#ifndef LOVE_THORVG_H
#define LOVE_THORVG_H

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#  if defined(LOVE_THORVG_BUILD)
#    define LOVE_THORVG_API __declspec(dllexport)
#  else
#    define LOVE_THORVG_API __declspec(dllimport)
#  endif
#else
#  define LOVE_THORVG_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct love_thorvg_document love_thorvg_document;

enum love_thorvg_result {
    LOVE_THORVG_OK = 0,
    LOVE_THORVG_INVALID_ARGUMENT = 1,
    LOVE_THORVG_OUT_OF_MEMORY = 2,
    LOVE_THORVG_ENGINE_ERROR = 3,
    LOVE_THORVG_LOAD_ERROR = 4,
    LOVE_THORVG_RENDER_ERROR = 5
};

LOVE_THORVG_API uint32_t love_thorvg_abi_version(void);
LOVE_THORVG_API const char* love_thorvg_version(void);

LOVE_THORVG_API int love_thorvg_document_create(
    const void* data,
    size_t size,
    const char* mime_type,
    const char* resource_path,
    unsigned threads,
    love_thorvg_document** out_document,
    char* error,
    size_t error_capacity);

LOVE_THORVG_API void love_thorvg_document_destroy(love_thorvg_document* document);

LOVE_THORVG_API int love_thorvg_document_render(
    love_thorvg_document* document,
    uint32_t* rgba_pixels,
    uint32_t width,
    uint32_t height,
    uint32_t stride_pixels,
    float progress,
    char* error,
    size_t error_capacity);

LOVE_THORVG_API float love_thorvg_document_duration(const love_thorvg_document* document);
LOVE_THORVG_API float love_thorvg_document_total_frames(const love_thorvg_document* document);
LOVE_THORVG_API float love_thorvg_document_intrinsic_width(const love_thorvg_document* document);
LOVE_THORVG_API float love_thorvg_document_intrinsic_height(const love_thorvg_document* document);

#ifdef __cplusplus
}
#endif

#endif
