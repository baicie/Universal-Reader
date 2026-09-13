use djvu_rs::{
    DjVuDocument,
    cbz::{CbzOptions, djvu_to_cbz},
};

pub fn convert_to_cbz(bytes: &[u8]) -> Option<Vec<u8>> {
    let document = DjVuDocument::parse(bytes).ok()?;
    djvu_to_cbz(
        &document,
        &CbzOptions {
            dpi: 150,
            ..Default::default()
        },
    )
    .ok()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Cursor, Read};

    #[test]
    fn converts_a_real_djvu_fixture_to_cbz() {
        let bytes = include_bytes!("../../../../test-books/djvu/minimal.djvu");
        let cbz = convert_to_cbz(bytes).expect("convert djvu");
        let mut archive = zip::ZipArchive::new(Cursor::new(cbz)).expect("converted cbz zip");

        assert!(!archive.is_empty());
        let mut page = archive.by_index(0).unwrap();
        assert!(page.name().ends_with(".png"));
        let mut png = Vec::new();
        page.read_to_end(&mut png).unwrap();
        assert!(png.starts_with(b"\x89PNG\r\n\x1A\n"));
    }
}
