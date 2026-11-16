#include "MoERoutingPolicy.h"
#include <cassert>
#include <iostream>
#include <cmath>

using namespace smolmax;

void test_exact_top_k_routing() {
    // 4 experts, logits: [1.0, 5.0, 2.0, 4.0]
    float logits[4] = {1.0f, 5.0f, 2.0f, 4.0f};
    int32_t num_experts = 4;
    int32_t top_k = 2;

    auto res = MoERoutingPolicy::select_experts(
        logits, num_experts, top_k,
        [](int32_t) { return false; },
        0.0f // No cache bias -> exact routing
    );

    assert(res.size() == 2);
    // Highest is expert 1 (score 5.0), second highest is expert 3 (score 4.0)
    assert(res[0].expert_id == 1);
    assert(res[1].expert_id == 3);
    assert(res[0].weight > res[1].weight);
    
    // Softmax probabilities should sum to approximately 1.0
    float sum_weights = res[0].weight + res[1].weight;
    assert(std::fabs(sum_weights - 1.0f) < 1e-4);

    std::cout << "[PASS] test_exact_top_k_routing" << std::endl;
}

void test_cache_aware_bias() {
    // Expert 0 has 3.0, Expert 1 has 3.1
    // If expert 0 is cached and we give bias +0.5, expert 0 should win!
    float logits[2] = {3.0f, 3.1f};
    auto res = MoERoutingPolicy::select_experts(
        logits, 2, 1,
        [](int32_t id) { return id == 0; },
        0.5f // Bias for resident expert 0
    );

    assert(res.size() == 1);
    assert(res[0].expert_id == 0); // Cached expert won due to bias

    std::cout << "[PASS] test_cache_aware_bias" << std::endl;
}

int main() {
    std::cout << "--- Running SmolMax Routing Correctness Tests ---" << std::endl;
    test_exact_top_k_routing();
    test_cache_aware_bias();
    std::cout << "All Routing Correctness tests PASSED successfully!" << std::endl;
    return 0;
}
