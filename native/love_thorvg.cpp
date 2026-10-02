#include "love_thorvg.h"

#include <thorvg_capi.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <new>
#include <string>
#include <vector>

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
    love_thorvg_asset_resolver resolver = nullptr;
    void* resolver_user_data = nullptr;
    std::string asset_error;
    std::vector<std::string> loaded_fonts;
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

const char* sniff_mime(const std::vector<uint8_t>& bytes, const char* source, int asset_type)
{
    if (bytes.size() >= 8 && std::memcmp(bytes.data(), "\x89PNG\r\n\x1a\n", 8) == 0) return "png";
    if (bytes.size() >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) return "jpg";
    if (bytes.size() >= 4 && std::memcmp(bytes.data(), "OTTO", 4) == 0) return "otf";
    if (bytes.size() >= 4 && bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0) return "ttf";
    if (!bytes.empty() && bytes[0] == '<') return "svg";

    if (source) {
        const char* dot = std::strrchr(source, '.');
        if (dot && dot[1] != '\0') return dot + 1;
    }
    return asset_type == LOVE_THORVG_ASSET_FONT ? "ttf" : "";
}

std::string font_name(const char* source)
{
    if (!source) return "love-thorvg-font";
    constexpr const char prefix[] = "name:";
    if (std::strncmp(source, prefix, sizeof(prefix) - 1) == 0) return source + sizeof(prefix) - 1;
    return source;
}

bool resolve_asset(Tvg_Paint paint, const char* source, void* data)
{
    auto* document = static_cast<love_thorvg_document*>(data);
    if (!document || !document->resolver || !source) return false;

    Tvg_Type type = TVG_TYPE_UNDEF;
    if (!succeeded(tvg_paint_get_type(paint, &type))) return false;
    const int asset_type = type == TVG_TYPE_TEXT ? LOVE_THORVG_ASSET_FONT : LOVE_THORVG_ASSET_PICTURE;
    const size_t required = document->resolver(source, asset_type, nullptr, 0, document->resolver_user_data);
    if (required == 0 || required > UINT32_MAX) {
        if (asset_type == LOVE_THORVG_ASSET_PICTURE) document->asset_error = "asset not found: " + std::string(source);
        return false;
    }

    std::vector<uint8_t> bytes(required);
    const size_t written = document->resolver(source, asset_type, bytes.data(), bytes.size(),
                                               document->resolver_user_data);
    if (written != required) {
        if (asset_type == LOVE_THORVG_ASSET_PICTURE) document->asset_error = "asset read failed: " + std::string(source);
        return false;
    }

    const char* mime = sniff_mime(bytes, source, asset_type);
    if (asset_type == LOVE_THORVG_ASSET_FONT) {
        const auto name = font_name(source);
        auto result = tvg_font_load_data(name.c_str(), reinterpret_cast<const char*>(bytes.data()),
                                         static_cast<uint32_t>(bytes.size()), mime, true);
        if (!succeeded(result)) return false;
        result = tvg_text_set_font(paint, name.c_str());
        if (!succeeded(result)) return false;
        document->loaded_fonts.push_back(name);
        return true;
    }

    const auto result = tvg_picture_load_data(paint, reinterpret_cast<const char*>(bytes.data()),
                                              static_cast<uint32_t>(bytes.size()), mime, "", true);
    if (!succeeded(result)) {
        document->asset_error = "asset decode failed: " + std::string(source);
        return false;
    }
    return true;
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
    return 2;
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
    return love_thorvg_document_create_with_resolver(
        data, size, mime_type, resource_path, threads, nullptr, nullptr,
        out_document, error, error_capacity);
}

int love_thorvg_document_create_with_resolver(
    const void* data, size_t size, const char* mime_type, const char* resource_path,
    unsigned threads, love_thorvg_asset_resolver resolver, void* resolver_user_data,
    love_thorvg_document** out_document, char* error, size_t error_capacity)
{
    if (error && error_capacity > 0) error[0] = '\0';
    if (!data || size == 0 || !out_document || size > UINT32_MAX) {
        if (error && error_capacity > 0) std::snprintf(error, error_capacity, "invalid document data");
        return LOVE_THORVG_INVALID_ARGUMENT;
    }
    *out_document = nullptr;

    auto* document = new (std::nothrow) love_thorvg_document();
    if (!document) return LOVE_THORVG_OUT_OF_MEMORY;
    document->resolver = resolver;
    document->resolver_user_data = resolver_user_data;

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

    if (resolver) {
        result = tvg_picture_set_asset_resolver(document->picture, resolve_asset, document);
        if (!succeeded(result)) {
            set_error(error, error_capacity, "setting asset resolver", result);
            love_thorvg_document_destroy(document);
            return LOVE_THORVG_LOAD_ERROR;
        }
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
    for (const auto& name : document->loaded_fonts) {
        tvg_font_load_data(name.c_str(), nullptr, 0, nullptr, false);
    }
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

    document->asset_error.clear();
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
    if (!document->asset_error.empty()) {
        if (error && error_capacity > 0) std::snprintf(error, error_capacity, "%s", document->asset_error.c_str());
        return LOVE_THORVG_LOAD_ERROR;
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
