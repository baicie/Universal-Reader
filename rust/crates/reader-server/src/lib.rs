use axum::{Json, Router, extract::Path, http::StatusCode, response::IntoResponse, routing::get};

pub const SERVICE_NAME: &str = "universal-reader-server";
pub const SERVICE_VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Debug, PartialEq, Eq)]
pub struct DetectedFormat {
    pub format: &'static str,
    pub document_type: &'static str,
}

pub fn detect_format(file_name: &str) -> Option<DetectedFormat> {
    let extension = file_name.rsplit_once('.')?.1.to_ascii_lowercase();
    let (format, document_type) = match extension.as_str() {
        "epub" => ("epub", "reflow"),
        "pdf" => ("pdf", "fixed_page"),
        "mobi" => ("mobi", "reflow"),
        "azw3" => ("azw3", "reflow"),
        "fb2" => ("fb2", "reflow"),
        "txt" => ("txt", "reflow"),
        "md" | "markdown" => ("markdown", "reflow"),
        "html" | "htm" => ("html", "reflow"),
        "cbz" => ("cbz", "comic"),
        "cbr" => ("cbr", "comic"),
        _ => return None,
    };
    Some(DetectedFormat {
        format,
        document_type,
    })
}

pub fn app() -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/v1/formats/{file_name}", get(format))
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        service: SERVICE_NAME,
        version: SERVICE_VERSION,
        status: "ok",
    })
}

async fn format(Path(file_name): Path<String>) -> impl IntoResponse {
    if file_name.trim().is_empty() || file_name.len() > 255 {
        return (
            StatusCode::BAD_REQUEST,
            Json(ApiError {
                error: "file_name must contain 1 to 255 characters",
            }),
        )
            .into_response();
    }

    match detect_format(&file_name) {
        Some(detected) => (
            StatusCode::OK,
            Json(FormatResponse {
                file_name,
                format: detected.format,
                document_type: detected.document_type,
            }),
        )
            .into_response(),
        None => (
            StatusCode::UNSUPPORTED_MEDIA_TYPE,
            Json(ApiError {
                error: "unsupported document format",
            }),
        )
            .into_response(),
    }
}

#[derive(serde::Serialize)]
struct HealthResponse {
    service: &'static str,
    version: &'static str,
    status: &'static str,
}

#[derive(serde::Serialize)]
struct FormatResponse {
    file_name: String,
    format: &'static str,
    document_type: &'static str,
}

#[derive(serde::Serialize)]
struct ApiError {
    error: &'static str,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_supported_extensions_case_insensitively() {
        assert_eq!(
            detect_format("book.EPUB"),
            Some(DetectedFormat {
                format: "epub",
                document_type: "reflow",
            })
        );
        assert_eq!(
            detect_format("comic.cbz"),
            Some(DetectedFormat {
                format: "cbz",
                document_type: "comic",
            })
        );
    }

    #[test]
    fn rejects_unsupported_or_extensionless_names() {
        assert_eq!(detect_format("archive.zip"), None);
        assert_eq!(detect_format("README"), None);
    }
}
