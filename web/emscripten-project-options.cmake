# liblove is a shared intermediate, so static dependencies folded into it need
# position-independent code. Use megasource's static Lua target for the web
# build so the final executable has no browser-side .so dependencies.
if(EMSCRIPTEN)
  set(CMAKE_POSITION_INDEPENDENT_CODE ON)
  if(PROJECT_NAME STREQUAL "love")
    set(MEGA_LUA51 lua51-static)
  endif()
endif()
