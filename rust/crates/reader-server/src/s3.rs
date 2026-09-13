use hmac::{Hmac, Mac};
use reqwest::{Method, Url};
use sha2::{Digest, Sha256};
use time::OffsetDateTime;

use crate::library::LibraryError;
use crate::sources::METADATA_SYNC_FILE;

const MAX_OBJECT_BYTES: usize = 64 * 1024 * 1024;
const MAX_LIST_PAGES: usize = 10_000;

#[derive(Clone)]
pub struct S3Config {
    endpoint: Url,
    region: String,
    bucket: String,
    prefix: String,
    access_key: String,
    secret_key: String,
    client: reqwest::Client,
}

impl S3Config {
    pub fn new(
        endpoint: &str,
        region: &str,
        bucket: &str,
        prefix: &str,
        access_key: &str,
        secret_key: &str,
    ) -> Option<Self> {
        let endpoint = Url::parse(endpoint.trim()).ok()?;
        if !matches!(endpoint.scheme(), "http" | "https") || endpoint.host_str().is_none() {
            return None;
        }
        let bucket = bucket.trim();
        if bucket.is_empty() || bucket.contains('/') {
            return None;
        }
        let region = region.trim();
        let access_key = access_key.trim();
        let secret_key = secret_key.trim();
        if region.is_empty() || access_key.is_empty() || secret_key.is_empty() {
            return None;
        }
        let mut prefix = prefix.trim().replace('\\', "/");
        while prefix.starts_with('/') {
            prefix.remove(0);
        }
        if !prefix.is_empty() && !prefix.ends_with('/') {
            prefix.push('/');
        }
        Some(Self {
            endpoint,
            region: region.to_string(),
            bucket: bucket.to_string(),
            prefix,
            access_key: access_key.to_string(),
            secret_key: secret_key.to_string(),
            client: reqwest::Client::new(),
        })
    }
}

pub async fn list_files(config: &S3Config) -> Result<Vec<(String, Vec<u8>)>, LibraryError> {
    let keys = list_keys(config).await?;
    let mut files = Vec::new();
    for key in keys {
        let Some(name) = key.rsplit('/').next().filter(|name| !name.is_empty()) else {
            continue;
        };
        if name == METADATA_SYNC_FILE {
            continue;
        }
        if let Ok(bytes) = get_object(config, &key).await {
            files.push((name.to_string(), bytes));
        }
    }
    Ok(files)
}

pub async fn list_names(config: &S3Config) -> Result<Vec<String>, LibraryError> {
    Ok(list_keys(config)
        .await?
        .into_iter()
        .filter_map(|key| key.rsplit('/').next().map(str::to_string))
        .filter(|name| !name.is_empty() && name != METADATA_SYNC_FILE)
        .collect())
}

pub async fn put_file(
    config: &S3Config,
    file_name: &str,
    bytes: &[u8],
) -> Result<(), LibraryError> {
    let key = format!("{}{}", config.prefix, file_name);
    put_object(config, &key, bytes).await
}

pub async fn get_file(config: &S3Config, file_name: &str) -> Result<Option<Vec<u8>>, LibraryError> {
    if file_name.is_empty()
        || file_name.contains(['/', '\\'])
        || file_name == "."
        || file_name == ".."
    {
        return Err(LibraryError::InvalidName);
    }
    let key = format!("{}{}", config.prefix, file_name);
    let response = signed_request(config, Method::GET, Some(&key), &[], &[])?
        .send()
        .await
        .map_err(|_| LibraryError::Io)?;
    if response.status() == reqwest::StatusCode::NOT_FOUND {
        return Ok(None);
    }
    if !response.status().is_success()
        || response
            .content_length()
            .is_some_and(|length| length > MAX_OBJECT_BYTES as u64)
    {
        return Err(LibraryError::Io);
    }
    let bytes = response.bytes().await.map_err(|_| LibraryError::Io)?;
    if bytes.len() > MAX_OBJECT_BYTES {
        return Err(LibraryError::Io);
    }
    Ok(Some(bytes.to_vec()))
}

async fn list_keys(config: &S3Config) -> Result<Vec<String>, LibraryError> {
    let mut keys = Vec::new();
    let mut continuation: Option<String> = None;
    for _ in 0..MAX_LIST_PAGES {
        let mut query = vec![
            ("list-type".to_string(), "2".to_string()),
            ("prefix".to_string(), config.prefix.clone()),
        ];
        if let Some(token) = &continuation {
            query.push(("continuation-token".to_string(), token.clone()));
        }
        let response = signed_request(config, Method::GET, None, &query, &[])?
            .send()
            .await
            .map_err(|_| LibraryError::Io)?;
        if !response.status().is_success() {
            return Err(LibraryError::Io);
        }
        let xml = response.text().await.map_err(|_| LibraryError::Io)?;
        keys.extend(xml_values(&xml, "Key"));
        if !xml_bool(&xml, "IsTruncated") {
            return Ok(keys);
        }
        continuation = xml_values(&xml, "NextContinuationToken").into_iter().next();
        if continuation.is_none() {
            return Err(LibraryError::Io);
        }
    }
    Err(LibraryError::Io)
}

async fn get_object(config: &S3Config, key: &str) -> Result<Vec<u8>, LibraryError> {
    let response = signed_request(config, Method::GET, Some(key), &[], &[])?
        .send()
        .await
        .map_err(|_| LibraryError::Io)?;
    if !response.status().is_success() {
        return Err(LibraryError::Io);
    }
    if response
        .content_length()
        .is_some_and(|length| length > MAX_OBJECT_BYTES as u64)
    {
        return Err(LibraryError::Io);
    }
    let bytes = response.bytes().await.map_err(|_| LibraryError::Io)?;
    if bytes.len() > MAX_OBJECT_BYTES {
        return Err(LibraryError::Io);
    }
    Ok(bytes.to_vec())
}

async fn put_object(config: &S3Config, key: &str, bytes: &[u8]) -> Result<(), LibraryError> {
    let response = signed_request(config, Method::PUT, Some(key), &[], bytes)?
        .send()
        .await
        .map_err(|_| LibraryError::Io)?;
    response
        .status()
        .is_success()
        .then_some(())
        .ok_or(LibraryError::Io)
}

fn signed_request(
    config: &S3Config,
    method: Method,
    key: Option<&str>,
    query: &[(String, String)],
    payload: &[u8],
) -> Result<reqwest::RequestBuilder, LibraryError> {
    let mut url = config.endpoint.clone();
    {
        let mut segments = url.path_segments_mut().map_err(|_| LibraryError::Io)?;
        segments.push(&config.bucket);
        if let Some(key) = key {
            for segment in key.split('/') {
                segments.push(segment);
            }
        }
    }
    let mut query = query.to_vec();
    query.sort();
    if !query.is_empty() {
        url.query_pairs_mut().extend_pairs(query.iter());
    }

    let now = OffsetDateTime::now_utc();
    let date = format!(
        "{:04}{:02}{:02}",
        now.year(),
        u8::from(now.month()),
        now.day()
    );
    let amz_date = format!(
        "{date}T{:02}{:02}{:02}Z",
        now.hour(),
        now.minute(),
        now.second()
    );
    let payload_hash = hex_digest(payload);
    let host = url.host_str().ok_or(LibraryError::Io)?.to_string()
        + &url
            .port()
            .map(|port| format!(":{port}"))
            .unwrap_or_default();
    let canonical_uri = url.path();
    let canonical_query = query
        .iter()
        .map(|(key, value)| format!("{}={}", aws_encode(key, true), aws_encode(value, true)))
        .collect::<Vec<_>>()
        .join("&");
    let canonical_headers =
        format!("host:{host}\nx-amz-content-sha256:{payload_hash}\nx-amz-date:{amz_date}\n");
    let signed_headers = "host;x-amz-content-sha256;x-amz-date";
    let canonical_request = format!(
        "{}\n{canonical_uri}\n{canonical_query}\n{canonical_headers}\n{signed_headers}\n{payload_hash}",
        method.as_str()
    );
    let scope = format!("{date}/{}/s3/aws4_request", config.region);
    let string_to_sign = format!(
        "AWS4-HMAC-SHA256\n{amz_date}\n{scope}\n{}",
        hex_digest(canonical_request.as_bytes())
    );
    let date_key = hmac(
        format!("AWS4{}", config.secret_key).as_bytes(),
        date.as_bytes(),
    );
    let region_key = hmac(&date_key, config.region.as_bytes());
    let service_key = hmac(&region_key, b"s3");
    let signing_key = hmac(&service_key, b"aws4_request");
    let signature = hex_bytes(&hmac(&signing_key, string_to_sign.as_bytes()));
    let authorization = format!(
        "AWS4-HMAC-SHA256 Credential={}/{scope}, SignedHeaders={signed_headers}, Signature={signature}",
        config.access_key
    );

    let mut request = config
        .client
        .request(method, url)
        .header("x-amz-content-sha256", payload_hash)
        .header("x-amz-date", amz_date)
        .header("authorization", authorization);
    if !payload.is_empty() {
        request = request.body(payload.to_vec());
    }
    Ok(request)
}

fn hmac(key: &[u8], value: &[u8]) -> Vec<u8> {
    let mut mac = Hmac::<Sha256>::new_from_slice(key).expect("HMAC accepts arbitrary key sizes");
    mac.update(value);
    mac.finalize().into_bytes().to_vec()
}

fn hex_digest(value: &[u8]) -> String {
    hex_bytes(&Sha256::digest(value))
}

fn hex_bytes(bytes: &[u8]) -> String {
    let mut output = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        output.push_str(&format!("{byte:02x}"));
    }
    output
}

fn aws_encode(value: &str, encode_slash: bool) -> String {
    let mut output = String::new();
    for byte in value.as_bytes() {
        let allowed = byte.is_ascii_alphanumeric()
            || matches!(*byte, b'-' | b'_' | b'.' | b'~')
            || (!encode_slash && *byte == b'/');
        if allowed {
            output.push(char::from(*byte));
        } else {
            output.push_str(&format!("%{byte:02X}"));
        }
    }
    output
}

fn xml_values(xml: &str, tag: &str) -> Vec<String> {
    let open = format!("<{tag}>");
    let close = format!("</{tag}>");
    let mut values = Vec::new();
    let mut rest = xml;
    while let Some(start) = rest.find(&open) {
        let value_start = start + open.len();
        let Some(end) = rest[value_start..].find(&close) else {
            break;
        };
        values.push(xml_unescape(&rest[value_start..value_start + end]));
        rest = &rest[value_start + end + close.len()..];
    }
    values
}

fn xml_bool(xml: &str, tag: &str) -> bool {
    xml_values(xml, tag)
        .into_iter()
        .next()
        .is_some_and(|value| value.eq_ignore_ascii_case("true"))
}

fn xml_unescape(value: &str) -> String {
    value
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
        .replace("&amp;", "&")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn signs_requests_without_exposing_the_secret() {
        let config = S3Config::new(
            "https://s3.example.test",
            "us-east-1",
            "books",
            "library/",
            "access",
            "secret",
        )
        .unwrap();
        let request = signed_request(&config, Method::GET, None, &[], &[]).unwrap();
        let request = request.build().unwrap();
        let authorization = request.headers()["authorization"].to_str().unwrap();
        assert!(authorization.starts_with("AWS4-HMAC-SHA256 Credential=access/"));
        assert!(authorization.contains("SignedHeaders=host;x-amz-content-sha256;x-amz-date"));
        assert!(!authorization.contains("secret"));
    }

    #[test]
    fn parses_list_object_keys() {
        let xml = "<ListBucketResult><Contents><Key>library/a.epub</Key></Contents><Contents><Key>library/b&amp;c.txt</Key></Contents></ListBucketResult>";
        assert_eq!(
            xml_values(xml, "Key"),
            vec!["library/a.epub", "library/b&c.txt"]
        );
    }

    #[test]
    fn rejects_invalid_endpoint_configuration() {
        assert!(S3Config::new("file:///tmp", "us", "bucket", "", "key", "secret").is_none());
        assert!(S3Config::new("https://s3.test", "", "bucket", "", "key", "secret").is_none());
    }
}
