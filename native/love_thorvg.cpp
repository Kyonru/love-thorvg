#include "love_thorvg.h"

#include <thorvg_capi.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <new>
#include <map>
#include <mutex>
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
    std::map<std::string, std::vector<Tvg_Paint>> elements;
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

// ThorVG's font registry is global. Share identical families across documents,
// and reject conflicting registrations instead of silently changing live text.
struct SharedFont {
    std::vector<uint8_t> bytes;
    size_t owners = 0;
};
std::map<std::string, SharedFont> fonts;
std::mutex fonts_mutex;

bool acquire_font(love_thorvg_document* document, const std::string& name,
                  const std::vector<uint8_t>& bytes, const char* mime)
{
    std::lock_guard<std::mutex> lock(fonts_mutex);
    auto found = fonts.find(name);
    if (found != fonts.end() && found->second.bytes != bytes) {
        document->asset_error = "font family already loaded with different data: " + name;
        return false;
    }
    if (std::find(document->loaded_fonts.begin(), document->loaded_fonts.end(), name) != document->loaded_fonts.end()) return true;
    if (found == fonts.end()) {
        const auto result = tvg_font_load_data(name.c_str(), reinterpret_cast<const char*>(bytes.data()),
                                              static_cast<uint32_t>(bytes.size()), mime, true);
        if (!succeeded(result)) {
            document->asset_error = "font decode failed: " + name;
            return false;
        }
        found = fonts.emplace(name, SharedFont{bytes, 0}).first;
    }
    ++found->second.owners;
    document->loaded_fonts.push_back(name);
    return true;
}

void release_fonts(love_thorvg_document* document)
{
    std::lock_guard<std::mutex> lock(fonts_mutex);
    for (const auto& name : document->loaded_fonts) {
        auto found = fonts.find(name);
        if (found != fonts.end() && --found->second.owners == 0) {
            tvg_font_load_data(name.c_str(), nullptr, 0, nullptr, false);
            fonts.erase(found);
        }
    }
}

bool preload_font(love_thorvg_document* document, const char* name)
{
    const auto source = std::string("name:") + name;
    const auto required = document->resolver(source.c_str(), LOVE_THORVG_ASSET_FONT, nullptr, 0, document->resolver_user_data);
    if (required == 0 || required > UINT32_MAX) {
        document->asset_error = "font not found: " + std::string(name);
        return false;
    }
    std::vector<uint8_t> bytes(required);
    if (document->resolver(source.c_str(), LOVE_THORVG_ASSET_FONT, bytes.data(), bytes.size(), document->resolver_user_data) != required) {
        document->asset_error = "font read failed: " + std::string(name);
        return false;
    }
    return acquire_font(document, name, bytes, sniff_mime(bytes, name, LOVE_THORVG_ASSET_FONT));
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
        if (!acquire_font(document, name, bytes, mime)) return false;
        return succeeded(tvg_text_set_font(paint, name.c_str()));
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


struct ElementSearch {
    uint32_t id;
    std::vector<Tvg_Paint> paints;
    bool failed = false;
};

const std::vector<Tvg_Paint>& find_elements(love_thorvg_document* document, const char* id)
{
    auto found = document->elements.find(id);
    if (found != document->elements.end()) return found->second;
    ElementSearch search{tvg_accessor_generate_id(id), {}, false};
    auto accessor = tvg_accessor_new();
    if (!accessor) throw std::bad_alloc();
    const auto result = tvg_accessor_set(accessor, document->picture, [](Tvg_Paint paint, void* data) {
        auto* search = static_cast<ElementSearch*>(data);
        if (tvg_paint_get_id(paint) == search->id) {
            try { search->paints.push_back(paint); }
            catch (...) { search->failed = true; return false; }
        }
        return true;
    }, &search);
    tvg_accessor_del(accessor);
    if (search.failed) throw std::bad_alloc();
    if (!succeeded(result)) search.paints.clear();
    return document->elements.emplace(id, std::move(search.paints)).first->second;
}

int element_error(char* error, size_t capacity, const char* message)
{
    if (error && capacity) std::snprintf(error, capacity, "%s", message);
    return LOVE_THORVG_INVALID_ARGUMENT;
}

}  // namespace

extern "C" {

uint32_t love_thorvg_abi_version(void)
{
    return 2;
}

const char* love_thorvg_version(void)
{
    return "0.3.0";
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
    return love_thorvg_document_create_with_fonts(data, size, mime_type, resource_path,
        threads, resolver, resolver_user_data, nullptr, 0, out_document, error, error_capacity);
}

int love_thorvg_document_create_with_fonts(
    const void* data, size_t size, const char* mime_type, const char* resource_path,
    unsigned threads, love_thorvg_asset_resolver resolver, void* resolver_user_data,
    const char* const* font_names, size_t font_count,
    love_thorvg_document** out_document, char* error, size_t error_capacity)
{
    if (out_document) *out_document = nullptr;
    if (error && error_capacity > 0) error[0] = '\0';
    if (!data || size == 0 || !out_document || size > UINT32_MAX || (font_count && (!font_names || !resolver))) {
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
    for (size_t i = 0; i < font_count; ++i) {
        if (!font_names[i] || !font_names[i][0] || !preload_font(document, font_names[i])) {
            if (error && error_capacity > 0) std::snprintf(error, error_capacity, "%s",
                document->asset_error.empty() ? "invalid font family" : document->asset_error.c_str());
            love_thorvg_document_destroy(document);
            return LOVE_THORVG_LOAD_ERROR;
        }
    }

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

    tvg_picture_set_accessible(document->picture, true);
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
    release_fonts(document);
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


int love_thorvg_document_element_bounds(love_thorvg_document* document, const char* id,
                                        float* xywh, char* error, size_t error_capacity)
{
    if (!document || !id || !*id || !xywh)
        return element_error(error, error_capacity, "invalid element bounds arguments");
    try {
        const auto& paints = find_elements(document, id);
        if (paints.empty()) return element_error(error, error_capacity, "SVG element ID not found");
        // A detached duplicate gives parent-space bounds independent of the
        // document viewport, ancestor transforms, and previous render size.
        auto copy = tvg_paint_duplicate(paints.front());
        auto canvas = tvg_swcanvas_create(TVG_ENGINE_OPTION_DEFAULT);
        if (!copy || !canvas) {
            if (copy) tvg_paint_unref(copy, true);
            if (canvas) tvg_canvas_destroy(canvas);
            return LOVE_THORVG_OUT_OF_MEMORY;
        }
        // CSS fill-box origins use geometry, not the stroke outline.
        auto geometry = tvg_accessor_new();
        if (!geometry) {
            tvg_paint_unref(copy, true);
            tvg_canvas_destroy(canvas);
            return LOVE_THORVG_OUT_OF_MEMORY;
        }
        tvg_accessor_set(geometry, copy, [](Tvg_Paint paint, void*) {
            Tvg_Type type = TVG_TYPE_UNDEF;
            tvg_paint_get_type(paint, &type);
            if (type == TVG_TYPE_SHAPE) tvg_shape_set_stroke_width(paint, 0);
            return true;
        }, nullptr);
        tvg_accessor_del(geometry);
        uint32_t pixel = 0;
        auto result = tvg_swcanvas_set_target(canvas, &pixel, 1, 1, 1, TVG_COLORSPACE_ABGR8888S);
        if (succeeded(result)) result = tvg_canvas_add(canvas, copy);
        if (!succeeded(result)) {
            tvg_paint_unref(copy, true);
            tvg_canvas_destroy(canvas);
            set_error(error, error_capacity, "preparing element bounds", result);
            return LOVE_THORVG_RENDER_ERROR;
        }
        result = tvg_canvas_update(canvas);
        if (succeeded(result)) result = tvg_paint_get_aabb(copy, &xywh[0], &xywh[1], &xywh[2], &xywh[3]);
        tvg_canvas_sync(canvas);
        tvg_canvas_destroy(canvas);
        if (!succeeded(result)) {
            set_error(error, error_capacity, "measuring element bounds", result);
            return LOVE_THORVG_RENDER_ERROR;
        }
        return LOVE_THORVG_OK;
    } catch (...) {
        return element_error(error, error_capacity, "could not index SVG elements");
    }
}

int love_thorvg_document_set_element(love_thorvg_document* document, const char* id,
                                     const float* abcdef, float opacity,
                                     char* error, size_t error_capacity)
{
    if (!document || !id || !*id || !abcdef || !std::isfinite(opacity) || opacity < 0 || opacity > 1)
        return element_error(error, error_capacity, "invalid element transform or opacity");
    for (int i = 0; i < 6; ++i) {
        if (!std::isfinite(abcdef[i])) return element_error(error, error_capacity, "non-finite element transform");
    }
    try {
        const auto& paints = find_elements(document, id);
        if (paints.empty()) return element_error(error, error_capacity, "SVG element ID not found");
        const Tvg_Matrix matrix = {abcdef[0], abcdef[2], abcdef[4], abcdef[1], abcdef[3], abcdef[5], 0, 0, 1};
        for (auto paint : paints) {
            auto result = tvg_paint_set_transform(paint, &matrix);
            if (succeeded(result)) result = tvg_paint_set_opacity(paint, static_cast<uint8_t>(std::lround(opacity * 255)));
            if (!succeeded(result)) {
                set_error(error, error_capacity, "updating SVG element", result);
                return LOVE_THORVG_RENDER_ERROR;
            }
        }
        return LOVE_THORVG_OK;
    } catch (...) {
        return element_error(error, error_capacity, "could not index SVG elements");
    }
}

}  // extern "C"
