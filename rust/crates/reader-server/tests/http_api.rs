use axum::{
    Json, Router,
    body::{Body, to_bytes},
    http::{Request, StatusCode, header},
    routing::post,
};
use std::{
    fs,
    time::{SystemTime, UNIX_EPOCH},
};
use tower::ServiceExt;
use universal_reader_server::{
    AiConfig, app, app_with_storage_and_ai, app_with_storage_and_web, app_with_storage_dir,
};

#[tokio::test]
async fn health_endpoint_reports_service_status() {
    let response = app()
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
    let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
    assert!(
        std::str::from_utf8(&body)
            .unwrap()
            .contains("\"status\":\"ok\"")
    );
}

#[tokio::test]
async fn format_endpoint_detects_supported_document() {
    let response = app()
        .oneshot(
            Request::builder()
                .uri("/v1/formats/Book.EPUB")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
    let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
    let response = std::str::from_utf8(&body).unwrap();
    assert!(response.contains("\"format\":\"epub\""));
    assert!(response.contains("\"document_type\":\"reflow\""));
}

#[tokio::test]
async fn format_endpoint_rejects_unsupported_document() {
    let response = app()
        .oneshot(
            Request::builder()
                .uri("/v1/formats/archive.zip")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::UNSUPPORTED_MEDIA_TYPE);
}

#[tokio::test]
async fn upload_endpoint_stores_supported_document() {
    let storage_dir = unique_temp_dir("upload-success");
    let body = multipart_body("book.epub", b"epub content");
    let response = app_with_storage_dir(storage_dir.clone())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/files")
                .header(
                    "content-type",
                    "multipart/form-data; boundary=test-boundary",
                )
                .body(Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::CREATED);
    let response_body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
    let response_text = std::str::from_utf8(&response_body).unwrap();
    assert!(response_text.contains("\"file_name\":\"book.epub\""));
    assert!(response_text.contains("\"format\":\"epub\""));
    assert!(response_text.contains("\"id\":"));

    let stored_files: Vec<_> = fs::read_dir(storage_dir.join("files")).unwrap().collect();
    assert_eq!(stored_files.len(), 1);
    let stored_path = stored_files[0].as_ref().unwrap().path();
    assert_eq!(fs::read(stored_path).unwrap(), b"epub content");
    fs::remove_dir_all(storage_dir).unwrap();
}

#[tokio::test]
async fn upload_endpoint_rejects_unsupported_document_without_creating_file() {
    let storage_dir = unique_temp_dir("upload-rejected");
    let body = multipart_body("archive.zip", b"not supported");
    let response = app_with_storage_dir(storage_dir.clone())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/files")
                .header(
                    "content-type",
                    "multipart/form-data; boundary=test-boundary",
                )
                .body(Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::UNSUPPORTED_MEDIA_TYPE);
    assert!(!storage_dir.exists());
}

#[tokio::test]
async fn serves_flutter_web_index_and_spa_fallback() {
    let web_dir = unique_temp_dir("web-assets");
    let storage_dir = unique_temp_dir("web-storage");
    fs::create_dir_all(&web_dir).unwrap();
    fs::write(web_dir.join("index.html"), b"<html>web-ok</html>").unwrap();
    fs::write(web_dir.join("flutter.js"), b"/* asset */").unwrap();
    let app = app_with_storage_and_web(storage_dir.clone(), Some(web_dir.clone()));

    let index = app
        .clone()
        .oneshot(Request::builder().uri("/").body(Body::empty()).unwrap())
        .await
        .unwrap();
    assert_eq!(index.status(), StatusCode::OK);
    let index_body = to_bytes(index.into_body(), usize::MAX).await.unwrap();
    assert!(std::str::from_utf8(&index_body).unwrap().contains("web-ok"));

    let asset = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/flutter.js")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(asset.status(), StatusCode::OK);
    let asset_body = to_bytes(asset.into_body(), usize::MAX).await.unwrap();
    assert!(std::str::from_utf8(&asset_body).unwrap().contains("asset"));

    let spa = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/settings")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(spa.status(), StatusCode::OK);
    let spa_body = to_bytes(spa.into_body(), usize::MAX).await.unwrap();
    assert!(std::str::from_utf8(&spa_body).unwrap().contains("web-ok"));

    let health = app
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(health.status(), StatusCode::OK);
    let health_body = to_bytes(health.into_body(), usize::MAX).await.unwrap();
    assert!(
        std::str::from_utf8(&health_body)
            .unwrap()
            .contains("\"status\":\"ok\"")
    );

    fs::remove_dir_all(web_dir).unwrap();
    let _ = fs::remove_dir_all(storage_dir);
}

#[tokio::test]
async fn library_drive_lists_updates_downloads_and_deletes_documents() {
    let storage_dir = unique_temp_dir("library-drive");
    let app = app_with_storage_dir(storage_dir.clone());

    let empty = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/v1/library/documents")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(empty.status(), StatusCode::OK);
    let empty_body = to_bytes(empty.into_body(), usize::MAX).await.unwrap();
    assert!(
        std::str::from_utf8(&empty_body)
            .unwrap()
            .contains("\"documents\":[]")
    );

    let uploaded = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/files")
                .header(
                    "content-type",
                    "multipart/form-data; boundary=test-boundary",
                )
                .body(Body::from(multipart_body("notes.txt", b"hello drive")))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(uploaded.status(), StatusCode::CREATED);
    let uploaded_body = to_bytes(uploaded.into_body(), usize::MAX).await.unwrap();
    let uploaded_json: serde_json::Value = serde_json::from_slice(&uploaded_body).unwrap();
    let id = uploaded_json["id"].as_str().unwrap().to_string();
    assert_eq!(uploaded_json["title"], "notes");
    assert_eq!(uploaded_json["format"], "txt");

    let listed = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/v1/library/documents")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let listed_body = to_bytes(listed.into_body(), usize::MAX).await.unwrap();
    assert!(std::str::from_utf8(&listed_body).unwrap().contains(&id));

    let patched = app
        .clone()
        .oneshot(
            Request::builder()
                .method("PATCH")
                .uri(format!("/v1/library/documents/{id}"))
                .header("content-type", "application/json")
                .body(Body::from(r#"{"progress":0.4}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(patched.status(), StatusCode::OK);
    let patched_body = to_bytes(patched.into_body(), usize::MAX).await.unwrap();
    assert!(std::str::from_utf8(&patched_body).unwrap().contains("0.4"));

    let downloaded = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/v1/library/documents/{id}/file"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(downloaded.status(), StatusCode::OK);
    assert_eq!(
        downloaded
            .headers()
            .get(header::CONTENT_DISPOSITION)
            .unwrap(),
        "inline"
    );
    let file_body = to_bytes(downloaded.into_body(), usize::MAX).await.unwrap();
    assert_eq!(&file_body[..], b"hello drive");

    let deleted = app
        .clone()
        .oneshot(
            Request::builder()
                .method("DELETE")
                .uri(format!("/v1/library/documents/{id}"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(deleted.status(), StatusCode::NO_CONTENT);

    let missing = app
        .oneshot(
            Request::builder()
                .uri(format!("/v1/library/documents/{id}"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(missing.status(), StatusCode::NOT_FOUND);

    fs::remove_dir_all(storage_dir).unwrap();
}

#[tokio::test]
async fn ai_status_reports_whether_a_server_key_is_configured() {
    let storage_dir = unique_temp_dir("ai-status");
    let response = app_with_storage_and_ai(
        storage_dir.clone(),
        AiConfig::new(String::new(), String::new()),
    )
    .oneshot(
        Request::builder()
            .uri("/v1/ai/status")
            .body(Body::empty())
            .unwrap(),
    )
    .await
    .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(json["configured"], false);
    assert_eq!(json["provider"], "deepseek");
    let _ = fs::remove_dir_all(storage_dir);
}

#[tokio::test]
async fn ai_chat_rejects_unknown_models_before_requiring_a_key() {
    let storage_dir = unique_temp_dir("ai-model");
    let response = app_with_storage_and_ai(
        storage_dir.clone(),
        AiConfig::new(String::new(), String::new()),
    )
    .oneshot(
        Request::builder()
            .method("POST")
            .uri("/v1/ai/chat")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                r#"{"model":"gpt-4","messages":[{"role":"user","content":"hi"}]}"#,
            ))
            .unwrap(),
    )
    .await
    .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    let _ = fs::remove_dir_all(storage_dir);
}

#[tokio::test]
async fn ai_chat_rejects_empty_messages() {
    let storage_dir = unique_temp_dir("ai-empty-messages");
    let response = app_with_storage_and_ai(
        storage_dir.clone(),
        AiConfig::new(String::new(), "sk-test".into()),
    )
    .oneshot(
        Request::builder()
            .method("POST")
            .uri("/v1/ai/chat")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"model":"deepseek-chat","messages":[]}"#))
            .unwrap(),
    )
    .await
    .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    let _ = fs::remove_dir_all(storage_dir);
}

#[tokio::test]
async fn ai_chat_requires_a_key_from_the_request_or_the_server() {
    let storage_dir = unique_temp_dir("ai-key");
    let response = app_with_storage_and_ai(
        storage_dir.clone(),
        AiConfig::new(String::new(), String::new()),
    )
    .oneshot(
        Request::builder()
            .method("POST")
            .uri("/v1/ai/chat")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                r#"{"model":"deepseek-chat","messages":[{"role":"user","content":"hi"}]}"#,
            ))
            .unwrap(),
    )
    .await
    .unwrap();
    assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    let _ = fs::remove_dir_all(storage_dir);
}

#[tokio::test]
async fn ai_chat_forwards_to_the_configured_deepseek_endpoint() {
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let mock = Router::new().route(
        "/v1/chat/completions",
        post(|| async {
            Json(serde_json::json!({
                "choices": [{ "message": { "content": "  只谈当前摘录。  " } }]
            }))
        }),
    );
    tokio::spawn(async move {
        axum::serve(listener, mock).await.unwrap();
    });

    let storage_dir = unique_temp_dir("ai-chat");
    let app = app_with_storage_and_ai(
        storage_dir.clone(),
        AiConfig::new(format!("http://{addr}"), "sk-server".into()),
    );
    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/ai/chat")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    r#"{"model":"deepseek-chat","endpoint":"http://evil.example","messages":[{"role":"user","content":"hi"}]}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(json["content"], "只谈当前摘录。");
    let _ = fs::remove_dir_all(storage_dir);
}

#[tokio::test]
async fn conversation_endpoint_persists_turns_for_an_existing_book() {
    let storage_dir = unique_temp_dir("conversations");
    let app = app_with_storage_dir(storage_dir.clone());

    let uploaded = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/files")
                .header(
                    "content-type",
                    "multipart/form-data; boundary=test-boundary",
                )
                .body(Body::from(multipart_body("notes.txt", b"hello")))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(uploaded.status(), StatusCode::CREATED);
    let uploaded_body = to_bytes(uploaded.into_body(), usize::MAX).await.unwrap();
    let uploaded_json: serde_json::Value = serde_json::from_slice(&uploaded_body).unwrap();
    let id = uploaded_json["id"].as_str().unwrap().to_string();

    let empty = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/v1/library/documents/{id}/conversations"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(empty.status(), StatusCode::OK);
    let empty_body = to_bytes(empty.into_body(), usize::MAX).await.unwrap();
    let empty_json: serde_json::Value = serde_json::from_slice(&empty_body).unwrap();
    assert_eq!(empty_json["turns"], serde_json::json!([]));

    let saved = app
        .clone()
        .oneshot(
            Request::builder()
                .method("PUT")
                .uri(format!("/v1/library/documents/{id}/conversations"))
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    r#"{"turns":[{"kind":"ask","question":"这句话什么意思？","reply":"它在讲留白。","locator_label":"Offset 12","created_at_ms":1}]}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(saved.status(), StatusCode::OK);

    let loaded = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/v1/library/documents/{id}/conversations"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let loaded_body = to_bytes(loaded.into_body(), usize::MAX).await.unwrap();
    let loaded_json: serde_json::Value = serde_json::from_slice(&loaded_body).unwrap();
    assert_eq!(loaded_json["turns"][0]["reply"], "它在讲留白。");
    assert!(
        storage_dir
            .join("conversations")
            .join(format!("{id}.json"))
            .is_file()
    );

    let missing = app
        .oneshot(
            Request::builder()
                .uri("/v1/library/documents/missing-id/conversations")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(missing.status(), StatusCode::NOT_FOUND);
    fs::remove_dir_all(storage_dir).unwrap();
}

#[tokio::test]
async fn search_indexes_uploaded_text_and_keeps_hits_on_that_book() {
    let storage_dir = unique_temp_dir("fts-search");
    let app = app_with_storage_dir(storage_dir.clone());
    let uploaded = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/files")
                .header(
                    "content-type",
                    "multipart/form-data; boundary=test-boundary",
                )
                .body(Body::from(multipart_body(
                    "notes.txt",
                    b"unique-needle-text",
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let body = to_bytes(uploaded.into_body(), usize::MAX).await.unwrap();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    let id = json["id"].as_str().unwrap();

    let searched = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/v1/library/documents/{id}/search?q=unique-needle-text"
                ))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(searched.status(), StatusCode::OK);
    let searched_body = to_bytes(searched.into_body(), usize::MAX).await.unwrap();
    let searched_json: serde_json::Value = serde_json::from_slice(&searched_body).unwrap();
    assert_eq!(searched_json["hits"][0]["excerpt"], "unique-needle-text");

    let notes = app
        .clone()
        .oneshot(
            Request::builder()
                .method("PUT")
                .uri(format!("/v1/library/documents/{id}/annotations"))
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    r#"{"notes":[{"id":"n1","note":"saved","quote":"q","locator_label":"offset 0","source":"assistant","created_at_ms":1}]}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(notes.status(), StatusCode::OK);
    let loaded = app
        .oneshot(
            Request::builder()
                .uri(format!("/v1/library/documents/{id}/annotations"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let loaded_body = to_bytes(loaded.into_body(), usize::MAX).await.unwrap();
    let loaded_json: serde_json::Value = serde_json::from_slice(&loaded_body).unwrap();
    assert_eq!(loaded_json["notes"][0]["note"], "saved");
    fs::remove_dir_all(storage_dir).unwrap();
}

#[tokio::test]
async fn scan_imports_supported_files_and_skips_unknown_or_duplicate_names() {
    let storage_dir = unique_temp_dir("scan-lib");
    let folder = unique_temp_dir("scan-src");
    fs::create_dir_all(&folder).unwrap();
    fs::write(folder.join("notes.txt"), b"from folder").unwrap();
    fs::write(folder.join("skip.bin"), b"nope").unwrap();
    let folder = fs::canonicalize(&folder).unwrap();
    let app = app_with_storage_dir(storage_dir.clone());
    let first = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/scan")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "path": folder }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(first.status(), StatusCode::OK);
    let first_body = to_bytes(first.into_body(), usize::MAX).await.unwrap();
    let first_json: serde_json::Value = serde_json::from_slice(&first_body).unwrap();
    assert_eq!(
        first_json["imported"],
        1,
        "scan body: {}",
        String::from_utf8_lossy(&first_body)
    );
    assert_eq!(first_json["skipped"], 0);

    let second = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/scan")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "path": folder }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let second_body = to_bytes(second.into_body(), usize::MAX).await.unwrap();
    let second_json: serde_json::Value = serde_json::from_slice(&second_body).unwrap();
    assert_eq!(second_json["imported"], 0);
    assert_eq!(second_json["skipped"], 1);
    fs::remove_dir_all(storage_dir).unwrap();
    fs::remove_dir_all(folder).unwrap();
}

#[tokio::test]
async fn webdav_import_rejects_an_unconfigured_or_non_http_url() {
    let storage_dir = unique_temp_dir("webdav-reject");
    let response = app_with_storage_dir(storage_dir.clone())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/webdav/import")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(r#"{"base_url":"file:///tmp/secret"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    let _ = fs::remove_dir_all(storage_dir);
}

#[tokio::test]
async fn webdav_sync_rejects_a_non_http_url() {
    let storage_dir = unique_temp_dir("webdav-sync-reject");
    let response = app_with_storage_dir(storage_dir.clone())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/webdav/sync")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(r#"{"base_url":"file:///tmp/secret"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    let _ = fs::remove_dir_all(storage_dir);
}

#[tokio::test]
async fn watch_accepts_an_absolute_folder() {
    let storage_dir = unique_temp_dir("watch-lib");
    let folder = unique_temp_dir("watch-src");
    fs::create_dir_all(&folder).unwrap();
    let folder = fs::canonicalize(&folder).unwrap();
    let response = app_with_storage_dir(storage_dir.clone())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/watch")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "path": folder }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let _ = fs::remove_dir_all(storage_dir);
    let _ = fs::remove_dir_all(folder);
}

fn multipart_body(file_name: &str, content: &[u8]) -> Vec<u8> {
    format!(
        "--test-boundary\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{file_name}\"\r\nContent-Type: application/octet-stream\r\n\r\n"
    )
    .into_bytes()
    .into_iter()
    .chain(content.iter().copied())
    .chain(b"\r\n--test-boundary--\r\n".iter().copied())
    .collect()
}

fn unique_temp_dir(label: &str) -> std::path::PathBuf {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!("universal-reader-{label}-{timestamp}"))
}
