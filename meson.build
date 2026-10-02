project(
  'love-thorvg',
  'cpp',
  version: '0.1.0',
  default_options: ['cpp_std=c++17', 'warning_level=3'],
  meson_version: '>=1.3.0',
)

thorvg_project = subproject(
  'thorvg',
  default_options: [
    'default_library=static',
    'engines=cpu',
    'loaders=svg,lottie',
    'bindings=capi',
    'savers=',
    'tests=false',
    'log=false',
    'extra=',
  ],
)
thorvg_dependency = thorvg_project.get_variable('thorvg_dep')
thorvg_headers = thorvg_project.get_variable('headers')

love_thorvg_library = shared_library(
  'love_thorvg',
  'native/love_thorvg.cpp',
  dependencies: thorvg_dependency,
  include_directories: [include_directories('include'), thorvg_headers],
  cpp_args: ['-DLOVE_THORVG_BUILD'],
  gnu_symbol_visibility: 'hidden',
  install: true,
)

if get_option('build_tests')
  native_test = executable(
    'native-test',
    'tests/native_test.cpp',
    link_with: love_thorvg_library,
    include_directories: include_directories('include'),
  )
  test('native API', native_test)
endif
