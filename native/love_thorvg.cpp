#include "love_thorvg.h"

#include <thorvg_capi.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <new>

struct love_thorvg_document {
    Tvg_Canvas canvas = nullptr;
    Tvg_Animation animation = nullptr;
    Tvg_Paint picture = nullptr;
    float intrinsic_width = 0.0f;
    float intrinsic_height = 0.0f;
    float duration = 0.0f;
    float total_frames = 0.0f;
    uint32_t target_width = 0;
    uint32_t target_height = 0;
    bool added = false;
    bool engine_initialized = false;
};

namespace {

void set_error(char* error, size_t capacity, const char* operation, Tvg_Result result)
{
    if (!error || capacity == 0) return;
    std::snprintf(error, capacity, "%s failed (ThorVG result %d)", operation, static_cast<int>(result));
}

bool succeeded(Tvg_Result result)
{
    return result == TVG_RESULT_SUCCESS;
}

bool frame_result_ok(Tvg_Result result)
{
    return result == TVG_RESULT_SUCCESS || result == TVG_RESULT_INSUFFICIENT_CONDITION ||
           result == TVG_RESULT_NOT_SUPPORTED;
}

int apply_transform(love_thorvg_document* document, uint32_t width, uint32_t height,
                    char* error, size_t error_capacity)
{
    if (document->target_width == width && document->target_height == height) return LOVE_THORVG_OK;

    const float source_width = document->intrinsic_width > 0.0f ? document->intrinsic_width : static_cast<float>(width);
    const float source_height = document->intrinsic_height > 0.0f ? document->intrinsic_height : static_cast<float>(height);
    const float scale = std::min(static_cast<float>(width) / source_width,
                                 static_cast<float>(height) / source_height);
    const float x = (static_cast<float>(width) - source_width * scale) * 0.5f;
    const float y = (static_cast<float>(height) - source_height * scale) * 0.5f;
    const Tvg_Matrix matrix = {
        scale, 0.0f, x,
        0.0f, scale, y,
        0.0f, 0.0f, 1.0f
    };

    const auto result = tvg_paint_set_transform(document->picture, &matrix);
    if (!succeeded(result)) {
        set_error(error, error_capacity, "setting picture transform", result);
        return LOVE_THORVG_RENDER_ERROR;
    }
    document->target_width = width;
    document->target_height = height;
    return LOVE_THORVG_OK;
}

}  // namespace

extern "C" {

uint32_t love_thorvg_abi_version(void)
{
    return 1;
}

const char* love_thorvg_version(void)
{
    return "0.1.0";
}

int love_thorvg_document_create(const void* data, size_t size, const char* mime_type,
                                const char* resource_path, unsigned threads,
                                love_thorvg_document** out_document,
                                char* error, size_t error_capacity)
{
    if (error && error_capacity > 0) error[0] = '\0';
    if (!data || size == 0 || !out_document || size > UINT32_MAX) {
        if (error && error_capacity > 0) std::snprintf(error, error_capacity, "invalid document data");
        return LOVE_THORVG_INVALID_ARGUMENT;
    }
    *out_document = nullptr;

    auto* document = new (std::nothrow) love_thorvg_document();
    if (!document) return LOVE_THORVG_OUT_OF_MEMORY;

    auto result = tvg_engine_init(threads);
    if (!succeeded(result)) {
        set_error(error, error_capacity, "initializing ThorVG", result);
        delete document;
        return LOVE_THORVG_ENGINE_ERROR;
    }
    document->engine_initialized = true;

    document->canvas = tvg_swcanvas_create(TVG_ENGINE_OPTION_DEFAULT);
    document->animation = tvg_animation_new();
    document->picture = document->animation ? tvg_animation_get_picture(document->animation) : nullptr;
    if (!document->canvas || !document->animation || !document->picture) {
        if (error && error_capacity > 0) std::snprintf(error, error_capacity, "creating ThorVG objects failed");
        love_thorvg_document_destroy(document);
        return LOVE_THORVG_ENGINE_ERROR;
    }

    result = tvg_picture_load_data(document->picture,
                                   static_cast<const char*>(data),
                                   static_cast<uint32_t>(size),
                                   mime_type ? mime_type : "",
                                   resource_path ? resource_path : "",
                                   true);
    if (!succeeded(result)) {
        set_error(error, error_capacity, "loading vector document", result);
        love_thorvg_document_destroy(document);
        return LOVE_THORVG_LOAD_ERROR;
    }

    tvg_picture_get_size(document->picture, &document->intrinsic_width, &document->intrinsic_height);
    tvg_animation_get_duration(document->animation, &document->duration);
    tvg_animation_get_total_frame(document->animation, &document->total_frames);
    *out_document = document;
    return LOVE_THORVG_OK;
}

void love_thorvg_document_destroy(love_thorvg_document* document)
{
    if (!document) return;
    if (document->canvas) {
        tvg_canvas_sync(document->canvas);
        tvg_canvas_destroy(document->canvas);
    }
    if (document->animation) tvg_animation_del(document->animation);
    if (document->engine_initialized) tvg_engine_term();
    delete document;
}

int love_thorvg_document_render(love_thorvg_document* document, uint32_t* rgba_pixels,
                                uint32_t width, uint32_t height, uint32_t stride_pixels,
                                float progress, char* error, size_t error_capacity)
{
    if (error && error_capacity > 0) error[0] = '\0';
    if (!document || !rgba_pixels || width == 0 || height == 0 || stride_pixels < width) {
        if (error && error_capacity > 0) std::snprintf(error, error_capacity, "invalid render target");
        return LOVE_THORVG_INVALID_ARGUMENT;
    }

    auto result = tvg_swcanvas_set_target(document->canvas, rgba_pixels, stride_pixels, width, height,
                                          TVG_COLORSPACE_ABGR8888S);
    if (!succeeded(result)) {
        set_error(error, error_capacity, "setting software target", result);
        return LOVE_THORVG_RENDER_ERROR;
    }

    const int transform_result = apply_transform(document, width, height, error, error_capacity);
    if (transform_result != LOVE_THORVG_OK) return transform_result;

    if (!document->added) {
        result = tvg_canvas_add(document->canvas, document->picture);
        if (!succeeded(result)) {
            set_error(error, error_capacity, "adding picture to canvas", result);
            return LOVE_THORVG_RENDER_ERROR;
        }
        document->added = true;
    }

    progress = std::isfinite(progress) ? std::clamp(progress, 0.0f, 1.0f) : 0.0f;
    if (document->total_frames > 1.0f) {
        result = tvg_animation_set_frame(document->animation, progress * (document->total_frames - 1.0f));
        if (!frame_result_ok(result)) {
            set_error(error, error_capacity, "setting animation frame", result);
            return LOVE_THORVG_RENDER_ERROR;
        }
    }

    result = tvg_canvas_update(document->canvas);
    if (!succeeded(result)) {
        set_error(error, error_capacity, "updating canvas", result);
        return LOVE_THORVG_RENDER_ERROR;
    }
    result = tvg_canvas_draw(document->canvas, true);
    if (!succeeded(result)) {
        set_error(error, error_capacity, "drawing canvas", result);
        return LOVE_THORVG_RENDER_ERROR;
    }
    result = tvg_canvas_sync(document->canvas);
    if (!succeeded(result)) {
        set_error(error, error_capacity, "synchronizing canvas", result);
        return LOVE_THORVG_RENDER_ERROR;
    }
    return LOVE_THORVG_OK;
}

float love_thorvg_document_duration(const love_thorvg_document* document)
{
    return document ? document->duration : 0.0f;
}

float love_thorvg_document_total_frames(const love_thorvg_document* document)
{
    return document ? document->total_frames : 0.0f;
}

float love_thorvg_document_intrinsic_width(const love_thorvg_document* document)
{
    return document ? document->intrinsic_width : 0.0f;
}

float love_thorvg_document_intrinsic_height(const love_thorvg_document* document)
{
    return document ? document->intrinsic_height : 0.0f;
}

}  // extern "C"
