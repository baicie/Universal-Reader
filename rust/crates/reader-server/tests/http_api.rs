use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use tower::ServiceExt;
use universal_reader_server::app;

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
