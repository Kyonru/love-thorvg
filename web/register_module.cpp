extern "C" {
#include <lua.h>
#include <lauxlib.h>
}

extern "C" int luaopen_love_thorvg_web(lua_State* state);

// Call this after the love.js Lua state is created. Keeping registration in a
// tiny translation unit makes the love.js patch independent of ThorVG itself.
extern "C" void love_thorvg_register_web_module(lua_State* state)
{
    lua_getglobal(state, "package");
    lua_getfield(state, -1, "preload");
    lua_pushcfunction(state, luaopen_love_thorvg_web);
    lua_setfield(state, -2, "love_thorvg_web");
    lua_pop(state, 2);
}
