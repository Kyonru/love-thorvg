project(
  'love-thorvg',
  'cpp',
  version: '0.2.0',
  default_options: ['cpp_std=c++17', 'warning_level=3'],
  meson_version: '>=1.3.0',
)

thorvg_project = subproject(
  'thorvg',
  default_options: [
    'default_library=static',
    'static=true',
    'engines=cpu',
    'loaders=svg,lottie,png,ttf,otf',
    'bindings=capi',
    'savers=',
    'tests=false',
    'log=false',
    'extra=',
  ],
)
thorvg_dependency = thorvg_project.get_variable('thorvg_dep')
thorvg_headers = thorvg_project.get_variable('headers')

is_web = host_machine.system() == 'emscripten'
library_args = {
  'dependencies': thorvg_dependency,
  'include_directories': [include_directories('include'), thorvg_headers],
  'cpp_args': ['-DLOVE_THORVG_BUILD'],
  'gnu_symbol_visibility': 'hidden',
}

if is_web
  love_thorvg_library = static_library(
    'love_thorvg',
    'native/love_thorvg.cpp',
    kwargs: library_args,
  )
else
  love_thorvg_library = shared_library(
    'love_thorvg',
    'native/love_thorvg.cpp',
    install: true,
    kwargs: library_args,
  )
endif

if get_option('build_tests') and not is_web
  native_test = executable(
    'native-test',
    'tests/native_test.cpp',
    link_with: love_thorvg_library,
    include_directories: include_directories('include'),
  )
  test('native API', native_test)
endif

if get_option('web_harness')
  if not is_web
    error('web_harness requires the Emscripten cross file')
  endif

  executable(
    'love_thorvg_web',
    'web/wasm_entry.cpp',
    link_with: love_thorvg_library,
    dependencies: thorvg_dependency,
    include_directories: include_directories('include'),
    link_args: [
      '-sMODULARIZE=1',
      '-sEXPORT_NAME=LoveThorVG',
      '-sEXPORT_ES6=1',
      '-sENVIRONMENT=web,node',
      '-sALLOW_MEMORY_GROWTH=1',
      '-sEXPORTED_FUNCTIONS=["_malloc","_free","_love_thorvg_abi_version","_love_thorvg_version","_love_thorvg_document_create","_love_thorvg_document_destroy","_love_thorvg_document_render","_love_thorvg_document_duration","_love_thorvg_document_total_frames","_love_thorvg_document_intrinsic_width","_love_thorvg_document_intrinsic_height"]',
      '-sEXPORTED_RUNTIME_METHODS=["UTF8ToString","HEAPU8","HEAPU32"]',
    ],
    install: false,
  )
endif
