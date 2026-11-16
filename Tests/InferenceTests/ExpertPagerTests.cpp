#include "ExpertCache.h"
#include <cassert>
#include <iostream>

using namespace smolmax;

void test_expert_cache_initialization() {
    ExpertCache cache;
    bool ok = cache.initialize(4, 1024 * 1024); // 4 slots, 1MB each
    assert(ok);
    assert(cache.get_pool_size() == 4);
    assert(cache.get_active_count() == 0);
    std::cout << "[PASS] test_expert_cache_initialization" << std::endl;
}

void test_expert_cache_hits_and_misses() {
    ExpertCache cache;
    cache.initialize(2, 1024);

    // Initial lookup should miss
    ExpertSlot* s1 = cache.lookup(0, 5, 1);
    assert(s1 == nullptr);
    assert(cache.get_metrics().misses == 1);

    // Acquire and load
    s1 = cache.acquire_slot_for_loading(0, 5, 1);
    assert(s1 != nullptr);
    assert(s1->key.layer_id == 0);
    assert(s1->key.expert_id == 5);

    // Subsequent lookup should hit
    ExpertSlot* s2 = cache.lookup(0, 5, 2);
    assert(s2 != nullptr);
    assert(s2 == s1);
    assert(cache.get_metrics().hits == 1);

    std::cout << "[PASS] test_expert_cache_hits_and_misses" << std::endl;
}

void test_lru_eviction() {
    ExpertCache cache;
    cache.initialize(2, 1024); // Only 2 slots

    // Load expert 0 and 1
    cache.acquire_slot_for_loading(0, 0, 10);
    cache.acquire_slot_for_loading(0, 1, 20);
    assert(cache.get_active_count() == 2);

    // Access expert 0 again to make expert 1 the oldest (LRU)
    cache.lookup(0, 0, 30);

    // Now load expert 2 -> should evict expert 1!
    ExpertSlot* s = cache.acquire_slot_for_loading(0, 2, 40);
    assert(s != nullptr);
    assert(cache.get_metrics().evictions == 1);
    assert(cache.is_cached(0, 0) == true);
    assert(cache.is_cached(0, 1) == false); // Evicted!
    assert(cache.is_cached(0, 2) == true);

    std::cout << "[PASS] test_lru_eviction" << std::endl;
}

void test_pinning_prevents_eviction() {
    ExpertCache cache;
    cache.initialize(2, 1024);

    ExpertSlot* s0 = cache.acquire_slot_for_loading(0, 0, 10);
    cache.pin_expert(s0); // Pin expert 0

    cache.acquire_slot_for_loading(0, 1, 20);

    // Even if expert 0 was accessed earlier, pinning prevents it from being evicted
    ExpertSlot* s2 = cache.acquire_slot_for_loading(0, 2, 30);
    assert(s2 != nullptr);
    assert(cache.is_cached(0, 0) == true); // Still cached because pinned!
    assert(cache.is_cached(0, 1) == false); // Expert 1 was evicted instead!

    cache.unpin_expert(s0);
    std::cout << "[PASS] test_pinning_prevents_eviction" << std::endl;
}

int main() {
    std::cout << "--- Running SmolMax Expert Pager Tests ---" << std::endl;
    test_expert_cache_initialization();
    test_expert_cache_hits_and_misses();
    test_lru_eviction();
    test_pinning_prevents_eviction();
    std::cout << "All Expert Pager C++ tests PASSED successfully!" << std::endl;
    return 0;
}
