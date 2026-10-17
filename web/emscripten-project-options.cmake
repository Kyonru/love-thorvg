# liblove is a shared intermediate, so static dependencies folded into it need
# position-independent code. Keep the legacy Lua shared target non-PIC so
# Emscripten folds it into the final executable instead of emitting a .so
# dependency. mpg123 is disabled by the web build but retained here defensively.
if(EMSCRIPTEN)
  if(PROJECT_NAME STREQUAL "lua51" OR PROJECT_NAME STREQUAL "mpg123")
    set(CMAKE_POSITION_INDEPENDENT_CODE OFF)
  else()
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
  endif()
endif()
