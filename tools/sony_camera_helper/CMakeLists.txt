cmake_minimum_required(VERSION 3.20)
cmake_policy(SET CMP0091 NEW)  # MSVC_RUNTIME_LIBRARY
project(sony_camera_helper LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT WIN32)
  message(FATAL_ERROR "sony_camera_helper hanya untuk Windows (transport WIA).")
endif()

add_executable(sony_camera_helper
  src/main.cpp
  src/json_min.cpp
  src/ptp_wia.cpp
  src/sony_camera.cpp
)

target_compile_definitions(sony_camera_helper PRIVATE
  WIN32_LEAN_AND_MEAN
  NOMINMAX
  _WIN32_WINNT=0x0A00
  _CRT_SECURE_NO_WARNINGS
)

target_link_libraries(sony_camera_helper PRIVATE
  ws2_32
  ole32
  oleaut32
  wiaguid
)

if(MSVC)
  target_compile_options(sony_camera_helper PRIVATE /W4 /permissive- /utf-8)
  # Runtime statis supaya .exe bisa dikirim tanpa VC++ redistributable.
  set_property(TARGET sony_camera_helper PROPERTY
    MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

install(TARGETS sony_camera_helper RUNTIME DESTINATION .)
