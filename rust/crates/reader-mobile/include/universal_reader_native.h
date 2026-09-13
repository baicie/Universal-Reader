#ifndef UNIVERSAL_READER_NATIVE_H
#define UNIVERSAL_READER_NATIVE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum {
  UR_OK = 0,
  UR_INVALID_ARGUMENT = 1,
  UR_CORRUPT = 2,
  UR_INTERNAL = 3
};

typedef struct {
  uint8_t* data;
  size_t len;
  size_t capacity;
} UrBytes;

uint32_t ur_native_api_version(void);

int32_t ur_chm_to_epub(
    const uint8_t* file_name_ptr,
    size_t file_name_len,
    const uint8_t* input_ptr,
    size_t input_len,
    UrBytes* output);

int32_t ur_djvu_to_cbz(
    const uint8_t* input_ptr,
    size_t input_len,
    UrBytes* output);

void ur_bytes_free(UrBytes bytes);

#ifdef __cplusplus
}
#endif

#endif
