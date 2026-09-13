use std::{
    collections::HashSet,
    io::{Cursor, Write},
    path::Path,
};

use libchm::{ChmFile, EntrySel};
use tempfile::NamedTempFile;
use zip::{CompressionMethod, ZipWriter, write::SimpleFileOptions};

const MAX_CHM_ENTRIES: usize = 10_000;
const MAX_CHM_FILE_BYTES: usize = 64 * 1024 * 1024;
const MAX_CHM_TOTAL_BYTES: usize = 256 * 1024 * 1024;

pub fn convert_to_epub(file_name: &str, bytes: &[u8]) -> Option<Vec<u8>> {
    let mut temp = NamedTempFile::new().ok()?;
    temp.write_all(bytes).ok()?;
    temp.flush().ok()?;
    let mut chm = ChmFile::open(temp.path()).ok()?;
    let entries = chm.entries(EntrySel::NORMAL | EntrySel::FILES).ok()?;
    if entries.len() > MAX_CHM_ENTRIES {
        return None;
    }

    let mut files = Vec::<(String, Vec<u8>)>::new();
    let mut seen = HashSet::new();
    let mut total = 0usize;
    for entry in entries {
        let Some(path) = normalize_path(&entry.path) else {
            continue;
        };
        if !seen.insert(path.clone()) {
            continue;
        }
        let length = usize::try_from(entry.length).ok()?;
        if length > MAX_CHM_FILE_BYTES {
            continue;
        }
        let Ok(content) = chm.read(&entry) else {
            continue;
        };
        total = total.checked_add(content.len())?;
        if total > MAX_CHM_TOTAL_BYTES {
            return None;
        }
        files.push((path, content));
    }

    let mut pages = files
        .iter()
        .filter(|(path, _)| is_html(path))
        .map(|(path, _)| path.clone())
        .collect::<Vec<_>>();
    pages.sort_by_key(|path| (page_rank(path), path.to_ascii_lowercase()));
    if pages.is_empty() {
        return None;
    }

    let fallback_title = title_from_file_name(file_name);
    let title = pages
        .first()
        .and_then(|path| files.iter().find(|(candidate, _)| candidate == path))
        .and_then(|(_, content)| html_title(content))
        .unwrap_or(fallback_title);

    let mut cursor = Cursor::new(Vec::new());
    {
        let mut zip = ZipWriter::new(&mut cursor);
        let stored = SimpleFileOptions::default().compression_method(CompressionMethod::Stored);
        let deflated = SimpleFileOptions::default();
        zip.start_file("mimetype", stored).ok()?;
        zip.write_all(b"application/epub+zip").ok()?;
        zip.start_file("META-INF/container.xml", deflated).ok()?;
        zip.write_all(container_xml().as_bytes()).ok()?;
        zip.start_file("OEBPS/content.opf", deflated).ok()?;
        zip.write_all(opf_xml(&title, &pages, &files).as_bytes())
            .ok()?;
        zip.start_file("OEBPS/nav.xhtml", deflated).ok()?;
        zip.write_all(nav_xhtml(&pages, &files).as_bytes()).ok()?;
        for (path, content) in &files {
            zip.start_file(format!("OEBPS/{path}"), deflated).ok()?;
            zip.write_all(content).ok()?;
        }
        zip.finish().ok()?;
    }
    Some(cursor.into_inner())
}

fn container_xml() -> String {
    r#"<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>"#
        .to_string()
}

fn opf_xml(title: &str, pages: &[String], files: &[(String, Vec<u8>)]) -> String {
    let mut manifest = String::new();
    let mut spine = String::new();
    for (index, (path, _)) in files.iter().enumerate() {
        manifest.push_str(&format!(
            r#"<item id="item-{index}" href="{}" media-type="{}"/>"#,
            escape_xml(path),
            media_type(path)
        ));
    }
    for path in pages {
        let Some((file_index, _)) = files.iter().enumerate().find(|(_, (item, _))| item == path)
        else {
            continue;
        };
        spine.push_str(&format!(r#"<itemref idref="item-{file_index}"/>"#));
    }
    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>{}</dc:title>
    <dc:language>en</dc:language>
    <dc:identifier id="bookid">urn:uuid:chm-{}</dc:identifier>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    {manifest}
  </manifest>
  <spine>{spine}</spine>
</package>"#,
        escape_xml(title),
        stable_hash(title)
    )
}

fn nav_xhtml(pages: &[String], files: &[(String, Vec<u8>)]) -> String {
    let mut items = String::new();
    for path in pages {
        let title = files
            .iter()
            .find(|(candidate, _)| candidate == path)
            .and_then(|(_, content)| html_title(content))
            .unwrap_or_else(|| path.clone());
        items.push_str(&format!(
            r#"<li><a href="{}">{}</a></li>"#,
            escape_xml(path),
            escape_xml(&title)
        ));
    }
    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <head><title>Contents</title></head>
  <body><nav epub:type="toc"><ol>{items}</ol></nav></body>
</html>"#
    )
}

fn normalize_path(path: &str) -> Option<String> {
    let mut parts = Vec::new();
    let normalized = path.replace('\\', "/");
    for part in normalized.split('/') {
        if part.is_empty() || part == "." {
            continue;
        }
        if part == ".." {
            return None;
        }
        parts.push(part);
    }
    (!parts.is_empty()).then(|| parts.join("/"))
}

fn is_html(path: &str) -> bool {
    let lower = path.to_ascii_lowercase();
    lower.ends_with(".htm") || lower.ends_with(".html") || lower.ends_with(".xhtml")
}

fn page_rank(path: &str) -> (u8, String) {
    let lower = path.to_ascii_lowercase();
    let name = lower.rsplit('/').next().unwrap_or(&lower);
    let rank = if name.starts_with("index.") {
        0
    } else if name.starts_with("default.") {
        1
    } else {
        2
    };
    (rank, lower)
}

fn html_title(bytes: &[u8]) -> Option<String> {
    let text = String::from_utf8_lossy(bytes);
    let lower = text.to_ascii_lowercase();
    let start = lower.find("<title")?;
    let open_end = lower[start..].find('>')? + start + 1;
    let end = lower[open_end..].find("</title>")? + open_end;
    let title = text[open_end..end]
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .trim()
        .to_string();
    (!title.is_empty()).then_some(title)
}

fn title_from_file_name(file_name: &str) -> String {
    Path::new(file_name)
        .file_stem()
        .and_then(|value| value.to_str())
        .unwrap_or("CHM document")
        .to_string()
}

fn media_type(path: &str) -> &'static str {
    let lower = path.to_ascii_lowercase();
    if is_html(&lower) {
        "application/xhtml+xml"
    } else if lower.ends_with(".css") {
        "text/css"
    } else if lower.ends_with(".png") {
        "image/png"
    } else if lower.ends_with(".jpg") || lower.ends_with(".jpeg") {
        "image/jpeg"
    } else if lower.ends_with(".gif") {
        "image/gif"
    } else if lower.ends_with(".webp") {
        "image/webp"
    } else if lower.ends_with(".svg") {
        "image/svg+xml"
    } else if lower.ends_with(".js") {
        "text/javascript"
    } else {
        "application/octet-stream"
    }
}

fn escape_xml(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

fn stable_hash(value: &str) -> u64 {
    let mut hash = 1469598103934665603u64;
    for byte in value.as_bytes() {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(1099511628211);
    }
    hash
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn converts_a_real_chm_fixture_to_epub() {
        let bytes = include_bytes!("../../../../test-books/chm/minimal.chm");
        let epub = convert_to_epub("manual.chm", bytes).expect("convert chm");
        let mut archive = zip::ZipArchive::new(Cursor::new(epub)).expect("converted epub zip");

        let mut names = Vec::new();
        for index in 0..archive.len() {
            names.push(archive.by_index(index).unwrap().name().to_string());
        }
        assert!(names.contains(&"mimetype".to_string()));
        assert!(names.contains(&"META-INF/container.xml".to_string()));
        assert!(names.contains(&"OEBPS/content.opf".to_string()));
        assert!(names.contains(&"OEBPS/nav.xhtml".to_string()));
        assert!(names.iter().any(|name| name.ends_with(".htm")));
    }
}
