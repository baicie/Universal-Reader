use std::{collections::HashMap, path::Path};

use serde::{Deserialize, Serialize};

use crate::{
    library::{
        AnnotationRecord, AnnotationTombstone, Annotations, LibraryDocumentRecord, LibraryError,
        LibraryStore,
    },
    s3, sources,
};

const SNAPSHOT_VERSION: u32 = 1;
const MAX_ANNOTATIONS_PER_DOCUMENT: usize = 100;
const MAX_TOMBSTONES_PER_DOCUMENT: usize = 200;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct MetadataSnapshot {
    #[serde(default = "snapshot_version")]
    pub version: u32,
    #[serde(default)]
    pub documents: Vec<MetadataDocument>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct MetadataDocument {
    pub content_hash: String,
    #[serde(default)]
    pub document_id: String,
    #[serde(default)]
    pub file_name: String,
    #[serde(default)]
    pub progress: f64,
    #[serde(default, alias = "lastOpenedMs")]
    pub last_opened_ms: u64,
    #[serde(default)]
    pub annotations: Vec<AnnotationRecord>,
    #[serde(default)]
    pub deleted_annotations: Vec<AnnotationTombstone>,
}

#[derive(Clone, Debug, Default, Serialize)]
pub struct MetadataSyncResult {
    pub remote_found: bool,
    pub documents: usize,
    pub progress_updated: usize,
    pub annotations_updated: usize,
    pub unmatched_remote: usize,
}

struct PreparedSync {
    snapshot: MetadataSnapshot,
    result: MetadataSyncResult,
}

pub async fn sync_folder(
    store: &LibraryStore,
    path: &Path,
) -> Result<MetadataSyncResult, LibraryError> {
    let remote = sources::read_folder_metadata(path).await?;
    let prepared = synchronize(store, remote).await?;
    let bytes = serde_json::to_vec(&prepared.snapshot).map_err(|_| LibraryError::Io)?;
    sources::write_folder_metadata(path, &bytes).await?;
    Ok(prepared.result)
}

pub async fn sync_webdav(
    store: &LibraryStore,
    sources_config: &sources::SourcesConfig,
    base_url: &str,
    username: &str,
    password: &str,
) -> Result<MetadataSyncResult, LibraryError> {
    let remote =
        sources::read_webdav_metadata(sources_config, base_url, username, password).await?;
    let prepared = synchronize(store, remote).await?;
    let bytes = serde_json::to_vec(&prepared.snapshot).map_err(|_| LibraryError::Io)?;
    sources::write_webdav_metadata(sources_config, base_url, username, password, &bytes).await?;
    Ok(prepared.result)
}

pub async fn sync_s3(
    store: &LibraryStore,
    config: &s3::S3Config,
) -> Result<MetadataSyncResult, LibraryError> {
    let remote = s3::get_file(config, sources::METADATA_SYNC_FILE).await?;
    let prepared = synchronize(store, remote).await?;
    let bytes = serde_json::to_vec(&prepared.snapshot).map_err(|_| LibraryError::Io)?;
    s3::put_file(config, sources::METADATA_SYNC_FILE, &bytes).await?;
    Ok(prepared.result)
}

async fn synchronize(
    store: &LibraryStore,
    remote: Option<Vec<u8>>,
) -> Result<PreparedSync, LibraryError> {
    let local = local_snapshot(store).await?;
    let remote_found = remote.is_some();
    let remote = match remote {
        Some(bytes) => Some(parse_snapshot(&bytes)?),
        None => None,
    };
    let snapshot = merge_snapshots(local, remote.as_ref())?;
    let mut result = apply_snapshot(store, &snapshot).await?;
    result.remote_found = remote_found;
    Ok(PreparedSync { snapshot, result })
}

async fn local_snapshot(store: &LibraryStore) -> Result<MetadataSnapshot, LibraryError> {
    let documents = store.list().await?;
    let mut snapshot = MetadataSnapshot {
        version: SNAPSHOT_VERSION,
        documents: Vec::new(),
    };
    for document in documents {
        if document.content_hash.trim().is_empty() {
            continue;
        }
        let annotations = store.load_annotations(&document.id).await?;
        let deleted_annotations = store.load_annotation_tombstones(&document.id).await?;
        snapshot.documents.push(metadata_document(
            &document,
            annotations,
            deleted_annotations,
        ));
    }
    normalize_snapshot(snapshot)
}

async fn apply_snapshot(
    store: &LibraryStore,
    snapshot: &MetadataSnapshot,
) -> Result<MetadataSyncResult, LibraryError> {
    let documents = store.list().await?;
    let by_hash: HashMap<&str, &LibraryDocumentRecord> = documents
        .iter()
        .filter(|document| !document.content_hash.is_empty())
        .map(|document| (document.content_hash.as_str(), document))
        .collect();
    let mut result = MetadataSyncResult {
        remote_found: false,
        documents: snapshot.documents.len(),
        progress_updated: 0,
        annotations_updated: 0,
        unmatched_remote: 0,
    };
    for entry in &snapshot.documents {
        let Some(document) = by_hash.get(entry.content_hash.as_str()) else {
            result.unmatched_remote += 1;
            continue;
        };
        if document.progress != entry.progress || document.last_opened_ms != entry.last_opened_ms {
            store
                .apply_synced_reading_state(&document.id, entry.progress, entry.last_opened_ms)
                .await?;
            result.progress_updated += 1;
        }
        let current_annotations = store.load_annotations(&document.id).await?;
        let current_tombstones = store.load_annotation_tombstones(&document.id).await?;
        if current_annotations.notes != entry.annotations
            || current_tombstones != entry.deleted_annotations
        {
            store
                .replace_synced_annotations(
                    &document.id,
                    Annotations {
                        notes: entry.annotations.clone(),
                    },
                    entry.deleted_annotations.clone(),
                )
                .await?;
            result.annotations_updated += 1;
        }
    }
    Ok(result)
}

fn metadata_document(
    document: &LibraryDocumentRecord,
    annotations: Annotations,
    deleted_annotations: Vec<AnnotationTombstone>,
) -> MetadataDocument {
    MetadataDocument {
        content_hash: document.content_hash.clone(),
        document_id: document.id.clone(),
        file_name: document.file_name.clone(),
        progress: normalize_progress(document.progress),
        last_opened_ms: document.last_opened_ms,
        annotations: annotations.notes,
        deleted_annotations,
    }
}

fn parse_snapshot(bytes: &[u8]) -> Result<MetadataSnapshot, LibraryError> {
    let snapshot: MetadataSnapshot = serde_json::from_slice(bytes).map_err(|_| LibraryError::Io)?;
    normalize_snapshot(snapshot)
}

fn normalize_snapshot(mut snapshot: MetadataSnapshot) -> Result<MetadataSnapshot, LibraryError> {
    if snapshot.version != SNAPSHOT_VERSION {
        return Err(LibraryError::Io);
    }
    let mut by_hash: HashMap<String, MetadataDocument> = HashMap::new();
    for mut document in snapshot.documents.drain(..) {
        let hash = document.content_hash.trim();
        if !valid_sync_key(hash) {
            if hash.is_empty() {
                continue;
            }
            return Err(LibraryError::Io);
        }
        document.content_hash = hash.to_string();
        document.progress = normalize_progress(document.progress);
        normalize_annotations(&mut document);
        if let Some(existing) = by_hash.remove(&document.content_hash) {
            document = merge_documents(&existing, &document);
        }
        by_hash.insert(document.content_hash.clone(), document);
    }
    snapshot.version = SNAPSHOT_VERSION;
    snapshot.documents = by_hash.into_values().collect();
    snapshot
        .documents
        .sort_by(|left, right| left.content_hash.cmp(&right.content_hash));
    Ok(snapshot)
}

fn merge_snapshots(
    local: MetadataSnapshot,
    remote: Option<&MetadataSnapshot>,
) -> Result<MetadataSnapshot, LibraryError> {
    let local = normalize_snapshot(local)?;
    let Some(remote) = remote else {
        return Ok(local);
    };
    let remote = normalize_snapshot(remote.clone())?;
    let mut merged: HashMap<String, MetadataDocument> = remote
        .documents
        .into_iter()
        .map(|document| (document.content_hash.clone(), document))
        .collect();
    for document in local.documents {
        if let Some(remote_document) = merged.remove(&document.content_hash) {
            merged.insert(
                document.content_hash.clone(),
                merge_documents(&document, &remote_document),
            );
        } else {
            merged.insert(document.content_hash.clone(), document);
        }
    }
    let mut snapshot = MetadataSnapshot {
        version: SNAPSHOT_VERSION,
        documents: merged.into_values().collect(),
    };
    snapshot
        .documents
        .sort_by(|left, right| left.content_hash.cmp(&right.content_hash));
    Ok(snapshot)
}

fn merge_documents(local: &MetadataDocument, remote: &MetadataDocument) -> MetadataDocument {
    let remote_is_newer = remote.last_opened_ms > local.last_opened_ms
        || (remote.last_opened_ms == local.last_opened_ms && remote.progress > local.progress);
    let mut merged = if remote_is_newer {
        remote.clone()
    } else {
        local.clone()
    };
    if merged.document_id.is_empty() {
        merged.document_id = if remote.document_id.is_empty() {
            local.document_id.clone()
        } else {
            remote.document_id.clone()
        };
    }
    if merged.file_name.is_empty() {
        merged.file_name = if remote.file_name.is_empty() {
            local.file_name.clone()
        } else {
            remote.file_name.clone()
        };
    }
    let mut notes: HashMap<String, AnnotationRecord> = HashMap::new();
    for note in local.annotations.iter().chain(remote.annotations.iter()) {
        if !valid_sync_key(&note.id) {
            continue;
        }
        match notes.get(&note.id) {
            Some(existing) if annotation_rank(existing) >= annotation_rank(note) => {}
            _ => {
                notes.insert(note.id.clone(), note.clone());
            }
        }
    }
    let mut tombstones: HashMap<String, AnnotationTombstone> = HashMap::new();
    for tombstone in local
        .deleted_annotations
        .iter()
        .chain(remote.deleted_annotations.iter())
    {
        if !valid_sync_key(&tombstone.id) {
            continue;
        }
        match tombstones.get(&tombstone.id) {
            Some(existing) if existing.deleted_at_ms >= tombstone.deleted_at_ms => {}
            _ => {
                tombstones.insert(tombstone.id.clone(), tombstone.clone());
            }
        }
    }
    for (id, note) in notes.iter() {
        let Some(tombstone) = tombstones.get(id) else {
            continue;
        };
        if note.created_at_ms > tombstone.deleted_at_ms {
            tombstones.remove(id);
        }
    }
    notes.retain(|id, note| {
        tombstones
            .get(id)
            .is_none_or(|tombstone| note.created_at_ms > tombstone.deleted_at_ms)
    });
    merged.annotations = notes.into_values().collect();
    merged.deleted_annotations = tombstones.into_values().collect();
    normalize_annotations(&mut merged);
    merged
}

fn normalize_annotations(document: &mut MetadataDocument) {
    document.annotations.retain(|note| valid_sync_key(&note.id));
    document
        .deleted_annotations
        .retain(|tombstone| valid_sync_key(&tombstone.id));
    document.annotations.sort_by(|left, right| {
        left.created_at_ms
            .cmp(&right.created_at_ms)
            .then_with(|| left.id.cmp(&right.id))
    });
    if document.annotations.len() > MAX_ANNOTATIONS_PER_DOCUMENT {
        let excess = document.annotations.len() - MAX_ANNOTATIONS_PER_DOCUMENT;
        document.annotations.drain(0..excess);
    }
    document.deleted_annotations.sort_by(|left, right| {
        left.deleted_at_ms
            .cmp(&right.deleted_at_ms)
            .then_with(|| left.id.cmp(&right.id))
    });
    if document.deleted_annotations.len() > MAX_TOMBSTONES_PER_DOCUMENT {
        let excess = document.deleted_annotations.len() - MAX_TOMBSTONES_PER_DOCUMENT;
        document.deleted_annotations.drain(0..excess);
    }
}

fn annotation_rank(note: &AnnotationRecord) -> (u64, String) {
    (
        note.created_at_ms,
        serde_json::to_string(note).unwrap_or_default(),
    )
}

fn normalize_progress(progress: f64) -> f64 {
    if progress.is_finite() {
        progress.clamp(0.0, 1.0)
    } else {
        0.0
    }
}

fn valid_sync_key(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 128
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_'))
}

const fn snapshot_version() -> u32 {
    SNAPSHOT_VERSION
}

#[cfg(test)]
mod tests {
    use super::*;

    fn note(id: &str, created_at_ms: u64) -> AnnotationRecord {
        AnnotationRecord {
            id: id.to_string(),
            note: format!("note-{id}"),
            quote: String::new(),
            locator_label: String::new(),
            source: "user".to_string(),
            created_at_ms,
        }
    }

    fn document(hash: &str) -> MetadataDocument {
        MetadataDocument {
            content_hash: hash.to_string(),
            document_id: String::new(),
            file_name: String::new(),
            progress: 0.0,
            last_opened_ms: 0,
            annotations: Vec::new(),
            deleted_annotations: Vec::new(),
        }
    }

    #[test]
    fn newer_reading_state_wins_and_old_notes_merge() {
        let mut local = document("abc123");
        local.progress = 0.2;
        local.last_opened_ms = 10;
        local.annotations.push(note("local", 1));
        let mut remote = document("abc123");
        remote.progress = 0.8;
        remote.last_opened_ms = 20;
        remote.annotations.push(note("remote", 2));

        let merged = merge_snapshots(
            MetadataSnapshot {
                version: SNAPSHOT_VERSION,
                documents: vec![local],
            },
            Some(&MetadataSnapshot {
                version: SNAPSHOT_VERSION,
                documents: vec![remote],
            }),
        )
        .unwrap();

        let entry = &merged.documents[0];
        assert_eq!(entry.progress, 0.8);
        assert_eq!(entry.last_opened_ms, 20);
        assert_eq!(
            entry
                .annotations
                .iter()
                .map(|item| item.id.as_str())
                .collect::<Vec<_>>(),
            vec!["local", "remote"]
        );
    }

    #[test]
    fn tombstone_suppresses_an_older_note() {
        let mut local = document("abc123");
        local.deleted_annotations.push(AnnotationTombstone {
            id: "gone".to_string(),
            deleted_at_ms: 20,
        });
        let mut remote = document("abc123");
        remote.annotations.push(note("gone", 10));

        let merged = merge_snapshots(
            MetadataSnapshot {
                version: SNAPSHOT_VERSION,
                documents: vec![local],
            },
            Some(&MetadataSnapshot {
                version: SNAPSHOT_VERSION,
                documents: vec![remote],
            }),
        )
        .unwrap();

        assert!(merged.documents[0].annotations.is_empty());
        assert_eq!(merged.documents[0].deleted_annotations.len(), 1);
    }

    #[test]
    fn recreated_note_removes_an_older_tombstone() {
        let mut local = document("abc123");
        local.deleted_annotations.push(AnnotationTombstone {
            id: "same".to_string(),
            deleted_at_ms: 10,
        });
        let mut remote = document("abc123");
        remote.annotations.push(note("same", 20));

        let merged = merge_snapshots(
            MetadataSnapshot {
                version: SNAPSHOT_VERSION,
                documents: vec![local],
            },
            Some(&MetadataSnapshot {
                version: SNAPSHOT_VERSION,
                documents: vec![remote],
            }),
        )
        .unwrap();

        assert_eq!(merged.documents[0].annotations.len(), 1);
        assert!(merged.documents[0].deleted_annotations.is_empty());
    }

    #[test]
    fn rejects_unknown_snapshot_versions() {
        let snapshot = MetadataSnapshot {
            version: SNAPSHOT_VERSION + 1,
            documents: Vec::new(),
        };
        let bytes = serde_json::to_vec(&snapshot).unwrap();
        assert!(parse_snapshot(&bytes).is_err());
    }
}
