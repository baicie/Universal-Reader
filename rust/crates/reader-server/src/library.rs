use std::{
    collections::HashSet,
    path::{Path, PathBuf},
    sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    },
    time::{SystemTime, UNIX_EPOCH},
};

use serde::{Deserialize, Serialize};
use tokio::sync::Mutex;

use crate::{detect_format, extract, sources, sqlite};

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
    #[serde(default)]
    pub content_hash: String,
    #[serde(default)]
    pub has_cover: bool,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Conversation {
    #[serde(default)]
    pub turns: Vec<ConversationTurn>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SearchHit {
    pub locator: String,
    pub title: String,
    pub excerpt: String,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Annotations {
    #[serde(default)]
    pub notes: Vec<AnnotationRecord>,
}

const MAX_COLLECTIONS: usize = 50;
const MAX_COLLECTION_NAME: usize = 40;

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Shelves {
    #[serde(default)]
    pub favorites: Vec<String>,
    #[serde(default)]
    pub collections: Vec<ShelfCollection>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ShelfCollection {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub color: u32,
    #[serde(default, alias = "documentIds")]
    pub document_ids: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AnnotationRecord {
    pub id: String,
    #[serde(default)]
    pub note: String,
    #[serde(default)]
    pub quote: String,
    #[serde(default, alias = "locatorLabel")]
    pub locator_label: String,
    #[serde(default)]
    pub source: String,
    #[serde(default, alias = "createdAtMs")]
    pub created_at_ms: u64,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ConversationTurn {
    pub kind: String,
    #[serde(default)]
    pub question: String,
    pub reply: String,
    #[serde(default, alias = "locatorLabel")]
    pub locator_label: String,
    #[serde(default, alias = "createdAtMs")]
    pub created_at_ms: u64,
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

    pub fn covers_dir(&self) -> PathBuf {
        self.root.join("covers")
    }

    async fn write_cover_locked(&self, id: &str, bytes: &[u8]) -> Result<(), LibraryError> {
        tokio::fs::create_dir_all(self.covers_dir())
            .await
            .map_err(|_| LibraryError::Io)?;
        tokio::fs::write(self.covers_dir().join(id), bytes)
            .await
            .map_err(|_| LibraryError::Io)
    }

    pub async fn read_cover(&self, id: &str) -> Result<Vec<u8>, LibraryError> {
        if !valid_id(id) {
            return Err(LibraryError::InvalidName);
        }
        let record = self.get(id).await?;
        if !record.has_cover {
            return Err(LibraryError::NotFound);
        }
        tokio::fs::read(self.covers_dir().join(id))
            .await
            .map_err(|_| LibraryError::NotFound)
    }

    pub async fn ingest_path(
        &self,
        path: &Path,
    ) -> Result<Option<LibraryDocumentRecord>, LibraryError> {
        let Some(name) = path.file_name().and_then(|value| value.to_str()) else {
            return Ok(None);
        };
        if detect_format(name).is_none() {
            return Ok(None);
        }
        let bytes = match tokio::fs::read(path).await {
            Ok(bytes) if bytes.len() <= 64 * 1024 * 1024 => bytes,
            _ => return Ok(None),
        };
        self.ingest_if_new(name.to_string(), &bytes).await
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

        let hash = content_hash(content);
        let _guard = self.lock.lock().await;
        let catalog = self.load_catalog().await?;
        if let Some(existing) = catalog
            .documents
            .iter()
            .find(|document| !document.content_hash.is_empty() && document.content_hash == hash)
        {
            return Ok(existing.clone());
        }
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
        let cover = extract::extract_cover(&file_name, content);
        if let Some(bytes) = &cover {
            self.write_cover_locked(&id, bytes).await?;
        }
        let identity = extract::document_identity(&file_name, content);

        let record = LibraryDocumentRecord {
            id,
            title: identity.title,
            file_name,
            stored_name,
            author: identity.author,
            format: detected.format.to_string(),
            document_type: detected.document_type.to_string(),
            size: content.len(),
            cover_color: cover_color_for(&stored_path),
            progress: 0.0,
            last_opened_ms: now_ms,
            content_hash: hash,
            has_cover: cover.is_some(),
        };

        let mut catalog = self.load_catalog().await?;
        catalog.documents.insert(0, record.clone());
        self.save_catalog(&catalog).await?;
        self.reindex_locked(&record.id, &record.file_name, content)?;
        Ok(record)
    }

    pub async fn ingest_if_new(
        &self,
        file_name: String,
        content: &[u8],
    ) -> Result<Option<LibraryDocumentRecord>, LibraryError> {
        {
            let documents = self.list().await?;
            let hash = content_hash(content);
            if documents
                .iter()
                .any(|document| !document.content_hash.is_empty() && document.content_hash == hash)
            {
                return Ok(None);
            }
            if sources::should_skip(
                &documents
                    .iter()
                    .map(|document| document.file_name.clone())
                    .collect::<Vec<_>>(),
                &file_name,
            ) {
                return Ok(None);
            }
        }
        Ok(Some(self.ingest(file_name, content).await?))
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
        self.update_document(id, Some(progress), None, None).await
    }

    pub async fn update_document(
        &self,
        id: &str,
        progress: Option<f64>,
        title: Option<String>,
        author: Option<String>,
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
        if let Some(progress) = progress {
            document.progress = progress.clamp(0.0, 1.0);
            document.last_opened_ms = unix_ms();
        }
        if let Some(title) = title {
            document.title = title_for_write(&title, &document.title);
        }
        if let Some(author) = author {
            document.author = author_for_write(&author);
        }
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
        let _ = tokio::fs::remove_file(self.covers_dir().join(id)).await;
        self.save_catalog(&catalog).await?;
        let _ = tokio::fs::remove_file(self.conversation_path(id)).await;
        if let Ok(conn) = sqlite::open(&self.root) {
            let _ = conn.execute("DELETE FROM document_fts WHERE document_id = ?1", [id]);
            let _ = conn.execute("DELETE FROM annotations WHERE document_id = ?1", [id]);
            let _ = sqlite::delete_conversation(&conn, id);
            let known: HashSet<String> = catalog.documents.iter().map(|d| d.id.clone()).collect();
            if let Ok(Some(raw)) = sqlite::get_setting(&conn, "shelves")
                && let Ok(shelves) = serde_json::from_str::<Shelves>(&raw)
                && let Ok(encoded) = serde_json::to_string(&prune_shelves(shelves, &known))
            {
                let _ = sqlite::set_setting(&conn, "shelves", &encoded);
            }
        }
        Ok(record)
    }

    pub async fn search_document(
        &self,
        id: &str,
        query: &str,
    ) -> Result<Vec<SearchHit>, LibraryError> {
        if !valid_id(id) {
            return Err(LibraryError::InvalidName);
        }
        let _ = self.get(id).await?;
        let needle = query.replace('"', " ");
        let needle = needle.trim();
        if needle.is_empty() {
            return Ok(Vec::new());
        }
        let _guard = self.lock.lock().await;
        let conn = sqlite::open(&self.root)?;
        let mut stmt = conn
            .prepare(
                "SELECT locator, title, body FROM document_fts WHERE document_fts MATCH ?1 AND document_id = ?2 LIMIT 10",
            )
            .map_err(|_| LibraryError::Io)?;
        let match_query = format!("\"{needle}\"");
        let rows = stmt
            .query_map(rusqlite::params![match_query, id], |row| {
                Ok(SearchHit {
                    locator: row.get(0)?,
                    title: row.get(1)?,
                    excerpt: row.get::<_, String>(2)?.chars().take(180).collect(),
                })
            })
            .map_err(|_| LibraryError::Io)?;
        rows.collect::<Result<Vec<_>, _>>()
            .map_err(|_| LibraryError::Io)
    }

    pub async fn load_annotations(&self, id: &str) -> Result<Annotations, LibraryError> {
        if !valid_id(id) {
            return Err(LibraryError::InvalidName);
        }
        let _ = self.get(id).await?;
        let _guard = self.lock.lock().await;
        let conn = sqlite::open(&self.root)?;
        let mut stmt = conn
            .prepare(
                "SELECT id, note, quote, locator_label, source, created_at_ms FROM annotations WHERE document_id = ?1 ORDER BY created_at_ms",
            )
            .map_err(|_| LibraryError::Io)?;
        let rows = stmt
            .query_map([id], |row| {
                Ok(AnnotationRecord {
                    id: row.get(0)?,
                    note: row.get(1)?,
                    quote: row.get(2)?,
                    locator_label: row.get(3)?,
                    source: row.get(4)?,
                    created_at_ms: row.get(5)?,
                })
            })
            .map_err(|_| LibraryError::Io)?;
        Ok(Annotations {
            notes: rows
                .collect::<Result<Vec<_>, _>>()
                .map_err(|_| LibraryError::Io)?,
        })
    }

    pub async fn save_annotations(
        &self,
        id: &str,
        mut annotations: Annotations,
    ) -> Result<Annotations, LibraryError> {
        if !valid_id(id) {
            return Err(LibraryError::InvalidName);
        }
        if annotations.notes.len() > 100 {
            annotations.notes.drain(0..annotations.notes.len() - 100);
        }
        let _ = self.get(id).await?;
        let _guard = self.lock.lock().await;
        let conn = sqlite::open(&self.root)?;
        conn.execute("DELETE FROM annotations WHERE document_id = ?1", [id])
            .map_err(|_| LibraryError::Io)?;
        for note in &annotations.notes {
            conn.execute(
                "INSERT INTO annotations (document_id, id, note, quote, locator_label, source, created_at_ms) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                rusqlite::params![
                    id,
                    note.id,
                    note.note,
                    note.quote,
                    note.locator_label,
                    note.source,
                    note.created_at_ms as i64
                ],
            )
            .map_err(|_| LibraryError::Io)?;
        }
        Ok(annotations)
    }

    pub async fn load_shelves(&self) -> Result<Shelves, LibraryError> {
        let documents = self.list().await?;
        let known: HashSet<String> = documents.into_iter().map(|document| document.id).collect();
        let _guard = self.lock.lock().await;
        self.read_shelves_locked(&known)
    }

    pub async fn save_shelves(&self, shelves: Shelves) -> Result<Shelves, LibraryError> {
        let documents = self.list().await?;
        let known: HashSet<String> = documents.into_iter().map(|document| document.id).collect();
        let pruned = prune_shelves(shelves, &known);
        let _guard = self.lock.lock().await;
        let conn = sqlite::open(&self.root)?;
        let raw = serde_json::to_string(&pruned).map_err(|_| LibraryError::Io)?;
        sqlite::set_setting(&conn, "shelves", &raw).map_err(|_| LibraryError::Io)?;
        Ok(pruned)
    }

    fn read_shelves_locked(&self, known: &HashSet<String>) -> Result<Shelves, LibraryError> {
        let conn = sqlite::open(&self.root)?;
        let raw = sqlite::get_setting(&conn, "shelves").map_err(|_| LibraryError::Io)?;
        let shelves = match raw {
            None => Shelves::default(),
            Some(value) if value.is_empty() => Shelves::default(),
            Some(value) => serde_json::from_str(&value).map_err(|_| LibraryError::Io)?,
        };
        Ok(prune_shelves(shelves, known))
    }

    fn reindex_locked(
        &self,
        id: &str,
        file_name: &str,
        content: &[u8],
    ) -> Result<(), LibraryError> {
        let conn = sqlite::open(&self.root)?;
        conn.execute("DELETE FROM document_fts WHERE document_id = ?1", [id])
            .map_err(|_| LibraryError::Io)?;
        let Some(units) = extract::extract_units(file_name, content) else {
            return Ok(());
        };
        for unit in units {
            conn.execute(
                "INSERT INTO document_fts (document_id, locator, title, body) VALUES (?1, ?2, ?3, ?4)",
                rusqlite::params![id, unit.locator, unit.title, unit.body],
            )
            .map_err(|_| LibraryError::Io)?;
        }
        Ok(())
    }

    pub async fn load_conversation(&self, id: &str) -> Result<Conversation, LibraryError> {
        if !valid_id(id) {
            return Err(LibraryError::InvalidName);
        }
        let _guard = self.lock.lock().await;
        let catalog = self.load_catalog().await?;
        if !catalog.documents.iter().any(|document| document.id == id) {
            return Err(LibraryError::NotFound);
        }
        let conn = sqlite::open(&self.root)?;
        if let Some(raw) = sqlite::load_conversation_json(&conn, id)? {
            return serde_json::from_str(&raw).map_err(|_| LibraryError::Io);
        }
        match tokio::fs::read(self.conversation_path(id)).await {
            Ok(bytes) => {
                let conversation: Conversation =
                    serde_json::from_slice(&bytes).map_err(|_| LibraryError::Io)?;
                let encoded = serde_json::to_string(&conversation).map_err(|_| LibraryError::Io)?;
                sqlite::save_conversation_json(&conn, id, &encoded)?;
                Ok(conversation)
            }
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                Ok(Conversation::default())
            }
            Err(_) => Err(LibraryError::Io),
        }
    }

    pub async fn save_conversation(
        &self,
        id: &str,
        mut conversation: Conversation,
    ) -> Result<Conversation, LibraryError> {
        if !valid_id(id) {
            return Err(LibraryError::InvalidName);
        }
        if conversation.turns.len() > 50 {
            conversation.turns.drain(0..conversation.turns.len() - 50);
        }
        let _guard = self.lock.lock().await;
        let catalog = self.load_catalog().await?;
        if !catalog.documents.iter().any(|document| document.id == id) {
            return Err(LibraryError::NotFound);
        }
        let encoded = serde_json::to_string(&conversation).map_err(|_| LibraryError::Io)?;
        let conn = sqlite::open(&self.root)?;
        sqlite::save_conversation_json(&conn, id, &encoded)?;
        Ok(conversation)
    }

    fn conversations_dir(&self) -> PathBuf {
        self.root.join("conversations")
    }

    fn conversation_path(&self, id: &str) -> PathBuf {
        self.conversations_dir().join(format!("{id}.json"))
    }

    async fn load_catalog(&self) -> Result<Catalog, LibraryError> {
        let legacy = self.read_legacy_catalog_json().await?;
        let mut conn = sqlite::open(&self.root)?;
        sqlite::migrate_catalog_once(
            &mut conn,
            legacy.as_ref().map(|catalog| catalog.documents.as_slice()),
        )?;
        Ok(Catalog {
            documents: sqlite::load_documents(&conn)?,
        })
    }

    async fn save_catalog(&self, catalog: &Catalog) -> Result<(), LibraryError> {
        let mut conn = sqlite::open(&self.root)?;
        sqlite::replace_documents(&mut conn, &catalog.documents)?;
        sqlite::mark_catalog_migrated(&conn)
    }

    async fn read_legacy_catalog_json(&self) -> Result<Option<Catalog>, LibraryError> {
        match tokio::fs::read(self.catalog_path()).await {
            Ok(bytes) => match serde_json::from_slice::<Catalog>(&bytes) {
                Ok(catalog) if !catalog.documents.is_empty() => Ok(Some(catalog)),
                _ => Ok(None),
            },
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(None),
            Err(_) => Err(LibraryError::Io),
        }
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
                content_hash: String::new(),
                has_cover: false,
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

fn prune_shelves(mut shelves: Shelves, known: &HashSet<String>) -> Shelves {
    shelves.favorites = unique_known(shelves.favorites, known);
    let mut collections = Vec::new();
    for mut collection in shelves.collections {
        if collection.id.is_empty() {
            continue;
        }
        collection.name = collection
            .name
            .trim()
            .chars()
            .take(MAX_COLLECTION_NAME)
            .collect();
        if collection.name.is_empty() {
            continue;
        }
        collection.document_ids = unique_known(collection.document_ids, known);
        collections.push(collection);
        if collections.len() == MAX_COLLECTIONS {
            break;
        }
    }
    shelves.collections = collections;
    shelves
}

fn unique_known(ids: Vec<String>, known: &HashSet<String>) -> Vec<String> {
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    for id in ids {
        if known.contains(&id) && seen.insert(id.clone()) {
            out.push(id);
        }
    }
    out
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

const MAX_IDENTITY_LEN: usize = 200;

fn clip_identity(value: &str) -> String {
    value.chars().take(MAX_IDENTITY_LEN).collect()
}

fn title_for_write(requested: &str, current: &str) -> String {
    let trimmed = requested.trim();
    if trimmed.is_empty() {
        current.to_string()
    } else {
        clip_identity(trimmed)
    }
}

fn author_for_write(requested: &str) -> String {
    clip_identity(requested.trim())
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

pub fn content_hash(bytes: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    Sha256::digest(bytes)
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
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

    #[tokio::test]
    async fn ingest_skips_the_same_bytes_under_a_new_name() {
        let dir = std::env::temp_dir().join(format!(
            "universal-reader-hash-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let store = LibraryStore::new(dir.clone());
        let first = store
            .ingest("one.txt".to_string(), b"same-bytes")
            .await
            .unwrap();
        let second = store
            .ingest("two.txt".to_string(), b"same-bytes")
            .await
            .unwrap();
        assert_eq!(first.id, second.id);
        let skipped = store
            .ingest_if_new("three.txt".to_string(), b"same-bytes")
            .await
            .unwrap();
        assert!(skipped.is_none());
        let files: Vec<_> = std::fs::read_dir(store.files_dir()).unwrap().collect();
        assert_eq!(files.len(), 1);
        let _ = tokio::fs::remove_dir_all(dir).await;
    }

    #[tokio::test]
    async fn ingest_uses_epub_opf_title_instead_of_the_file_name() {
        let dir = unique_temp("epub-identity");
        let store = LibraryStore::new(dir.clone());
        let record = store
            .ingest(
                "story.epub".to_string(),
                &crate::extract::test_minimal_epub("设计中的设计", "原研哉"),
            )
            .await
            .unwrap();
        assert_eq!(record.title, "设计中的设计");
        assert_eq!(record.author, "原研哉");
        let _ = tokio::fs::remove_dir_all(dir).await;
    }

    #[tokio::test]
    async fn conversation_store_keeps_the_latest_fifty_turns_for_one_book() {
        let dir = std::env::temp_dir().join(format!(
            "universal-reader-conv-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let store = LibraryStore::new(dir.clone());
        let record = store
            .ingest("notes.txt".to_string(), b"hello")
            .await
            .unwrap();
        let conversation = Conversation {
            turns: (0u64..51)
                .map(|index| ConversationTurn {
                    kind: "ask".into(),
                    question: String::new(),
                    reply: format!("r{index}"),
                    locator_label: String::new(),
                    created_at_ms: index,
                })
                .collect(),
        };
        let saved = store
            .save_conversation(&record.id, conversation)
            .await
            .unwrap();
        assert_eq!(saved.turns.len(), 50);
        assert_eq!(saved.turns.first().unwrap().reply, "r1");
        assert_eq!(saved.turns.last().unwrap().reply, "r50");
        let missing = store
            .save_conversation("missing-id", Conversation::default())
            .await;
        assert!(matches!(missing, Err(LibraryError::NotFound)));
        assert!(
            !dir.join("conversations")
                .join(format!("{}.json", record.id))
                .is_file()
        );
        tokio::fs::create_dir_all(dir.join("conversations"))
            .await
            .unwrap();
        tokio::fs::write(
            dir.join("conversations")
                .join(format!("{}.json", record.id)),
            br#"{"turns":[{"kind":"ask","question":"","reply":"poison","locator_label":"","created_at_ms":1}]}"#,
        )
        .await
        .unwrap();
        let loaded = LibraryStore::new(dir.clone())
            .load_conversation(&record.id)
            .await
            .unwrap();
        assert_eq!(loaded.turns.len(), 50);
        assert_eq!(loaded.turns.last().unwrap().reply, "r50");
        let _ = tokio::fs::remove_dir_all(dir).await;
    }

    #[tokio::test]
    async fn corrupt_conversation_json_is_an_error_not_an_empty_history() {
        let dir = std::env::temp_dir().join(format!(
            "universal-reader-conv-corrupt-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let store = LibraryStore::new(dir.clone());
        let record = store
            .ingest("notes.txt".to_string(), b"hello")
            .await
            .unwrap();
        let path = dir
            .join("conversations")
            .join(format!("{}.json", record.id));
        tokio::fs::create_dir_all(path.parent().unwrap())
            .await
            .unwrap();
        tokio::fs::write(&path, b"{not-json").await.unwrap();
        let loaded = store.load_conversation(&record.id).await;
        assert!(matches!(loaded, Err(LibraryError::Io)));
        let _ = tokio::fs::remove_dir_all(dir).await;
    }

    #[tokio::test]
    async fn sqlite_catalog_keeps_title_and_progress_when_json_is_poisoned() {
        let dir = unique_temp("sqlite-wins");
        let store = LibraryStore::new(dir.clone());
        let record = store
            .ingest("notes.txt".to_string(), b"hello")
            .await
            .unwrap();
        store.update_progress(&record.id, 0.4).await.unwrap();
        assert!(!dir.join("catalog.json").is_file());

        tokio::fs::write(
            dir.join("catalog.json"),
            poisoned_catalog_json(&record, "设计中的设计", 0.0),
        )
        .await
        .unwrap();

        let listed = LibraryStore::new(dir.clone()).list().await.unwrap();
        assert_eq!(listed.len(), 1);
        assert_eq!(listed[0].id, record.id);
        assert_eq!(listed[0].title, "notes");
        assert!((listed[0].progress - 0.4).abs() < 1e-9);
        let _ = tokio::fs::remove_dir_all(dir).await;
    }

    #[tokio::test]
    async fn ingest_title_survives_after_catalog_json_is_gone() {
        let dir = unique_temp("sqlite-no-json");
        let store = LibraryStore::new(dir.clone());
        let record = store
            .ingest("notes.txt".to_string(), b"hello")
            .await
            .unwrap();
        assert!(!dir.join("catalog.json").is_file());

        let listed = LibraryStore::new(dir.clone()).list().await.unwrap();
        assert_eq!(listed.len(), 1);
        assert_eq!(listed[0].id, record.id);
        assert_eq!(listed[0].title, "notes");
        let _ = tokio::fs::remove_dir_all(dir).await;
    }

    #[tokio::test]
    async fn empty_sqlite_imports_legacy_catalog_json_once() {
        let dir = unique_temp("legacy-json");
        tokio::fs::create_dir_all(dir.join("files")).await.unwrap();
        tokio::fs::write(dir.join("files").join("9-0.txt"), b"legacy")
            .await
            .unwrap();
        tokio::fs::write(
            dir.join("catalog.json"),
            r#"{
              "documents": [{
                "id": "9-0",
                "file_name": "notes.txt",
                "stored_name": "9-0.txt",
                "title": "notes",
                "author": "",
                "format": "txt",
                "document_type": "reflow",
                "size": 6,
                "cover_color": 1,
                "progress": 0.37,
                "last_opened_ms": 1,
                "content_hash": "abc",
                "has_cover": false
              }]
            }"#,
        )
        .await
        .unwrap();

        let listed = LibraryStore::new(dir.clone()).list().await.unwrap();
        assert_eq!(listed.len(), 1);
        assert_eq!(listed[0].id, "9-0");
        assert_eq!(listed[0].title, "notes");
        assert!((listed[0].progress - 0.37).abs() < 1e-9);

        tokio::fs::write(
            dir.join("catalog.json"),
            poisoned_catalog_json(&listed[0], "设计中的设计", 0.0),
        )
        .await
        .unwrap();
        let listed = LibraryStore::new(dir.clone()).list().await.unwrap();
        assert_eq!(listed[0].title, "notes");
        assert!((listed[0].progress - 0.37).abs() < 1e-9);
        let _ = tokio::fs::remove_dir_all(dir).await;
    }

    #[tokio::test]
    async fn update_document_renames_without_inventing_a_book() {
        let dir = unique_temp("rename-title");
        let store = LibraryStore::new(dir.clone());
        let record = store
            .ingest("notes.txt".to_string(), b"hello")
            .await
            .unwrap();
        store
            .update_document(
                &record.id,
                None,
                Some("  设计笔记  ".into()),
                Some("  某作者  ".into()),
            )
            .await
            .unwrap();
        let listed = store.list().await.unwrap();
        assert_eq!(listed.len(), 1);
        assert_eq!(listed[0].title, "设计笔记");
        assert_eq!(listed[0].author, "某作者");

        store
            .update_document(&record.id, None, Some("   ".into()), Some("".into()))
            .await
            .unwrap();
        let listed = store.list().await.unwrap();
        assert_eq!(listed[0].title, "设计笔记");
        assert_eq!(listed[0].author, "");

        let missing = store
            .update_document("9-999", None, Some("设计中的设计".into()), None)
            .await;
        assert!(matches!(missing, Err(LibraryError::NotFound)));
        let listed = store.list().await.unwrap();
        assert_eq!(listed.len(), 1);
        assert_eq!(listed[0].title, "设计笔记");
        let _ = tokio::fs::remove_dir_all(dir).await;
    }

    fn unique_temp(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!(
            "universal-reader-{name}-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ))
    }

    fn poisoned_catalog_json(record: &LibraryDocumentRecord, title: &str, progress: f64) -> String {
        serde_json::json!({
            "documents": [{
                "id": record.id,
                "file_name": record.file_name,
                "stored_name": record.stored_name,
                "title": title,
                "author": "",
                "format": "txt",
                "document_type": "reflow",
                "size": record.size,
                "cover_color": record.cover_color,
                "progress": progress,
                "last_opened_ms": 0,
                "content_hash": record.content_hash,
                "has_cover": false
            }]
        })
        .to_string()
    }
}
