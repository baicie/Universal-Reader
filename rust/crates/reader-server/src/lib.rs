use std::{
    env,
    path::{Path, PathBuf},
    sync::Arc,
};

use axum::{
    Json, Router,
    body::Bytes,
    extract::{Multipart, Path as PathParam, Query, State},
    http::{StatusCode, header},
    response::IntoResponse,
    routing::{get, post},
};
use serde::Deserialize;
use tokio::sync::Mutex;
use tower_http::{
    cors::CorsLayer,
    services::{ServeDir, ServeFile},
};

mod ai;
mod extract;
mod library;
mod sources;
mod sqlite;

pub use ai::AiConfig;
pub use library::{LibraryDocumentRecord, LibraryStore};
pub use sources::SourcesConfig;

use library::{Annotations, Conversation, LibraryError, Shelves, content_type_for};

pub const SERVICE_NAME: &str = "universal-reader-server";
pub const SERVICE_VERSION: &str = env!("CARGO_PKG_VERSION");
const MAX_UPLOAD_BYTES: usize = 64 * 1024 * 1024;

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
    store: LibraryStore,
    ai: AiConfig,
    sources: SourcesConfig,
    watches: Arc<Mutex<Vec<sources::FolderWatch>>>,
}

pub fn app() -> Router {
    let storage_dir = env::var_os("UNIVERSAL_READER_STORAGE_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("data/library"));
    app_with_storage_dir(storage_dir)
}

pub fn app_with_storage_dir(storage_dir: PathBuf) -> Router {
    api_router(
        LibraryStore::new(storage_dir),
        AiConfig::from_env(),
        SourcesConfig::from_env(),
    )
}

pub fn app_with_storage_and_ai(storage_dir: PathBuf, ai: AiConfig) -> Router {
    api_router(
        LibraryStore::new(storage_dir),
        ai,
        SourcesConfig::from_env(),
    )
}

pub fn app_for_server() -> Router {
    let storage_dir = env::var_os("UNIVERSAL_READER_STORAGE_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("data/library"));
    app_with_storage_and_web(storage_dir, resolve_web_dir())
}

pub fn app_with_storage_and_web(storage_dir: PathBuf, web_dir: Option<PathBuf>) -> Router {
    with_optional_web(
        api_router(
            LibraryStore::new(storage_dir),
            AiConfig::from_env(),
            SourcesConfig::from_env(),
        ),
        web_dir,
    )
}

pub fn resolve_web_dir() -> Option<PathBuf> {
    if let Some(dir) = env::var_os("UNIVERSAL_READER_WEB_DIR") {
        let path = PathBuf::from(dir);
        return has_web_index(&path).then_some(path);
    }
    if let Ok(exe) = env::current_exe()
        && let Some(parent) = exe.parent()
    {
        let beside_exe = parent.join("web");
        if has_web_index(&beside_exe) {
            return Some(beside_exe);
        }
    }
    let cwd_web = PathBuf::from("web");
    has_web_index(&cwd_web).then_some(cwd_web)
}

fn has_web_index(dir: &Path) -> bool {
    dir.join("index.html").is_file()
}

fn api_router(store: LibraryStore, ai: AiConfig, sources: SourcesConfig) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/v1/formats/{file_name}", get(format))
        .route("/v1/ai/status", get(ai::ai_status))
        .route("/v1/ai/chat", post(ai::ai_chat))
        .route("/v1/library/documents", get(list_documents))
        .route(
            "/v1/library/documents/{id}",
            get(get_document)
                .patch(update_document)
                .delete(delete_document),
        )
        .route("/v1/library/documents/{id}/file", get(download_document))
        .route("/v1/library/documents/{id}/cover", get(download_cover))
        .route(
            "/v1/library/documents/{id}/conversations",
            get(get_conversation).put(put_conversation),
        )
        .route("/v1/library/documents/{id}/search", get(search_document))
        .route(
            "/v1/library/documents/{id}/annotations",
            get(get_annotations).put(put_annotations),
        )
        .route("/v1/library/shelves", get(get_shelves).put(put_shelves))
        .route("/v1/library/files", post(upload_file))
        .route("/v1/library/scan", post(scan_folder))
        .route("/v1/library/webdav/import", post(import_webdav))
        .route("/v1/library/webdav/sync", post(sync_webdav))
        .route("/v1/library/watch", post(watch_folder))
        .layer(CorsLayer::permissive())
        .with_state(AppState {
            store,
            ai,
            sources,
            watches: Arc::new(Mutex::new(Vec::new())),
        })
}

fn with_optional_web(api: Router, web_dir: Option<PathBuf>) -> Router {
    let Some(web_dir) = web_dir.filter(|dir| has_web_index(dir)) else {
        return api;
    };
    let index = web_dir.join("index.html");
    api.fallback_service(
        ServeDir::new(web_dir)
            .append_index_html_on_directories(true)
            .fallback(ServeFile::new(index)),
    )
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        service: SERVICE_NAME,
        version: SERVICE_VERSION,
        status: "ok",
    })
}

async fn format(PathParam(file_name): PathParam<String>) -> impl IntoResponse {
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

async fn list_documents(State(state): State<AppState>) -> impl IntoResponse {
    match state.store.list().await {
        Ok(documents) => (StatusCode::OK, Json(ListResponse { documents })).into_response(),
        Err(_) => library_error(LibraryError::Io).into_response(),
    }
}

async fn get_document(
    State(state): State<AppState>,
    PathParam(id): PathParam<String>,
) -> impl IntoResponse {
    match state.store.get(&id).await {
        Ok(document) => (StatusCode::OK, Json(document)).into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn update_document(
    State(state): State<AppState>,
    PathParam(id): PathParam<String>,
    Json(body): Json<UpdateDocumentRequest>,
) -> impl IntoResponse {
    if body.progress.is_none() && body.title.is_none() && body.author.is_none() {
        return (
            StatusCode::BAD_REQUEST,
            Json(ApiError {
                error: "progress, title, or author is required",
            }),
        )
            .into_response();
    }
    match state
        .store
        .update_document(&id, body.progress, body.title, body.author)
        .await
    {
        Ok(document) => (StatusCode::OK, Json(document)).into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn delete_document(
    State(state): State<AppState>,
    PathParam(id): PathParam<String>,
) -> impl IntoResponse {
    match state.store.delete(&id).await {
        Ok(_) => StatusCode::NO_CONTENT.into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn get_conversation(
    State(state): State<AppState>,
    PathParam(id): PathParam<String>,
) -> impl IntoResponse {
    match state.store.load_conversation(&id).await {
        Ok(conversation) => (StatusCode::OK, Json(conversation)).into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn put_conversation(
    State(state): State<AppState>,
    PathParam(id): PathParam<String>,
    Json(body): Json<Conversation>,
) -> impl IntoResponse {
    match state.store.save_conversation(&id, body).await {
        Ok(conversation) => (StatusCode::OK, Json(conversation)).into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn download_document(
    State(state): State<AppState>,
    PathParam(id): PathParam<String>,
) -> impl IntoResponse {
    match state.store.read_file(&id).await {
        Ok((document, bytes)) => (
            StatusCode::OK,
            [
                (header::CONTENT_TYPE, content_type_for(&document.format)),
                (
                    header::CONTENT_DISPOSITION,
                    if matches!(document.format.as_str(), "txt" | "markdown" | "html") {
                        "inline"
                    } else {
                        "attachment"
                    },
                ),
            ],
            bytes,
        )
            .into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn download_cover(
    State(state): State<AppState>,
    PathParam(id): PathParam<String>,
) -> impl IntoResponse {
    match state.store.read_cover(&id).await {
        Ok(bytes) => (
            StatusCode::OK,
            [(header::CONTENT_TYPE, "application/octet-stream")],
            bytes,
        )
            .into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn search_document(
    State(state): State<AppState>,
    PathParam(id): PathParam<String>,
    Query(query): Query<SearchQuery>,
) -> impl IntoResponse {
    let Some(q) = query.q.filter(|value| !value.trim().is_empty()) else {
        return (
            StatusCode::BAD_REQUEST,
            Json(ApiError {
                error: "q is required",
            }),
        )
            .into_response();
    };
    match state.store.search_document(&id, &q).await {
        Ok(hits) => (StatusCode::OK, Json(SearchResponse { hits })).into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn get_annotations(
    State(state): State<AppState>,
    PathParam(id): PathParam<String>,
) -> impl IntoResponse {
    match state.store.load_annotations(&id).await {
        Ok(annotations) => (StatusCode::OK, Json(annotations)).into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn put_annotations(
    State(state): State<AppState>,
    PathParam(id): PathParam<String>,
    Json(body): Json<Annotations>,
) -> impl IntoResponse {
    match state.store.save_annotations(&id, body).await {
        Ok(annotations) => (StatusCode::OK, Json(annotations)).into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn get_shelves(State(state): State<AppState>) -> impl IntoResponse {
    match state.store.load_shelves().await {
        Ok(shelves) => (StatusCode::OK, Json(shelves)).into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn put_shelves(
    State(state): State<AppState>,
    Json(body): Json<Shelves>,
) -> impl IntoResponse {
    match state.store.save_shelves(body).await {
        Ok(shelves) => (StatusCode::OK, Json(shelves)).into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn scan_folder(
    State(state): State<AppState>,
    Json(body): Json<ScanRequest>,
) -> impl IntoResponse {
    let Some(path) = sources::scan_root_ok(&body.path) else {
        return (
            StatusCode::BAD_REQUEST,
            Json(ApiError {
                error: "path is required",
            }),
        )
            .into_response();
    };
    match sources::scan_folder(&path) {
        Ok(files) => ingest_named_files(&state.store, files)
            .await
            .into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn import_webdav(
    State(state): State<AppState>,
    Json(body): Json<WebDavRequest>,
) -> impl IntoResponse {
    let Some(base_url) = state.sources.resolve_url(body.base_url.as_deref()) else {
        return (
            StatusCode::BAD_REQUEST,
            Json(ApiError {
                error: "webdav url is not configured",
            }),
        )
            .into_response();
    };
    match sources::list_webdav_files(
        &state.sources,
        &base_url,
        body.username.as_deref().unwrap_or(""),
        body.password.as_deref().unwrap_or(""),
    )
    .await
    {
        Ok(files) => ingest_named_files(&state.store, files)
            .await
            .into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn sync_webdav(
    State(state): State<AppState>,
    Json(body): Json<WebDavRequest>,
) -> impl IntoResponse {
    let Some(base_url) = state.sources.resolve_url(body.base_url.as_deref()) else {
        return (
            StatusCode::BAD_REQUEST,
            Json(ApiError {
                error: "webdav url is not configured",
            }),
        )
            .into_response();
    };
    let user = body.username.as_deref().unwrap_or("");
    let pass = body.password.as_deref().unwrap_or("");
    let remote = match sources::list_webdav_files(&state.sources, &base_url, user, pass).await {
        Ok(files) => files,
        Err(error) => return library_error(error).into_response(),
    };
    let names = match sources::list_webdav_names(&state.sources, &base_url, user, pass).await {
        Ok(names) => names,
        Err(error) => return library_error(error).into_response(),
    };
    let (imported, skipped) = match ingest_counts(&state.store, remote).await {
        Ok(counts) => counts,
        Err(error) => return library_error(error).into_response(),
    };
    let mut pushed = 0usize;
    match state.store.list().await {
        Ok(documents) => {
            for document in documents {
                if names.iter().any(|name| name == &document.file_name) {
                    continue;
                }
                let Ok((_, bytes)) = state.store.read_file(&document.id).await else {
                    continue;
                };
                if sources::put_webdav_file(
                    &state.sources,
                    &base_url,
                    user,
                    pass,
                    &document.file_name,
                    &bytes,
                )
                .await
                .is_ok()
                {
                    pushed += 1;
                }
            }
        }
        Err(error) => return library_error(error).into_response(),
    }
    (
        StatusCode::OK,
        Json(SourceImportResponse {
            imported,
            skipped,
            pushed,
        }),
    )
        .into_response()
}

async fn watch_folder(
    State(state): State<AppState>,
    Json(body): Json<ScanRequest>,
) -> impl IntoResponse {
    let Some(path) = sources::scan_root_ok(&body.path) else {
        return (
            StatusCode::BAD_REQUEST,
            Json(ApiError {
                error: "path is required",
            }),
        )
            .into_response();
    };
    match sources::start_folder_watch(path, state.store.clone(), tokio::runtime::Handle::current())
    {
        Ok(watch) => {
            state.watches.lock().await.push(watch);
            (
                StatusCode::OK,
                Json(SourceImportResponse {
                    imported: 0,
                    skipped: 0,
                    pushed: 0,
                }),
            )
                .into_response()
        }
        Err(error) => library_error(error).into_response(),
    }
}

async fn ingest_named_files(
    store: &LibraryStore,
    files: Vec<(String, Vec<u8>)>,
) -> impl IntoResponse {
    match ingest_counts(store, files).await {
        Ok((imported, skipped)) => (
            StatusCode::OK,
            Json(SourceImportResponse {
                imported,
                skipped,
                pushed: 0,
            }),
        )
            .into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

async fn ingest_counts(
    store: &LibraryStore,
    files: Vec<(String, Vec<u8>)>,
) -> Result<(usize, usize), LibraryError> {
    let mut imported = 0usize;
    let mut skipped = 0usize;
    for (file_name, bytes) in files {
        match store.ingest_if_new(file_name, &bytes).await {
            Ok(Some(_)) => imported += 1,
            Ok(None) => skipped += 1,
            Err(LibraryError::Unsupported) => skipped += 1,
            Err(error) => return Err(error),
        }
    }
    Ok((imported, skipped))
}

async fn upload_file(State(state): State<AppState>, mut multipart: Multipart) -> impl IntoResponse {
    let mut file_name = None;
    let mut content: Option<Bytes> = None;

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

    match state.store.ingest(file_name, &content).await {
        Ok(document) => (StatusCode::CREATED, Json(document)).into_response(),
        Err(error) => library_error(error).into_response(),
    }
}

fn library_error(error: LibraryError) -> impl IntoResponse {
    let (status, message) = match error {
        LibraryError::InvalidName => (StatusCode::BAD_REQUEST, "file name is invalid"),
        LibraryError::Unsupported => (
            StatusCode::UNSUPPORTED_MEDIA_TYPE,
            "unsupported document format",
        ),
        LibraryError::NotFound => (StatusCode::NOT_FOUND, "document not found"),
        LibraryError::Io => (
            StatusCode::INTERNAL_SERVER_ERROR,
            "could not access library storage",
        ),
    };
    (status, Json(ApiError { error: message }))
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
struct ListResponse {
    documents: Vec<LibraryDocumentRecord>,
}

#[derive(Deserialize)]
struct UpdateDocumentRequest {
    progress: Option<f64>,
    title: Option<String>,
    author: Option<String>,
}

#[derive(Deserialize)]
struct SearchQuery {
    q: Option<String>,
}

#[derive(serde::Serialize)]
struct SearchResponse {
    hits: Vec<library::SearchHit>,
}

#[derive(Deserialize)]
struct ScanRequest {
    path: String,
}

#[derive(Deserialize)]
struct WebDavRequest {
    base_url: Option<String>,
    username: Option<String>,
    password: Option<String>,
}

#[derive(serde::Serialize)]
struct SourceImportResponse {
    imported: usize,
    skipped: usize,
    #[serde(default)]
    pushed: usize,
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
