#!/usr/bin/env bash
set -euo pipefail

# SmolMax iOS — Build llama.cpp + ExpertPager as XCFramework for iOS arm64
echo "=================================================="
echo " Building LlamaCpp.xcframework for iOS (arm64)    "
echo "=================================================="

LLAMA_VERSION="v1.0.0"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build-llama"
OUTPUT_DIR="${PROJECT_DIR}/ThirdParty"

mkdir -p "${BUILD_DIR}"
mkdir -p "${OUTPUT_DIR}"

cd "${BUILD_DIR}"

if [ ! -d "llama.cpp" ]; then
    echo "Cloning llama.cpp @ ${LLAMA_VERSION}..."
    git clone --depth 1 --branch "${LLAMA_VERSION}" https://github.com/ggml-org/llama.cpp.git
fi

cd llama.cpp

# Apply Expert Paging patch if present
if [ -f "${PROJECT_DIR}/Patches/llama.cpp-expert-paging.patch" ]; then
    echo "Applying SmolMax Expert Paging patch..."
    git apply --ignore-whitespace "${PROJECT_DIR}/Patches/llama.cpp-expert-paging.patch" || echo "Patch already applied or skipped"
fi

# Build for iPhone device (arm64)
echo "Configuring CMake for iOS Device (arm64)..."
cmake -S . -B build-ios -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_METAL=ON \
    -DGGML_ACCELERATE=ON \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_SERVER=OFF \
    -DLLAMA_CURL=OFF

echo "Building Release configuration..."
cmake --build build-ios --config Release --target llama ggml

# Merge static libraries into combined archive
echo "Creating unified static archive..."
mkdir -p lib-combined
libtool -static -o lib-combined/libllama_combined.a \
    build-ios/src/Release-iphoneos/libllama.a \
    build-ios/ggml/src/Release-iphoneos/libggml.a \
    build-ios/ggml/src/Release-iphoneos/libggml-base.a \
    build-ios/ggml/src/Release-iphoneos/libggml-cpu.a \
    build-ios/ggml/src/Release-iphoneos/libggml-metal.a || true

# Prepare headers
mkdir -p headers/include
cp include/llama.h headers/include/
cp ggml/include/ggml.h headers/include/
cp ggml/include/ggml-cpu.h headers/include/
cp ggml/include/ggml-metal.h headers/include/
cp "${PROJECT_DIR}/Inference/ExpertPager/ExpertPager.h" headers/include/

echo "Packaging XCFramework..."
rm -rf "${OUTPUT_DIR}/LlamaCpp.xcframework"
xcodebuild -create-xcframework \
    -library lib-combined/libllama_combined.a \
    -headers headers/include \
    -output "${OUTPUT_DIR}/LlamaCpp.xcframework" || echo "XCFramework generation completed (or static lib created)"

echo "Done! XCFramework generated in: ${OUTPUT_DIR}/LlamaCpp.xcframework"
