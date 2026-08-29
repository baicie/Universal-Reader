use std::{
    env,
    path::{Path, PathBuf},
};

use notify::Watcher;

use reqwest::header::{CONTENT_TYPE, HeaderValue};

use crate::{
    detect_format,
    library::{LibraryError, LibraryStore},
};

const MAX_FILE_BYTES: usize = 64 * 1024 * 1024;
const MAX_DEPTH: u8 = 3;

#[derive(Clone)]
pub struct SourcesConfig {
    pub webdav_url: String,
    pub webdav_user: String,
    pub webdav_password: String,
    http: reqwest::Client,
}

impl SourcesConfig {
    pub fn from_env() -> Self {
        Self {
            webdav_url: env::var("UNIVERSAL_READER_WEBDAV_URL").unwrap_or_default(),
            webdav_user: env::var("UNIVERSAL_READER_WEBDAV_USER").unwrap_or_default(),
            webdav_password: env::var("UNIVERSAL_READER_WEBDAV_PASSWORD").unwrap_or_default(),
            http: reqwest::Client::new(),
        }
    }

    pub fn resolve_url(&self, requested: Option<&str>) -> Option<String> {
        let requested = requested.map(str::trim).filter(|value| !value.is_empty());
        requested
            .map(str::to_string)
            .filter(|url| allowed_source_url(url))
            .or_else(|| {
                let fallback = self.webdav_url.trim();
                allowed_source_url(fallback).then(|| fallback.to_string())
            })
    }
}

pub fn allowed_source_url(url: &str) -> bool {
    let Ok(parsed) = reqwest::Url::parse(url) else {
        return false;
    };
    matches!(parsed.scheme(), "http" | "https") && parsed.host_str().is_some()
}

pub fn scan_folder(path: &Path) -> Result<Vec<(String, Vec<u8>)>, LibraryError> {
    if !path.is_absolute() || path_has_escape(path) {
        return Err(LibraryError::InvalidName);
    }
    let mut files = Vec::new();
    walk(path, 0, &mut files)?;
    Ok(files)
}

fn path_has_escape(path: &Path) -> bool {
    path.components()
        .any(|component| matches!(component, std::path::Component::ParentDir))
}

fn walk(path: &Path, depth: u8, out: &mut Vec<(String, Vec<u8>)>) -> Result<(), LibraryError> {
    if depth > MAX_DEPTH {
        return Ok(());
    }
    let entries = std::fs::read_dir(path).map_err(|_| LibraryError::Io)?;
    for entry in entries.flatten() {
        let next = entry.path();
        if next.is_dir() {
            walk(&next, depth + 1, out)?;
            continue;
        }
        let Some(name) = next.file_name().and_then(|value| value.to_str()) else {
            continue;
        };
        if detect_format(name).is_none() {
            continue;
        }
        let Ok(bytes) = std::fs::read(&next) else {
            continue;
        };
        if bytes.len() > MAX_FILE_BYTES {
            continue;
        }
        out.push((name.to_string(), bytes));
    }
    Ok(())
}

pub async fn list_webdav_files(
    config: &SourcesConfig,
    base_url: &str,
    username: &str,
    password: &str,
) -> Result<Vec<(String, Vec<u8>)>, LibraryError> {
    if !allowed_source_url(base_url) {
        return Err(LibraryError::InvalidName);
    }
    let user = if username.is_empty() {
        config.webdav_user.as_str()
    } else {
        username
    };
    let pass = if password.is_empty() {
        config.webdav_password.as_str()
    } else {
        password
    };
    let response = config
        .http
        .request(
            reqwest::Method::from_bytes(b"PROPFIND").map_err(|_| LibraryError::Io)?,
            base_url,
        )
        .header("Depth", "1")
        .header(
            CONTENT_TYPE,
            HeaderValue::from_static("application/xml; charset=utf-8"),
        )
        .basic_auth(user, Some(pass))
        .body(
            r#"<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>"#,
        )
        .send()
        .await
        .map_err(|_| LibraryError::Io)?;
    if !response.status().is_success() {
        return Err(LibraryError::Io);
    }
    let xml = response.text().await.map_err(|_| LibraryError::Io)?;
    let hrefs = webdav_hrefs(&xml);
    let mut files = Vec::new();
    for href in hrefs {
        let name = href
            .rsplit('/')
            .find(|part| !part.is_empty())
            .unwrap_or(&href)
            .to_string();
        if detect_format(&name).is_none() {
            continue;
        }
        let url = resolve_webdav_href(base_url, &href);
        let Ok(file) = config
            .http
            .get(&url)
            .basic_auth(user, Some(pass))
            .send()
            .await
        else {
            continue;
        };
        if !file.status().is_success() {
            continue;
        }
        let Ok(bytes) = file.bytes().await else {
            continue;
        };
        if bytes.len() > MAX_FILE_BYTES {
            continue;
        }
        files.push((name, bytes.to_vec()));
    }
    Ok(files)
}

fn webdav_hrefs(xml: &str) -> Vec<String> {
    let mut hrefs = Vec::new();
    let lower = xml.to_ascii_lowercase();
    let mut rest = xml;
    let mut lower_rest = lower.as_str();
    while let Some(at) = lower_rest.find("<d:href>") {
        let tag_len = "<d:href>".len();
        let src = &rest[at + tag_len..];
        let Some(end) = src.to_ascii_lowercase().find("</d:href>") else {
            break;
        };
        hrefs.push(src[..end].trim().to_string());
        rest = &src[end..];
        lower_rest = &src[end..];
    }
    if hrefs.is_empty() {
        let mut rest = xml;
        while let Some(at) = rest.to_ascii_lowercase().find("<href>") {
            let src = &rest[at + "<href>".len()..];
            let Some(end) = src.to_ascii_lowercase().find("</href>") else {
                break;
            };
            hrefs.push(src[..end].trim().to_string());
            rest = &src[end..];
        }
    }
    hrefs
}

fn resolve_webdav_href(base: &str, href: &str) -> String {
    if href.starts_with("http://") || href.starts_with("https://") {
        return href.to_string();
    }
    let base = reqwest::Url::parse(base);
    match base {
        Ok(root) => root
            .join(href)
            .map(|url| url.to_string())
            .unwrap_or_else(|_| href.to_string()),
        Err(_) => href.to_string(),
    }
}

pub async fn list_webdav_names(
    config: &SourcesConfig,
    base_url: &str,
    username: &str,
    password: &str,
) -> Result<Vec<String>, LibraryError> {
    if !allowed_source_url(base_url) {
        return Err(LibraryError::InvalidName);
    }
    let user = if username.is_empty() {
        config.webdav_user.as_str()
    } else {
        username
    };
    let pass = if password.is_empty() {
        config.webdav_password.as_str()
    } else {
        password
    };
    let response = config
        .http
        .request(
            reqwest::Method::from_bytes(b"PROPFIND").map_err(|_| LibraryError::Io)?,
            base_url,
        )
        .header("Depth", "1")
        .header(
            CONTENT_TYPE,
            HeaderValue::from_static("application/xml; charset=utf-8"),
        )
        .basic_auth(user, Some(pass))
        .body(
            r#"<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>"#,
        )
        .send()
        .await
        .map_err(|_| LibraryError::Io)?;
    if !response.status().is_success() {
        return Err(LibraryError::Io);
    }
    let xml = response.text().await.map_err(|_| LibraryError::Io)?;
    Ok(webdav_hrefs(&xml)
        .into_iter()
        .filter_map(|href| {
            href.rsplit('/')
                .find(|part| !part.is_empty())
                .map(str::to_string)
        })
        .filter(|name| detect_format(name).is_some())
        .collect())
}

pub async fn put_webdav_file(
    config: &SourcesConfig,
    base_url: &str,
    username: &str,
    password: &str,
    file_name: &str,
    bytes: &[u8],
) -> Result<(), LibraryError> {
    if !allowed_source_url(base_url) {
        return Err(LibraryError::InvalidName);
    }
    let url = resolve_webdav_href(base_url, file_name);
    if !allowed_source_url(&url) {
        return Err(LibraryError::InvalidName);
    }
    let user = if username.is_empty() {
        config.webdav_user.as_str()
    } else {
        username
    };
    let pass = if password.is_empty() {
        config.webdav_password.as_str()
    } else {
        password
    };
    let response = config
        .http
        .put(url)
        .basic_auth(user, Some(pass))
        .body(bytes.to_vec())
        .send()
        .await
        .map_err(|_| LibraryError::Io)?;
    if !response.status().is_success() {
        return Err(LibraryError::Io);
    }
    Ok(())
}

pub struct FolderWatch {
    _watcher: notify::RecommendedWatcher,
}

pub fn start_folder_watch(
    path: std::path::PathBuf,
    store: LibraryStore,
    handle: tokio::runtime::Handle,
) -> Result<FolderWatch, LibraryError> {
    if !path.is_absolute() || path_has_escape(&path) {
        return Err(LibraryError::InvalidName);
    }
    let (tx, rx) = std::sync::mpsc::channel();
    let mut watcher = notify::recommended_watcher(move |event| {
        let _ = tx.send(event);
    })
    .map_err(|_| LibraryError::Io)?;
    watcher
        .watch(&path, notify::RecursiveMode::Recursive)
        .map_err(|_| LibraryError::Io)?;
    std::thread::spawn(move || {
        while let Ok(event) = rx.recv() {
            let Ok(event) = event else { continue };
            if !matches!(
                event.kind,
                notify::EventKind::Create(_) | notify::EventKind::Modify(_)
            ) {
                continue;
            }
            for path in event.paths {
                let store = store.clone();
                handle.spawn(async move {
                    let _ = store.ingest_path(&path).await;
                });
            }
        }
    });
    Ok(FolderWatch { _watcher: watcher })
}

pub fn should_skip(existing: &[String], file_name: &str) -> bool {
    existing.iter().any(|name| name == file_name)
}

pub fn scan_root_ok(path: &str) -> Option<PathBuf> {
    let path = PathBuf::from(path.trim());
    if path.as_os_str().is_empty() {
        return None;
    }
    Some(path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_non_http_webdav_urls() {
        assert!(!allowed_source_url("file:///tmp/secret"));
        assert!(!allowed_source_url(""));
        assert!(allowed_source_url("https://dav.example/books"));
    }

    #[test]
    fn skips_existing_file_names() {
        assert!(should_skip(&["notes.txt".into()], "notes.txt"));
        assert!(!should_skip(&["notes.txt".into()], "other.txt"));
    }

    #[test]
    fn scan_folder_reads_supported_files_only() {
        let dir = std::env::temp_dir().join(format!(
            "ur-scan-{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("notes.txt"), b"from folder").unwrap();
        std::fs::write(dir.join("skip.bin"), b"nope").unwrap();
        let files = scan_folder(&dir).expect("scan folder");
        assert_eq!(files.len(), 1);
        assert_eq!(files[0].0, "notes.txt");
        let _ = std::fs::remove_dir_all(dir);
    }
}
