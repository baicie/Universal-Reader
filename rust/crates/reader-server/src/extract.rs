use std::io::{Cursor, Read};

use zip::ZipArchive;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TextUnit {
    pub locator: String,
    pub title: String,
    pub body: String,
}

pub fn extract_units(file_name: &str, bytes: &[u8]) -> Option<Vec<TextUnit>> {
    let ext = file_name.rsplit_once('.')?.1.to_ascii_lowercase();
    match ext.as_str() {
        "txt" | "md" | "markdown" => {
            let text = decode_plain_text(bytes)?.trim().to_string();
            if text.is_empty() {
                return None;
            }
            Some(vec![TextUnit {
                locator: "offset 0".into(),
                title: title_from_name(file_name),
                body: text,
            }])
        }
        "html" | "htm" => {
            let text = strip_html(&decode_text(bytes)).trim().to_string();
            if text.is_empty() {
                return None;
            }
            Some(vec![TextUnit {
                locator: "offset 0".into(),
                title: title_from_name(file_name),
                body: text,
            }])
        }
        "epub" => extract_epub(bytes),
        "pdf" => extract_pdf(bytes),
        "fb2" => extract_plain_xml(bytes, file_name),
        "mobi" | "azw3" => extract_epub(bytes).or_else(|| extract_plain_xml(bytes, file_name)),
        _ => None,
    }
}

pub fn extract_cover(file_name: &str, bytes: &[u8]) -> Option<Vec<u8>> {
    let ext = file_name.rsplit_once('.')?.1.to_ascii_lowercase();
    match ext.as_str() {
        "epub" | "cbz" | "cbr" => zip_cover(bytes, ext == "epub"),
        _ => None,
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DocumentIdentity {
    pub title: String,
    pub author: String,
}

pub fn document_identity(file_name: &str, bytes: &[u8]) -> DocumentIdentity {
    let fallback = title_from_name(file_name);
    let ext = file_name
        .rsplit_once('.')
        .map(|(_, value)| value.to_ascii_lowercase())
        .unwrap_or_default();
    match ext.as_str() {
        "epub" | "azw3" | "mobi" => identity_from_epub(bytes).unwrap_or(DocumentIdentity {
            title: fallback,
            author: String::new(),
        }),
        "fb2" => identity_from_fb2(bytes).unwrap_or(DocumentIdentity {
            title: fallback,
            author: String::new(),
        }),
        _ => DocumentIdentity {
            title: fallback,
            author: String::new(),
        },
    }
}

fn extract_plain_xml(bytes: &[u8], file_name: &str) -> Option<Vec<TextUnit>> {
    let text = strip_html(&decode_text(bytes));
    let text = text.trim().to_string();
    if text.is_empty() {
        return None;
    }
    Some(vec![TextUnit {
        locator: "offset 0".into(),
        title: title_from_name(file_name),
        body: text,
    }])
}

fn zip_cover(bytes: &[u8], prefer_named_cover: bool) -> Option<Vec<u8>> {
    let mut archive = ZipArchive::new(Cursor::new(bytes)).ok()?;
    let mut first = None;
    for i in 0..archive.len() {
        let mut file = archive.by_index(i).ok()?;
        if !file.is_file() {
            continue;
        }
        let name = file.name().replace('\\', "/").to_ascii_lowercase();
        if !name.ends_with(".png")
            && !name.ends_with(".jpg")
            && !name.ends_with(".jpeg")
            && !name.ends_with(".webp")
        {
            continue;
        }
        let mut buf = Vec::new();
        file.read_to_end(&mut buf).ok()?;
        if prefer_named_cover && name.contains("cover") {
            return Some(buf);
        }
        if first.is_none() {
            first = Some(buf);
        }
    }
    first
}

fn title_from_name(file_name: &str) -> String {
    file_name
        .rsplit_once('.')
        .map(|(stem, _)| stem)
        .unwrap_or(file_name)
        .to_string()
}

fn identity_from_epub(bytes: &[u8]) -> Option<DocumentIdentity> {
    let mut archive = ZipArchive::new(Cursor::new(bytes)).ok()?;
    let container = read_zip(&mut archive, "meta-inf/container.xml")?;
    let root = attr_value(&container, "full-path")?;
    let opf = read_zip(&mut archive, &root)?;
    let title = xml_local_text(&opf, "title")?;
    let author = xml_local_text(&opf, "creator").unwrap_or_default();
    Some(DocumentIdentity { title, author })
}

fn identity_from_fb2(bytes: &[u8]) -> Option<DocumentIdentity> {
    let xml = decode_text(bytes);
    let title = xml_local_text(&xml, "book-title")?;
    let first = xml_local_text(&xml, "first-name").unwrap_or_default();
    let last = xml_local_text(&xml, "last-name").unwrap_or_default();
    let author = [first.as_str(), last.as_str()]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join(" ");
    Some(DocumentIdentity { title, author })
}

fn xml_local_text(xml: &str, local: &str) -> Option<String> {
    let needle = format!("{local}>");
    let mut from = 0;
    while let Some(at) = xml[from..].find(&needle) {
        let start = from + at;
        let tag_open = xml[..start].rfind('<')?;
        let tag = &xml[tag_open..start];
        from = start + needle.len();
        if tag.contains('/') {
            continue;
        }
        let rest = &xml[from..];
        let end = rest.find('<')?;
        let text = unescape_xml(rest[..end].trim());
        if !text.is_empty() {
            return Some(text);
        }
    }
    None
}

fn unescape_xml(value: &str) -> String {
    value
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
}

fn decode_text(bytes: &[u8]) -> String {
    String::from_utf8_lossy(bytes).replace('\r', "")
}

fn decode_plain_text(bytes: &[u8]) -> Option<String> {
    if let Some(text) = decode_utf16_bom(bytes) {
        return Some(text);
    }
    let slice = if bytes.len() >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF {
        &bytes[3..]
    } else {
        bytes
    };
    if std::str::from_utf8(slice).is_ok() || slice.len() != bytes.len() {
        return std::str::from_utf8(slice)
            .ok()
            .map(|text| text.replace('\r', ""));
    }
    let (cow, _, had_errors) = encoding_rs::GB18030.decode(bytes);
    if had_errors {
        return None;
    }
    Some(cow.into_owned().replace('\r', ""))
}

fn decode_utf16_bom(bytes: &[u8]) -> Option<String> {
    let (offset, big_endian) = if bytes.len() >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE {
        (2usize, false)
    } else if bytes.len() >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF {
        (2, true)
    } else {
        return None;
    };
    let mut units = Vec::new();
    let mut index = offset;
    while index + 1 < bytes.len() {
        let unit = if big_endian {
            u16::from_be_bytes([bytes[index], bytes[index + 1]])
        } else {
            u16::from_le_bytes([bytes[index], bytes[index + 1]])
        };
        units.push(unit);
        index += 2;
    }
    String::from_utf16(&units)
        .ok()
        .map(|text| text.replace('\r', ""))
}

fn strip_html(source: &str) -> String {
    let mut out = String::with_capacity(source.len());
    let mut chars = source.chars().peekable();
    while let Some(ch) = chars.next() {
        if ch == '<' {
            let mut tag = String::new();
            for next in chars.by_ref() {
                if next == '>' {
                    break;
                }
                tag.push(next);
            }
            let name = tag
                .trim()
                .trim_start_matches('/')
                .split_whitespace()
                .next()
                .unwrap_or("")
                .to_ascii_lowercase();
            if matches!(
                name.as_str(),
                "br" | "p" | "div" | "h1" | "h2" | "h3" | "h4"
            ) {
                out.push('\n');
            }
            continue;
        }
        out.push(ch);
    }
    out.replace("&nbsp;", " ")
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
}

fn extract_epub(bytes: &[u8]) -> Option<Vec<TextUnit>> {
    let mut archive = ZipArchive::new(Cursor::new(bytes)).ok()?;
    let container = read_zip(&mut archive, "meta-inf/container.xml")?;
    let root = attr_value(&container, "full-path")?;
    let opf = read_zip(&mut archive, &root)?;
    let opf_dir = root.rsplit_once('/').map(|(dir, _)| dir.to_string());
    let manifest = collect_attrs(&opf, "item", "id", "href");
    let spine: Vec<String> = collect_attr_list(&opf, "itemref", "idref")
        .into_iter()
        .filter_map(|id| manifest.get(&id).cloned())
        .collect();
    if spine.is_empty() {
        return None;
    }
    let mut units = Vec::new();
    for href in spine {
        let path = join_href(opf_dir.as_deref(), &href);
        let Some(html) = read_zip(&mut archive, &path) else {
            continue;
        };
        let body = strip_html(&html);
        let body = body.trim().to_string();
        if body.is_empty() {
            continue;
        }
        units.push(TextUnit {
            locator: path.clone(),
            title: first_line(&body),
            body,
        });
    }
    if units.is_empty() { None } else { Some(units) }
}

fn extract_pdf(bytes: &[u8]) -> Option<Vec<TextUnit>> {
    let source = String::from_utf8_lossy(bytes);
    if !source.contains("%PDF-") {
        return None;
    }
    let mut strings = Vec::new();
    let mut rest = source.as_ref();
    while let Some(start) = rest.find('(') {
        rest = &rest[start + 1..];
        let mut out = String::new();
        let mut chars = rest.chars();
        while let Some(ch) = chars.next() {
            if ch == '\\' {
                if let Some(next) = chars.next() {
                    out.push(next);
                }
                continue;
            }
            if ch == ')' {
                rest = chars.as_str();
                if rest.trim_start().starts_with("Tj") && !out.trim().is_empty() {
                    strings.push(out);
                }
                break;
            }
            out.push(ch);
        }
    }
    if strings.is_empty() {
        return None;
    }
    Some(
        strings
            .into_iter()
            .enumerate()
            .map(|(index, body)| TextUnit {
                locator: format!("page {}", index + 1),
                title: format!("{}", index + 1),
                body,
            })
            .collect(),
    )
}

fn read_zip(archive: &mut ZipArchive<Cursor<&[u8]>>, path: &str) -> Option<String> {
    let needle = path.replace('\\', "/").to_ascii_lowercase();
    for i in 0..archive.len() {
        let mut file = archive.by_index(i).ok()?;
        let name = file.name().replace('\\', "/").to_ascii_lowercase();
        if name == needle || name.ends_with(&needle) {
            let mut buf = String::new();
            file.read_to_string(&mut buf).ok()?;
            return Some(buf);
        }
    }
    None
}

fn attr_value(xml: &str, attr: &str) -> Option<String> {
    let key = format!("{attr}=\"");
    let start = xml.find(&key)? + key.len();
    let end = xml[start..].find('"')? + start;
    Some(xml[start..end].to_string())
}

fn collect_attrs(
    xml: &str,
    tag: &str,
    key_attr: &str,
    value_attr: &str,
) -> std::collections::HashMap<String, String> {
    let mut map = std::collections::HashMap::new();
    let mut rest = xml;
    let open = format!("<{tag}");
    while let Some(at) = rest.find(&open) {
        let slice = &rest[at..];
        let end = slice.find('>').unwrap_or(slice.len());
        let tag_src = &slice[..end];
        if let (Some(key), Some(value)) = (attr_in(tag_src, key_attr), attr_in(tag_src, value_attr))
        {
            map.insert(key, value);
        }
        rest = &slice[end.min(slice.len())..];
        if rest.is_empty() {
            break;
        }
        rest = &rest[1.min(rest.len())..];
    }
    map
}

fn collect_attr_list(xml: &str, tag: &str, attr: &str) -> Vec<String> {
    let mut values = Vec::new();
    let mut rest = xml;
    let open = format!("<{tag}");
    while let Some(at) = rest.find(&open) {
        let slice = &rest[at..];
        let end = slice.find('>').unwrap_or(slice.len());
        if let Some(value) = attr_in(&slice[..end], attr) {
            values.push(value);
        }
        rest = &slice[end.min(slice.len())..];
        if rest.is_empty() {
            break;
        }
        rest = &rest[1.min(rest.len())..];
    }
    values
}

fn attr_in(tag: &str, name: &str) -> Option<String> {
    let key = format!("{name}=\"");
    let start = tag.find(&key)? + key.len();
    let end = tag[start..].find('"')? + start;
    Some(tag[start..end].to_string())
}

fn join_href(dir: Option<&str>, href: &str) -> String {
    let href = href.split('#').next().unwrap_or(href).replace('\\', "/");
    match dir {
        Some(dir) if !href.contains('/') => format!("{dir}/{href}"),
        _ => href,
    }
}

fn first_line(body: &str) -> String {
    body.lines().next().unwrap_or("").chars().take(40).collect()
}

#[cfg(test)]
pub(crate) fn test_minimal_epub(title: &str, author: &str) -> Vec<u8> {
    use std::io::{Cursor, Write};

    use zip::write::SimpleFileOptions;
    use zip::{CompressionMethod, ZipWriter};

    let mut cursor = Cursor::new(Vec::new());
    {
        let mut zip = ZipWriter::new(&mut cursor);
        let stored = SimpleFileOptions::default().compression_method(CompressionMethod::Stored);
        zip.start_file("mimetype", stored).unwrap();
        zip.write_all(b"application/epub+zip").unwrap();
        let deflated = SimpleFileOptions::default();
        zip.start_file("META-INF/container.xml", deflated).unwrap();
        zip.write_all(
            br#"<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>"#,
        )
        .unwrap();
        zip.start_file("OEBPS/content.opf", deflated).unwrap();
        zip.write_all(
            format!(
                r#"<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>{title}</dc:title>
    <dc:creator>{author}</dc:creator>
  </metadata>
  <manifest>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
  </spine>
</package>"#
            )
            .as_bytes(),
        )
        .unwrap();
        zip.start_file("OEBPS/ch1.xhtml", deflated).unwrap();
        zip.write_all(
            br#"<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><body><p>hi</p></body></html>"#,
        )
        .unwrap();
        zip.finish().unwrap();
    }
    cursor.into_inner()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_plain_text() {
        let units = extract_units("notes.txt", b"hello search").unwrap();
        assert_eq!(units[0].body, "hello search");
    }

    #[test]
    fn extracts_gb18030_text_as_chinese() {
        let bytes: &[u8] = &[181, 218, 210, 187, 213, 194];
        let units = extract_units("notes.txt", bytes).unwrap();
        assert!(units[0].body.contains("第一章"));
    }

    #[test]
    fn undecodable_txt_is_not_indexed_as_replacement_text() {
        assert!(extract_units("notes.txt", &[0xFF]).is_none());
    }

    #[test]
    fn extracts_pdf_strings() {
        let pdf = b"%PDF-1.1\nBT (hello from pdf) Tj ET";
        let units = extract_units("scan.pdf", pdf).unwrap();
        assert!(units[0].body.contains("hello from pdf"));
    }

    #[test]
    fn extracts_a_named_epub_cover() {
        assert!(extract_cover("notes.txt", b"hi").is_none());
    }

    #[test]
    fn epub_identity_uses_opf_title_not_the_file_name() {
        let bytes = test_minimal_epub("设计中的设计", "原研哉");
        let identity = document_identity("story.epub", &bytes);
        assert_eq!(identity.title, "设计中的设计");
        assert_eq!(identity.author, "原研哉");
        let plain = document_identity("notes.txt", b"hello");
        assert_eq!(plain.title, "notes");
        assert!(plain.author.is_empty());
    }

    #[test]
    fn fb2_identity_uses_book_title() {
        let xml = br#"<?xml version="1.0"?><FictionBook><description><title-info>
            <book-title>FB2 Book</book-title>
            <author><first-name>Ann</first-name><last-name>Author</last-name></author>
        </title-info></description></FictionBook>"#;
        let identity = document_identity("book.fb2", xml);
        assert_eq!(identity.title, "FB2 Book");
        assert_eq!(identity.author, "Ann Author");
    }
}
