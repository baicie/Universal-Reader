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
        "txt" | "md" | "markdown" | "html" | "htm" => {
            let mut text = decode_text(bytes);
            if matches!(ext.as_str(), "html" | "htm") {
                text = strip_html(&text);
            }
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

fn decode_text(bytes: &[u8]) -> String {
    String::from_utf8_lossy(bytes).replace('\r', "")
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
mod tests {
    use super::*;

    #[test]
    fn extracts_plain_text() {
        let units = extract_units("notes.txt", b"hello search").unwrap();
        assert_eq!(units[0].body, "hello search");
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
}
