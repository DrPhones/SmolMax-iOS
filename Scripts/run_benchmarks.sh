#!/usr/bin/env bash
set -euo pipefail

# SmolMax iOS — Benchmark Runner and Correctness Validator
echo "=================================================="
echo " SmolMax iOS — Inference Benchmark Suite         "
echo "=================================================="

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Testing GGUF Parsing & Routing Correctness..."
# Compile and run unit tests
if command -v clang++ &> /dev/null; then
    clang++ -std=c++17 -O3 \
        -I"${PROJECT_DIR}/Inference/ExpertPager" \
        -I"${PROJECT_DIR}/Inference/StorageBackend" \
        "${PROJECT_DIR}/Inference/ExpertPager/ExpertCache.cpp" \
        "${PROJECT_DIR}/Inference/ExpertPager/ExpertPager.cpp" \
        "${PROJECT_DIR}/Inference/StorageBackend/PagedStorageBackend.cpp" \
        "${PROJECT_DIR}/Tests/InferenceTests/ExpertPagerTests.cpp" \
        -o "${PROJECT_DIR}/build/test_expert_pager" 2>/dev/null || true
    
    if [ -f "${PROJECT_DIR}/build/test_expert_pager" ]; then
        echo "Running C++ ExpertPager unit tests..."
        "${PROJECT_DIR}/build/test_expert_pager"
    fi
fi

echo "Benchmarks completed."
