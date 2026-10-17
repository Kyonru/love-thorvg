#include "love_thorvg.h"

#include <lua.h>
#include <lauxlib.h>

#include <cstdint>
#include <cstring>
#include <limits>
#include <new>
#include <vector>

namespace {

constexpr const char* metatable_name = "love_thorvg.web.document";

struct LuaDocument {
    love_thorvg_document* document;
    lua_State* state;
    int resolver_ref;
};

LuaDocument* check_document(lua_State* state, int index)
{
    return static_cast<LuaDocument*>(luaL_checkudata(state, index, metatable_name));
}

size_t resolve_asset(const char* source, int asset_type, void* buffer, size_t capacity,
                     void* user_data)
{
    auto* value = static_cast<LuaDocument*>(user_data);
    if (!value || value->resolver_ref == LUA_NOREF) return 0;

    lua_State* state = value->state;
    const int top = lua_gettop(state);
    lua_rawgeti(state, LUA_REGISTRYINDEX, value->resolver_ref);
    lua_pushstring(state, source ? source : "");
    lua_pushstring(state, asset_type == LOVE_THORVG_ASSET_FONT ? "font" : "picture");
    if (lua_pcall(state, 2, 1, 0) != 0 || !lua_isstring(state, -1)) {
        lua_settop(state, top);
        return 0;
    }

    size_t size = 0;
    const char* bytes = lua_tolstring(state, -1, &size);
    if (buffer && capacity >= size) std::memcpy(buffer, bytes, size);
    lua_settop(state, top);
    return size;
}

int release(lua_State* state)
{
    auto* value = check_document(state, 1);
    if (value->document) {
        love_thorvg_document_destroy(value->document);
        value->document = nullptr;
    }
    if (value->resolver_ref != LUA_NOREF) {
        luaL_unref(state, LUA_REGISTRYINDEX, value->resolver_ref);
        value->resolver_ref = LUA_NOREF;
    }
    return 0;
}

int create(lua_State* state)
{
    size_t size = 0;
    const char* bytes = luaL_checklstring(state, 1, &size);
    const char* mime = luaL_optstring(state, 2, "");
    const char* resource_path = luaL_optstring(state, 3, "");
    const unsigned threads = static_cast<unsigned>(luaL_optinteger(state, 4, 0));
    luaL_checktype(state, 5, LUA_TFUNCTION);

    auto* value = static_cast<LuaDocument*>(lua_newuserdata(state, sizeof(LuaDocument)));
    value->document = nullptr;
    value->state = state;
    lua_pushvalue(state, 5);
    value->resolver_ref = luaL_ref(state, LUA_REGISTRYINDEX);
    luaL_getmetatable(state, metatable_name);
    lua_setmetatable(state, -2);

    char error[512] = {};
    const int result = love_thorvg_document_create_with_resolver(
        bytes, size, mime, resource_path, threads, resolve_asset, value,
        &value->document, error, sizeof(error));
    if (result != LOVE_THORVG_OK) {
        luaL_unref(state, LUA_REGISTRYINDEX, value->resolver_ref);
        value->resolver_ref = LUA_NOREF;
        lua_pop(state, 1);
        lua_pushnil(state);
        lua_pushstring(state, error[0] ? error : "ThorVG load failed");
        return 2;
    }

    lua_pushnumber(state, love_thorvg_document_duration(value->document));
    lua_pushnumber(state, love_thorvg_document_total_frames(value->document));
    lua_pushnumber(state, love_thorvg_document_intrinsic_width(value->document));
    lua_pushnumber(state, love_thorvg_document_intrinsic_height(value->document));
    return 5;
}

int render(lua_State* state)
{
    auto* value = check_document(state, 1);
    if (!value->document) return luaL_error(state, "document has been released");
    const uint32_t width = static_cast<uint32_t>(luaL_checkinteger(state, 2));
    const uint32_t height = static_cast<uint32_t>(luaL_checkinteger(state, 3));
    const float progress = static_cast<float>(luaL_checknumber(state, 4));
    if (width == 0 || height == 0 ||
        static_cast<size_t>(width) > std::numeric_limits<size_t>::max() / height / sizeof(uint32_t)) {
        return luaL_error(state, "invalid render dimensions");
    }

    std::vector<uint32_t> pixels;
    try {
        pixels.resize(static_cast<size_t>(width) * height);
    } catch (const std::bad_alloc&) {
        lua_pushnil(state);
        lua_pushstring(state, "not enough memory for render target");
        return 2;
    }
    char error[512] = {};
    const int result = love_thorvg_document_render(
        value->document, pixels.data(), width, height, width, progress, error, sizeof(error));
    if (result != LOVE_THORVG_OK) {
        lua_pushnil(state);
        lua_pushstring(state, error[0] ? error : "ThorVG render failed");
        return 2;
    }
    lua_pushlstring(state, reinterpret_cast<const char*>(pixels.data()),
                    pixels.size() * sizeof(uint32_t));
    return 1;
}

int version(lua_State* state)
{
    lua_pushstring(state, love_thorvg_version());
    return 1;
}

int abi_version(lua_State* state)
{
    lua_pushinteger(state, love_thorvg_abi_version());
    return 1;
}

const luaL_Reg module_functions[] = {
    {"new", create},
    {"render", render},
    {"release", release},
    {"version", version},
    {"abiVersion", abi_version},
    {nullptr, nullptr},
};

}  // namespace

extern "C" int luaopen_love_thorvg_web(lua_State* state)
{
    luaL_newmetatable(state, metatable_name);
    lua_pushcfunction(state, release);
    lua_setfield(state, -2, "__gc");
    lua_pop(state, 1);

    lua_newtable(state);
    luaL_register(state, nullptr, module_functions);
    return 1;
}
