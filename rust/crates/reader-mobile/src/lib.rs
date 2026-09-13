use std::{
    mem::ManuallyDrop,
    panic::{AssertUnwindSafe, catch_unwind},
    slice,
};

const MAX_INPUT_BYTES: usize = 64 * 1024 * 1024;

pub const UR_NATIVE_API_VERSION: u32 = 1;
pub const UR_OK: i32 = 0;
pub const UR_INVALID_ARGUMENT: i32 = 1;
pub const UR_CORRUPT: i32 = 2;
pub const UR_INTERNAL: i32 = 3;

#[repr(C)]
#[derive(Debug, Default)]
pub struct UrBytes {
    pub data: *mut u8,
    pub len: usize,
    pub capacity: usize,
}

#[unsafe(no_mangle)]
pub extern "C" fn ur_native_api_version() -> u32 {
    UR_NATIVE_API_VERSION
}

/// Converts a CHM byte buffer to EPUB through the shared native core.
///
/// # Safety
///
/// `file_name_ptr` and `input_ptr` must point to readable buffers of the
/// supplied lengths. `output` must be writable and must not alias either input.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ur_chm_to_epub(
    file_name_ptr: *const u8,
    file_name_len: usize,
    input_ptr: *const u8,
    input_len: usize,
    output: *mut UrBytes,
) -> i32 {
    unsafe {
        convert_with(
            file_name_ptr,
            file_name_len,
            input_ptr,
            input_len,
            output,
            reader_format_native::chm::convert_to_epub,
        )
    }
}

/// Converts a DjVu byte buffer to CBZ through the shared native core.
///
/// # Safety
///
/// `input_ptr` must point to a readable buffer of `input_len` bytes. `output`
/// must be writable and must not alias the input.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ur_djvu_to_cbz(
    input_ptr: *const u8,
    input_len: usize,
    output: *mut UrBytes,
) -> i32 {
    unsafe {
        convert_with(
            b"document.djvu".as_ptr(),
            b"document.djvu".len(),
            input_ptr,
            input_len,
            output,
            |_, input| reader_format_native::djvu::convert_to_cbz(input),
        )
    }
}

/// Releases bytes returned by a successful conversion.
///
/// # Safety
///
/// `bytes` must be the exact value returned by one conversion function and
/// must not be freed more than once.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ur_bytes_free(bytes: UrBytes) {
    if bytes.data.is_null() {
        return;
    }
    if bytes.len > bytes.capacity {
        return;
    }
    unsafe {
        drop(Vec::from_raw_parts(bytes.data, bytes.len, bytes.capacity));
    }
}

unsafe fn convert_with(
    file_name_ptr: *const u8,
    file_name_len: usize,
    input_ptr: *const u8,
    input_len: usize,
    output: *mut UrBytes,
    convert: impl FnOnce(&str, &[u8]) -> Option<Vec<u8>>,
) -> i32 {
    if output.is_null() {
        return UR_INVALID_ARGUMENT;
    }
    unsafe {
        output.write(UrBytes::default());
    }
    if file_name_ptr.is_null()
        || input_ptr.is_null()
        || file_name_len == 0
        || file_name_len > 255
        || input_len == 0
        || input_len > MAX_INPUT_BYTES
    {
        return UR_INVALID_ARGUMENT;
    }
    let file_name = unsafe { slice::from_raw_parts(file_name_ptr, file_name_len) };
    let input = unsafe { slice::from_raw_parts(input_ptr, input_len) };
    let Ok(file_name) = std::str::from_utf8(file_name) else {
        return UR_INVALID_ARGUMENT;
    };
    let bytes = match catch_unwind(AssertUnwindSafe(|| convert(file_name, input))) {
        Ok(Some(bytes)) => bytes,
        Ok(None) => return UR_CORRUPT,
        Err(_) => return UR_INTERNAL,
    };
    let mut bytes = ManuallyDrop::new(bytes);
    unsafe {
        output.write(UrBytes {
            data: bytes.as_mut_ptr(),
            len: bytes.len(),
            capacity: bytes.capacity(),
        });
    }
    UR_OK
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reports_the_public_api_version() {
        assert_eq!(ur_native_api_version(), UR_NATIVE_API_VERSION);
        assert_eq!(UR_NATIVE_API_VERSION, 1);
    }

    #[test]
    fn chm_fixture_converts_through_c_abi() {
        let fixture = include_bytes!("../../../../test-books/chm/minimal.chm");
        let name = b"manual.chm";
        let mut output = UrBytes::default();
        let status = unsafe {
            ur_chm_to_epub(
                name.as_ptr(),
                name.len(),
                fixture.as_ptr(),
                fixture.len(),
                &mut output,
            )
        };
        assert_eq!(status, UR_OK);
        assert!(!output.data.is_null());
        assert!(output.len > 0);
        unsafe { ur_bytes_free(output) };
    }

    #[test]
    fn djvu_fixture_converts_through_c_abi() {
        let fixture = include_bytes!("../../../../test-books/djvu/minimal.djvu");
        let mut output = UrBytes::default();
        let status = unsafe { ur_djvu_to_cbz(fixture.as_ptr(), fixture.len(), &mut output) };
        assert_eq!(status, UR_OK);
        assert!(!output.data.is_null());
        assert!(output.len > 0);
        unsafe { ur_bytes_free(output) };
    }

    #[test]
    fn malformed_input_returns_corrupt_without_allocating() {
        let input = [1u8, 2, 3];
        let mut output = UrBytes::default();
        let status = unsafe { ur_djvu_to_cbz(input.as_ptr(), input.len(), &mut output) };
        assert_eq!(status, UR_CORRUPT);
        assert!(output.data.is_null());
        assert_eq!(output.len, 0);
    }
}
