use std::{
    path::{Path, PathBuf},
    sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    },
    time::{SystemTime, UNIX_EPOCH},
};

use serde::{Deserialize, Serialize};
use tokio::sync::Mutex;

use crate::detect_format;

static FILE_SEQUENCE: AtomicU64 = AtomicU64::new(0);

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LibraryDocumentRecord {
    pub id: String,
    pub file_name: String,
    pub stored_name: String,
    pub title: String,
    pub author: String,
    pub format: String,
    pub document_type: String,
    pub size: usize,
    pub cover_color: u32,
    pub progress: f64,
    pub last_opened_ms: u64,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
struct Catalog {
    documents: Vec<LibraryDocumentRecord>,
}

#[derive(Debug)]
pub enum LibraryError {
    InvalidName,
    Unsupported,
    NotFound,
    Io,
}

#[derive(Clone)]
pub struct LibraryStore {
    root: PathBuf,
    lock: Arc<Mutex<()>>,
}

impl LibraryStore {
    pub fn new(root: PathBuf) -> Self {
        Self {
            root,
            lock: Arc::new(Mutex::new(())),
        }
    }

    pub fn files_dir(&self) -> PathBuf {
        self.root.join("files")
    }

    fn catalog_path(&self) -> PathBuf {
        self.root.join("catalog.json")
    }

    pub async fn list(&self) -> Result<Vec<LibraryDocumentRecord>, LibraryError> {
        let _guard = self.lock.lock().await;
        let mut catalog = self.load_catalog().await?;
        self.reconcile(&mut catalog).await?;
        self.save_catalog(&catalog).await?;
        Ok(catalog.documents)
    }

    pub async fn get(&self, id: &str) -> Result<LibraryDocumentRecord, LibraryError> {
        if !valid_id(id) {
            return Err(LibraryError::InvalidName);
        }
        let documents = self.list().await?;
        documents
            .into_iter()
            .find(|document| document.id == id)
            .ok_or(LibraryError::NotFound)
    }

    pub async fn ingest(
        &self,
        file_name: String,
        content: &[u8],
    ) -> Result<LibraryDocumentRecord, LibraryError> {
        if file_name.is_empty() || file_name.len() > 255 || file_name.contains(['/', '\\']) {
            return Err(LibraryError::InvalidName);
        }
        let Some(detected) = detect_format(&file_name) else {
            return Err(LibraryError::Unsupported);
        };

        let _guard = self.lock.lock().await;
        tokio::fs::create_dir_all(self.files_dir())
            .await
            .map_err(|_| LibraryError::Io)?;

        let now_ms = unix_ms();
        let sequence = FILE_SEQUENCE.fetch_add(1, Ordering::Relaxed);
        let extension = file_name.rsplit_once('.').map_or("bin", |(_, value)| value);
        let id = format!("{now_ms}-{sequence}");
        let stored_name = format!("{id}.{extension}");
        let stored_path = self.files_dir().join(&stored_name);
        tokio::fs::write(&stored_path, content)
            .await
            .map_err(|_| LibraryError::Io)?;

        let record = LibraryDocumentRecord {
            id,
            title: title_from_file_name(&file_name),
            file_name,
            stored_name,
            author: String::new(),
            format: detected.format.to_string(),
            document_type: detected.document_type.to_string(),
            size: content.len(),
            cover_color: cover_color_for(&stored_path),
            progress: 0.0,
            last_opened_ms: now_ms,
        };

        let mut catalog = self.load_catalog().await?;
        catalog.documents.insert(0, record.clone());
        self.save_catalog(&catalog).await?;
        Ok(record)
    }

    pub async fn read_file(
        &self,
        id: &str,
    ) -> Result<(LibraryDocumentRecord, Vec<u8>), LibraryError> {
        let record = self.get(id).await?;
        let path = self.files_dir().join(&record.stored_name);
        let bytes = tokio::fs::read(path)
            .await
            .map_err(|_| LibraryError::NotFound)?;
        Ok((record, bytes))
    }

    pub async fn update_progress(
        &self,
        id: &str,
        progress: f64,
    ) -> Result<LibraryDocumentRecord, LibraryError> {
        if !valid_id(id) {
            return Err(LibraryError::InvalidName);
        }
        let _guard = self.lock.lock().await;
        let mut catalog = self.load_catalog().await?;
        let Some(document) = catalog
            .documents
            .iter_mut()
            .find(|document| document.id == id)
        else {
            return Err(LibraryError::NotFound);
        };
        document.progress = progress.clamp(0.0, 1.0);
        document.last_opened_ms = unix_ms();
        let updated = document.clone();
        self.save_catalog(&catalog).await?;
        Ok(updated)
    }

    pub async fn delete(&self, id: &str) -> Result<LibraryDocumentRecord, LibraryError> {
        if !valid_id(id) {
            return Err(LibraryError::InvalidName);
        }
        let _guard = self.lock.lock().await;
        let mut catalog = self.load_catalog().await?;
        let Some(index) = catalog
            .documents
            .iter()
            .position(|document| document.id == id)
        else {
            return Err(LibraryError::NotFound);
        };
        let record = catalog.documents.remove(index);
        let path = self.files_dir().join(&record.stored_name);
        let _ = tokio::fs::remove_file(path).await;
        self.save_catalog(&catalog).await?;
        Ok(record)
    }

    async fn load_catalog(&self) -> Result<Catalog, LibraryError> {
        match tokio::fs::read(self.catalog_path()).await {
            Ok(bytes) => Ok(serde_json::from_slice(&bytes).unwrap_or_default()),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(Catalog::default()),
            Err(_) => Err(LibraryError::Io),
        }
    }

    async fn save_catalog(&self, catalog: &Catalog) -> Result<(), LibraryError> {
        tokio::fs::create_dir_all(&self.root)
            .await
            .map_err(|_| LibraryError::Io)?;
        let payload = serde_json::to_vec_pretty(catalog).map_err(|_| LibraryError::Io)?;
        tokio::fs::write(self.catalog_path(), payload)
            .await
            .map_err(|_| LibraryError::Io)
    }

    async fn reconcile(&self, catalog: &mut Catalog) -> Result<(), LibraryError> {
        let files_dir = self.files_dir();
        catalog
            .documents
            .retain(|document| files_dir.join(&document.stored_name).is_file());

        let Ok(mut entries) = tokio::fs::read_dir(&files_dir).await else {
            return Ok(());
        };
        while let Ok(Some(entry)) = entries.next_entry().await {
            let name = entry.file_name();
            let Some(name) = name.to_str() else {
                continue;
            };
            let Some((id, ext)) = name.rsplit_once('.') else {
                continue;
            };
            if !valid_id(id) || detect_format(name).is_none() {
                continue;
            }
            if catalog.documents.iter().any(|document| document.id == id) {
                continue;
            }
            let Ok(meta) = entry.metadata().await else {
                continue;
            };
            let detected = detect_format(name).expect("format checked above");
            catalog.documents.push(LibraryDocumentRecord {
                id: id.to_string(),
                file_name: name.to_string(),
                stored_name: name.to_string(),
                title: title_from_file_name(name),
                author: String::new(),
                format: detected.format.to_string(),
                document_type: detected.document_type.to_string(),
                size: meta.len() as usize,
                cover_color: cover_color_for(Path::new(name)),
                progress: 0.0,
                last_opened_ms: unix_ms(),
            });
            let _ = ext;
        }
        Ok(())
    }
}

pub fn content_type_for(format: &str) -> &'static str {
    match format {
        "epub" => "application/epub+zip",
        "pdf" => "application/pdf",
        "txt" => "text/plain; charset=utf-8",
        "markdown" => "text/markdown; charset=utf-8",
        "html" => "text/html; charset=utf-8",
        _ => "application/octet-stream",
    }
}

pub fn valid_id(id: &str) -> bool {
    !id.is_empty()
        && id.len() <= 128
        && !id.contains("..")
        && id
            .chars()
            .all(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_' | '.'))
}

fn title_from_file_name(file_name: &str) -> String {
    file_name
        .rsplit_once('.')
        .map(|(stem, _)| stem)
        .filter(|stem| !stem.is_empty())
        .unwrap_or(file_name)
        .to_string()
}

fn cover_color_for(path: &Path) -> u32 {
    const PALETTE: [u32; 6] = [
        0xFF2F5B57, 0xFFC4A574, 0xFF4F7C8A, 0xFF8B5A4A, 0xFF6F8179, 0xFF3D4A4C,
    ];
    let seed = path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or_default();
    let hash = seed.bytes().fold(0u32, |acc, byte| {
        acc.wrapping_mul(31).wrapping_add(byte as u32)
    });
    PALETTE[hash as usize % PALETTE.len()]
}

fn unix_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |duration| duration.as_millis() as u64)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_path_escape_ids() {
        assert!(!valid_id("../secret"));
        assert!(!valid_id("a/b"));
        assert!(valid_id("1756-0"));
    }

    #[test]
    fn titles_drop_the_extension() {
        assert_eq!(title_from_file_name("Design.epub"), "Design");
    }
}
