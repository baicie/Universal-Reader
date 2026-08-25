use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use std::{
    fs,
    time::{SystemTime, UNIX_EPOCH},
};
use tower::ServiceExt;
use universal_reader_server::{app, app_with_storage_dir};

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

    let stored_files: Vec<_> = fs::read_dir(&storage_dir).unwrap().collect();
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
