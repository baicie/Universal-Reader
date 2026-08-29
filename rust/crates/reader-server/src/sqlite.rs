use std::path::Path;

use rusqlite::Connection;

use crate::library::{LibraryDocumentRecord, LibraryError};

const CATALOG_MIGRATED: &str = "catalog_migrated";

const SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS documents (
  id TEXT PRIMARY KEY,
  file_name TEXT NOT NULL,
  stored_name TEXT NOT NULL,
  title TEXT NOT NULL,
  author TEXT NOT NULL,
  format TEXT NOT NULL,
  document_type TEXT NOT NULL,
  size INTEGER NOT NULL,
  cover_color INTEGER NOT NULL,
  progress REAL NOT NULL,
  last_opened_ms INTEGER NOT NULL,
  content_hash TEXT NOT NULL,
  has_cover INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS annotations (
  document_id TEXT NOT NULL,
  id TEXT NOT NULL,
  note TEXT NOT NULL,
  quote TEXT NOT NULL,
  locator_label TEXT NOT NULL,
  source TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY (document_id, id)
);
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS conversations (
  document_id TEXT PRIMARY KEY,
  turns_json TEXT NOT NULL
);
CREATE VIRTUAL TABLE IF NOT EXISTS document_fts USING fts5(
  document_id UNINDEXED,
  locator,
  title,
  body,
  tokenize = 'unicode61'
);
"#;

pub fn open(root: &Path) -> Result<Connection, LibraryError> {
    std::fs::create_dir_all(root).map_err(|_| LibraryError::Io)?;
    let conn = Connection::open(root.join("library.sqlite")).map_err(|_| LibraryError::Io)?;
    conn.execute_batch(SCHEMA).map_err(|_| LibraryError::Io)?;
    Ok(conn)
}

pub fn get_setting(conn: &Connection, key: &str) -> Result<Option<String>, rusqlite::Error> {
    let mut stmt = conn.prepare("SELECT value FROM settings WHERE key = ?1")?;
    let mut rows = stmt.query(rusqlite::params![key])?;
    match rows.next()? {
        Some(row) => Ok(Some(row.get(0)?)),
        None => Ok(None),
    }
}

pub fn set_setting(conn: &Connection, key: &str, value: &str) -> Result<(), rusqlite::Error> {
    conn.execute(
        "INSERT INTO settings (key, value) VALUES (?1, ?2) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        rusqlite::params![key, value],
    )?;
    Ok(())
}

pub fn load_documents(conn: &Connection) -> Result<Vec<LibraryDocumentRecord>, LibraryError> {
    let mut stmt = conn
        .prepare(
            "SELECT id, file_name, stored_name, title, author, format, document_type, size, cover_color, progress, last_opened_ms, content_hash, has_cover FROM documents",
        )
        .map_err(|_| LibraryError::Io)?;
    let rows = stmt
        .query_map([], |row| {
            Ok(LibraryDocumentRecord {
                id: row.get(0)?,
                file_name: row.get(1)?,
                stored_name: row.get(2)?,
                title: row.get(3)?,
                author: row.get(4)?,
                format: row.get(5)?,
                document_type: row.get(6)?,
                size: row.get::<_, i64>(7)? as usize,
                cover_color: row.get::<_, i64>(8)? as u32,
                progress: row.get(9)?,
                last_opened_ms: row.get::<_, i64>(10)? as u64,
                content_hash: row.get(11)?,
                has_cover: row.get::<_, i64>(12)? != 0,
            })
        })
        .map_err(|_| LibraryError::Io)?;
    rows.collect::<Result<Vec<_>, _>>()
        .map_err(|_| LibraryError::Io)
}

pub fn replace_documents(
    conn: &mut Connection,
    documents: &[LibraryDocumentRecord],
) -> Result<(), LibraryError> {
    let tx = conn.transaction().map_err(|_| LibraryError::Io)?;
    tx.execute("DELETE FROM documents", [])
        .map_err(|_| LibraryError::Io)?;
    for document in documents {
        tx.execute(
            "INSERT INTO documents (id, file_name, stored_name, title, author, format, document_type, size, cover_color, progress, last_opened_ms, content_hash, has_cover) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)",
            rusqlite::params![
                document.id,
                document.file_name,
                document.stored_name,
                document.title,
                document.author,
                document.format,
                document.document_type,
                document.size as i64,
                document.cover_color as i64,
                document.progress,
                document.last_opened_ms as i64,
                document.content_hash,
                document.has_cover as i64,
            ],
        )
        .map_err(|_| LibraryError::Io)?;
    }
    tx.commit().map_err(|_| LibraryError::Io)?;
    Ok(())
}

pub fn migrate_catalog_once(
    conn: &mut Connection,
    legacy: Option<&[LibraryDocumentRecord]>,
) -> Result<(), LibraryError> {
    if get_setting(conn, CATALOG_MIGRATED)
        .map_err(|_| LibraryError::Io)?
        .as_deref()
        == Some("1")
    {
        return Ok(());
    }
    if documents_empty(conn)?
        && let Some(documents) = legacy
    {
        replace_documents(conn, documents)?;
    }
    mark_catalog_migrated(conn)
}

pub fn mark_catalog_migrated(conn: &Connection) -> Result<(), LibraryError> {
    set_setting(conn, CATALOG_MIGRATED, "1").map_err(|_| LibraryError::Io)
}

fn documents_empty(conn: &Connection) -> Result<bool, LibraryError> {
    let count: i64 = conn
        .query_row("SELECT COUNT(*) FROM documents", [], |row| row.get(0))
        .map_err(|_| LibraryError::Io)?;
    Ok(count == 0)
}

pub fn load_conversation_json(
    conn: &Connection,
    document_id: &str,
) -> Result<Option<String>, LibraryError> {
    let mut stmt = conn
        .prepare("SELECT turns_json FROM conversations WHERE document_id = ?1")
        .map_err(|_| LibraryError::Io)?;
    let mut rows = stmt
        .query(rusqlite::params![document_id])
        .map_err(|_| LibraryError::Io)?;
    match rows.next().map_err(|_| LibraryError::Io)? {
        Some(row) => Ok(Some(row.get(0).map_err(|_| LibraryError::Io)?)),
        None => Ok(None),
    }
}

pub fn save_conversation_json(
    conn: &Connection,
    document_id: &str,
    turns_json: &str,
) -> Result<(), LibraryError> {
    conn.execute(
        "INSERT INTO conversations (document_id, turns_json) VALUES (?1, ?2) ON CONFLICT(document_id) DO UPDATE SET turns_json = excluded.turns_json",
        rusqlite::params![document_id, turns_json],
    )
    .map_err(|_| LibraryError::Io)?;
    Ok(())
}

pub fn delete_conversation(conn: &Connection, document_id: &str) -> Result<(), LibraryError> {
    conn.execute(
        "DELETE FROM conversations WHERE document_id = ?1",
        [document_id],
    )
    .map_err(|_| LibraryError::Io)?;
    Ok(())
}
