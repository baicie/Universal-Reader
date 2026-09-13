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
    let body = multipart_body("archive.zip", &[0, 1, 2, 3]);
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
async fn upload_endpoint_uses_content_when_the_extension_is_unrelated() {
    let storage_dir = unique_temp_dir("upload-content-detected");
    let body = multipart_body("book.bin", b"%PDF-1.7\n%%EOF");
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
    assert!(response_text.contains("\"format\":\"pdf\""));
    assert!(response_text.contains("\"document_type\":\"fixed_page\""));
    fs::remove_dir_all(storage_dir).unwrap();
}

#[tokio::test]
async fn upload_endpoint_converts_chm_to_epub() {
    let storage_dir = unique_temp_dir("upload-chm");
    let bytes = include_bytes!("../../../../test-books/chm/minimal.chm");
    let body = multipart_body("manual.chm", bytes);
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
    assert!(response_text.contains("\"format\":\"epub\""));
    assert!(response_text.contains("\"document_type\":\"reflow\""));

    let stored_files: Vec<_> = fs::read_dir(storage_dir.join("files")).unwrap().collect();
    assert_eq!(stored_files.len(), 1);
    let stored = fs::read(stored_files[0].as_ref().unwrap().path()).unwrap();
    assert!(stored.starts_with(b"PK\x03\x04"));
    assert!(
        stored
            .windows(20)
            .any(|window| window == b"application/epub+zip")
    );
    fs::remove_dir_all(storage_dir).unwrap();
}

#[tokio::test]
async fn upload_endpoint_converts_djvu_to_cbz() {
    let storage_dir = unique_temp_dir("upload-djvu");
    let bytes = include_bytes!("../../../../test-books/djvu/minimal.djvu");
    let body = multipart_body("scan.djvu", bytes);
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
    assert!(response_text.contains("\"format\":\"cbz\""));
    assert!(response_text.contains("\"document_type\":\"comic\""));

    let stored_files: Vec<_> = fs::read_dir(storage_dir.join("files")).unwrap().collect();
    assert_eq!(stored_files.len(), 1);
    let stored = fs::read(stored_files[0].as_ref().unwrap().path()).unwrap();
    assert!(stored.starts_with(b"PK\x03\x04"));
    let archive = zip::ZipArchive::new(std::io::Cursor::new(stored)).unwrap();
    assert!(!archive.is_empty());
    fs::remove_dir_all(storage_dir).unwrap();
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

    let renamed = app
        .clone()
        .oneshot(
            Request::builder()
                .method("PATCH")
                .uri(format!("/v1/library/documents/{id}"))
                .header("content-type", "application/json")
                .body(Body::from(r#"{"title":"设计笔记","author":"某作者"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(renamed.status(), StatusCode::OK);
    let renamed_body = to_bytes(renamed.into_body(), usize::MAX).await.unwrap();
    let renamed_json: serde_json::Value = serde_json::from_slice(&renamed_body).unwrap();
    assert_eq!(renamed_json["title"], "设计笔记");
    assert_eq!(renamed_json["author"], "某作者");
    assert!((renamed_json["progress"].as_f64().unwrap() - 0.4).abs() < 1e-9);

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
    assert!(storage_dir.join("library.sqlite").is_file());
    assert!(
        !storage_dir
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
    fs::write(folder.join("skip.bin"), [0, 1, 2, 3]).unwrap();
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
async fn progressive_scan_imports_in_batches_and_finishes() {
    let storage_dir = unique_temp_dir("progressive-scan-library");
    let folder = unique_temp_dir("progressive-scan-source");
    fs::create_dir_all(&folder).unwrap();
    for index in 0..3 {
        fs::write(
            folder.join(format!("book-{index}.txt")),
            format!("batch body {index}"),
        )
        .unwrap();
    }
    let folder = fs::canonicalize(&folder).unwrap();
    let app = app_with_storage_dir(storage_dir.clone());

    let started = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/scan/start")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "path": folder }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(started.status(), StatusCode::OK);
    let started_body = to_bytes(started.into_body(), usize::MAX).await.unwrap();
    let started_json: serde_json::Value = serde_json::from_slice(&started_body).unwrap();
    assert_eq!(started_json["total"], 3);
    let session_id = started_json["session_id"].as_str().unwrap();

    let first = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/scan/next")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "session_id": session_id, "limit": 2 }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(first.status(), StatusCode::OK);
    let first_body = to_bytes(first.into_body(), usize::MAX).await.unwrap();
    let first_json: serde_json::Value = serde_json::from_slice(&first_body).unwrap();
    assert_eq!(first_json["processed"], 2);
    assert_eq!(first_json["imported"], 2);
    assert_eq!(first_json["done"], false);

    let second = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/scan/next")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "session_id": session_id, "limit": 2 }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(second.status(), StatusCode::OK);
    let second_body = to_bytes(second.into_body(), usize::MAX).await.unwrap();
    let second_json: serde_json::Value = serde_json::from_slice(&second_body).unwrap();
    assert_eq!(second_json["processed"], 1);
    assert_eq!(second_json["imported"], 1);
    assert_eq!(second_json["done"], true);

    let listed = app
        .oneshot(
            Request::builder()
                .uri("/v1/library/documents")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let listed_body = to_bytes(listed.into_body(), usize::MAX).await.unwrap();
    let listed_json: serde_json::Value = serde_json::from_slice(&listed_body).unwrap();
    assert_eq!(listed_json["documents"].as_array().unwrap().len(), 3);

    fs::remove_dir_all(storage_dir).unwrap();
    fs::remove_dir_all(folder).unwrap();
}

#[tokio::test]
async fn folder_sync_imports_and_pushes_without_overwriting_conflicts() {
    let storage_dir = unique_temp_dir("folder-sync-library");
    let folder = unique_temp_dir("folder-sync-source");
    fs::create_dir_all(&folder).unwrap();
    fs::write(folder.join("from-folder.txt"), b"from folder").unwrap();
    fs::write(folder.join("same.txt"), b"folder copy").unwrap();
    let folder = fs::canonicalize(&folder).unwrap();
    let app = app_with_storage_dir(storage_dir.clone());

    for (name, bytes) in [
        ("local.txt", b"local book".as_slice()),
        ("same.txt", b"library copy".as_slice()),
    ] {
        let body = multipart_body(name, bytes);
        let response = app
            .clone()
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
    }

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/folder/sync")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "path": folder }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
    let body: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(body["imported"], 1);
    assert_eq!(body["pushed"], 1);
    assert_eq!(fs::read(folder.join("local.txt")).unwrap(), b"local book");
    assert_eq!(fs::read(folder.join("same.txt")).unwrap(), b"folder copy");
    fs::remove_dir_all(storage_dir).unwrap();
    fs::remove_dir_all(folder).unwrap();
}

#[tokio::test]
async fn metadata_folder_sync_merges_progress_annotations_and_deletions() {
    let storage_a = unique_temp_dir("metadata-sync-a");
    let storage_b = unique_temp_dir("metadata-sync-b");
    let folder = unique_temp_dir("metadata-sync-folder");
    fs::create_dir_all(&folder).unwrap();
    let folder = fs::canonicalize(&folder).unwrap();
    let app_a = app_with_storage_dir(storage_a.clone());
    let app_b = app_with_storage_dir(storage_b.clone());
    let bytes = b"shared sync book";

    let id_a = upload_document(&app_a, "shared.txt", bytes).await;
    put_annotation(&app_a, &id_a, "a", 10).await;
    patch_progress(&app_a, &id_a, 0.35).await;
    let first = sync_metadata_folder(&app_a, &folder).await;
    assert_eq!(first["remote_found"], false);
    assert!(folder.join("universal-reader-sync.json").is_file());

    let id_b = upload_document(&app_b, "shared.txt", bytes).await;
    put_annotation(&app_b, &id_b, "b", 20).await;
    tokio::time::sleep(std::time::Duration::from_millis(5)).await;
    patch_progress(&app_b, &id_b, 0.65).await;

    let from_b = sync_metadata_folder(&app_b, &folder).await;
    assert_eq!(from_b["remote_found"], true);
    assert_eq!(from_b["annotations_updated"], 1);
    let notes_b = load_annotations(&app_b, &id_b).await;
    assert_eq!(
        notes_b
            .as_array()
            .unwrap()
            .iter()
            .map(|note| note["id"].as_str().unwrap())
            .collect::<Vec<_>>(),
        vec!["a", "b"]
    );
    assert_eq!(load_progress(&app_b, &id_b).await, 0.65);

    let from_a = sync_metadata_folder(&app_a, &folder).await;
    assert_eq!(from_a["remote_found"], true);
    assert_eq!(from_a["annotations_updated"], 1);
    assert_eq!(load_progress(&app_a, &id_a).await, 0.65);
    let notes_a = load_annotations(&app_a, &id_a).await;
    assert_eq!(notes_a.as_array().unwrap().len(), 2);

    put_annotation_ids(&app_a, &id_a, &[("b", 20)]).await;
    sync_metadata_folder(&app_a, &folder).await;
    sync_metadata_folder(&app_b, &folder).await;
    let after_delete = load_annotations(&app_b, &id_b).await;
    assert_eq!(after_delete.as_array().unwrap().len(), 1);
    assert_eq!(after_delete[0]["id"], "b");

    fs::remove_dir_all(storage_a).unwrap();
    fs::remove_dir_all(storage_b).unwrap();
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

#[tokio::test]
async fn shelves_round_trip_and_drop_unknown_document_ids() {
    let storage_dir = unique_temp_dir("shelves-lib");
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
                .body(Body::from(multipart_body("notes.txt", b"hello shelves")))
                .unwrap(),
        )
        .await
        .unwrap();
    let body = to_bytes(uploaded.into_body(), usize::MAX).await.unwrap();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    let id = json["id"].as_str().unwrap();

    let saved = app
        .clone()
        .oneshot(
            Request::builder()
                .method("PUT")
                .uri("/v1/library/shelves")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({
                        "favorites": [id, "ghost"],
                        "collections": [{
                            "id": "c-1",
                            "name": "今晚读",
                            "color": 1,
                            "document_ids": [id, "missing"]
                        }]
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(saved.status(), StatusCode::OK);
    let saved_body = to_bytes(saved.into_body(), usize::MAX).await.unwrap();
    let saved_json: serde_json::Value = serde_json::from_slice(&saved_body).unwrap();
    assert_eq!(saved_json["favorites"], serde_json::json!([id]));
    assert_eq!(
        saved_json["collections"][0]["document_ids"],
        serde_json::json!([id])
    );

    let loaded = app
        .oneshot(
            Request::builder()
                .uri("/v1/library/shelves")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(loaded.status(), StatusCode::OK);
    let loaded_body = to_bytes(loaded.into_body(), usize::MAX).await.unwrap();
    let loaded_json: serde_json::Value = serde_json::from_slice(&loaded_body).unwrap();
    assert_eq!(loaded_json["favorites"], serde_json::json!([id]));
    assert_eq!(loaded_json["collections"][0]["name"], "今晚读");
    assert_eq!(
        loaded_json["collections"][0]["document_ids"],
        serde_json::json!([id])
    );
    fs::remove_dir_all(storage_dir).unwrap();
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

async fn upload_document(app: &Router, file_name: &str, bytes: &[u8]) -> String {
    let response = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/files")
                .header(
                    "content-type",
                    "multipart/form-data; boundary=test-boundary",
                )
                .body(Body::from(multipart_body(file_name, bytes)))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    json["id"].as_str().unwrap().to_string()
}

async fn put_annotation(app: &Router, id: &str, note_id: &str, created_at_ms: u64) {
    put_annotation_ids(app, id, &[(note_id, created_at_ms)]).await;
}

async fn put_annotation_ids(app: &Router, id: &str, notes: &[(&str, u64)]) {
    let notes: Vec<serde_json::Value> = notes
        .iter()
        .map(|(note_id, created_at_ms)| {
            serde_json::json!({
                "id": note_id,
                "note": format!("note-{note_id}"),
                "quote": String::new(),
                "locator_label": String::new(),
                "source": "user",
                "created_at_ms": created_at_ms
            })
        })
        .collect();
    let response = app
        .clone()
        .oneshot(
            Request::builder()
                .method("PUT")
                .uri(format!("/v1/library/documents/{id}/annotations"))
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "notes": notes }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
}

async fn patch_progress(app: &Router, id: &str, progress: f64) {
    let response = app
        .clone()
        .oneshot(
            Request::builder()
                .method("PATCH")
                .uri(format!("/v1/library/documents/{id}"))
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "progress": progress }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
}

async fn load_progress(app: &Router, id: &str) -> f64 {
    let response = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/v1/library/documents/{id}"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    json["progress"].as_f64().unwrap()
}

async fn load_annotations(app: &Router, id: &str) -> serde_json::Value {
    let response = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/v1/library/documents/{id}/annotations"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
    serde_json::from_slice::<serde_json::Value>(&body).unwrap()["notes"].clone()
}

async fn sync_metadata_folder(app: &Router, folder: &std::path::Path) -> serde_json::Value {
    let response = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/v1/library/metadata/folder/sync")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "path": folder }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
    serde_json::from_slice(&body).unwrap()
}

fn unique_temp_dir(label: &str) -> std::path::PathBuf {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!("universal-reader-{label}-{timestamp}"))
}
