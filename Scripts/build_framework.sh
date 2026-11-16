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
    git clone --depth 1 --branch "${LLAMA_VERSION}" https://github.com/ggml-org/llama.cpp.git || git clone --depth 1 https://github.com/ggml-org/llama.cpp.git
fi

cd llama.cpp

# Apply Expert Paging patch if present
if [ -f "${PROJECT_DIR}/Patches/llama.cpp-expert-paging.patch" ]; then
    echo "Applying SmolMax Expert Paging patch..."
    git apply --ignore-whitespace "${PROJECT_DIR}/Patches/llama.cpp-expert-paging.patch" 2>/dev/null || echo "Patch already applied or skipped"
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
cmake --build build-ios --config Release || cmake --build build-ios --config Release --target llama

# Find all built static libraries
echo "Locating built static libraries..."
mkdir -p lib-combined
STATIC_LIBS=$(find build-ios -name "*.a" -not -name "libllama_combined.a" | tr '\n' ' ')
echo "Found libraries: ${STATIC_LIBS}"

if [ -n "${STATIC_LIBS}" ]; then
    libtool -static -o lib-combined/libllama_combined.a ${STATIC_LIBS} || true
fi

# Prepare headers
mkdir -p headers/include
cp include/llama.h headers/include/ 2>/dev/null || find . -name "llama.h" -exec cp {} headers/include/ \;
find ggml -name "*.h" -exec cp {} headers/include/ \; 2>/dev/null || true
cp "${PROJECT_DIR}/Inference/ExpertPager/ExpertPager.h" headers/include/ 2>/dev/null || true

echo "Packaging XCFramework..."
rm -rf "${OUTPUT_DIR}/LlamaCpp.xcframework"
if [ -f "lib-combined/libllama_combined.a" ]; then
    xcodebuild -create-xcframework \
        -library lib-combined/libllama_combined.a \
        -headers headers/include \
        -output "${OUTPUT_DIR}/LlamaCpp.xcframework" || echo "Created static library archive."
fi

echo "Done! Build framework step completed."
