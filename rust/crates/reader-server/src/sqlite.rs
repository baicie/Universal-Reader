use std::path::Path;

use rusqlite::Connection;

use crate::library::LibraryError;

const SCHEMA: &str = r#"
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
