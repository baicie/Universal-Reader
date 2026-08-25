use std::{
    path::PathBuf,
    sync::atomic::{AtomicU64, Ordering},
    time::{SystemTime, UNIX_EPOCH},
};

use axum::{
    Json, Router,
    extract::{Multipart, Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
};

pub const SERVICE_NAME: &str = "universal-reader-server";
pub const SERVICE_VERSION: &str = env!("CARGO_PKG_VERSION");
const MAX_UPLOAD_BYTES: usize = 64 * 1024 * 1024;
static FILE_SEQUENCE: AtomicU64 = AtomicU64::new(0);

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

#[derive(Clone)]
struct AppState {
    storage_dir: PathBuf,
}

pub fn app() -> Router {
    let storage_dir = std::env::var_os("UNIVERSAL_READER_STORAGE_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("data/library"));
    app_with_storage_dir(storage_dir)
}

pub fn app_with_storage_dir(storage_dir: PathBuf) -> Router {
    let state = AppState { storage_dir };
    Router::new()
        .route("/health", get(health))
        .route("/v1/formats/{file_name}", get(format))
        .route("/v1/library/files", post(upload_file))
        .with_state(state)
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

async fn upload_file(State(state): State<AppState>, mut multipart: Multipart) -> impl IntoResponse {
    let mut file_name = None;
    let mut content = None;

    while let Ok(Some(field)) = multipart.next_field().await {
        if field.name() != Some("file") {
            continue;
        }
        let Some(candidate_name) = field.file_name().map(str::to_owned) else {
            return (
                StatusCode::BAD_REQUEST,
                Json(ApiError {
                    error: "file field must include a file name",
                }),
            )
                .into_response();
        };
        if candidate_name.len() > 255 || candidate_name.contains(['/', '\\']) {
            return (
                StatusCode::BAD_REQUEST,
                Json(ApiError {
                    error: "file name is invalid",
                }),
            )
                .into_response();
        }
        if detect_format(&candidate_name).is_none() {
            return (
                StatusCode::UNSUPPORTED_MEDIA_TYPE,
                Json(ApiError {
                    error: "unsupported document format",
                }),
            )
                .into_response();
        }
        match field.bytes().await {
            Ok(bytes) if bytes.len() <= MAX_UPLOAD_BYTES => {
                file_name = Some(candidate_name);
                content = Some(bytes);
            }
            Ok(_) => {
                return (
                    StatusCode::PAYLOAD_TOO_LARGE,
                    Json(ApiError {
                        error: "file exceeds the 64 MiB upload limit",
                    }),
                )
                    .into_response();
            }
            Err(_) => {
                return (
                    StatusCode::BAD_REQUEST,
                    Json(ApiError {
                        error: "could not read uploaded file",
                    }),
                )
                    .into_response();
            }
        }
        break;
    }

    let (Some(file_name), Some(content)) = (file_name, content) else {
        return (
            StatusCode::BAD_REQUEST,
            Json(ApiError {
                error: "multipart request must contain a file field",
            }),
        )
            .into_response();
    };
    let detected = detect_format(&file_name).expect("file format was validated before reading");

    if tokio::fs::create_dir_all(&state.storage_dir).await.is_err() {
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiError {
                error: "could not prepare library storage",
            }),
        )
            .into_response();
    }

    let sequence = FILE_SEQUENCE.fetch_add(1, Ordering::Relaxed);
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |duration| duration.as_millis());
    let extension = file_name.rsplit_once('.').map_or("bin", |(_, value)| value);
    let stored_name = format!("{timestamp}-{sequence}.{extension}");
    let stored_path = state.storage_dir.join(&stored_name);

    if tokio::fs::write(&stored_path, &content).await.is_err() {
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiError {
                error: "could not store uploaded file",
            }),
        )
            .into_response();
    }

    (
        StatusCode::CREATED,
        Json(UploadResponse {
            file_name,
            stored_name,
            format: detected.format,
            document_type: detected.document_type,
            size: content.len(),
        }),
    )
        .into_response()
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
struct UploadResponse {
    file_name: String,
    stored_name: String,
    format: &'static str,
    document_type: &'static str,
    size: usize,
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
