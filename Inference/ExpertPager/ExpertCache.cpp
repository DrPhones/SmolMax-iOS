#include "ExpertCache.h"
#include <cstdlib>
#include <algorithm>
#include <iostream>

#if defined(__APPLE__)
#include <stdlib.h>
#endif

namespace smolmax {

ExpertCache::ExpertCache() {}

ExpertCache::~ExpertCache() {
    teardown();
}

bool ExpertCache::initialize(size_t pool_size, size_t max_expert_size_bytes) {
    std::lock_guard<std::mutex> lock(mutex_);
    teardown();

    if (pool_size == 0 || max_expert_size_bytes == 0) {
        return false;
    }

    max_expert_size_bytes_ = max_expert_size_bytes;
    slots_.resize(pool_size);

    for (size_t i = 0; i < pool_size; ++i) {
        slots_[i].slot_id = static_cast<int32_t>(i);
        slots_[i].capacity_bytes = max_expert_size_bytes;
        slots_[i].key = {-1, -1};
        slots_[i].last_accessed_step = 0;
        slots_[i].pin_count = 0;
        slots_[i].is_valid = false;

        // Allocate 64-byte aligned memory for optimal NEON SIMD access
        void* ptr = nullptr;
#if defined(__APPLE__) || defined(__linux__)
        int res = posix_memalign(&ptr, 64, max_expert_size_bytes);
        if (res != 0 || !ptr) {
            std::cerr << "[SmolMax ExpertCache] Failed to allocate aligned memory for slot " << i << std::endl;
            teardown();
            return false;
        }
#else
        ptr = malloc(max_expert_size_bytes);
        if (!ptr) {
            teardown();
            return false;
        }
#endif
        slots_[i].memory_buffer = ptr;
    }

    metrics_.reset();
    return true;
}

void ExpertCache::teardown() {
    for (auto& slot : slots_) {
        if (slot.memory_buffer) {
            free(slot.memory_buffer);
            slot.memory_buffer = nullptr;
        }
    }
    slots_.clear();
    index_map_.clear();
    max_expert_size_bytes_ = 0;
}

ExpertSlot* ExpertCache::lookup(int32_t layer_id, int32_t expert_id, uint64_t current_step) {
    std::lock_guard<std::mutex> lock(mutex_);
    ExpertKey key{layer_id, expert_id};

    auto it = index_map_.find(key);
    if (it != index_map_.end()) {
        int32_t slot_idx = it->second;
        slots_[slot_idx].last_accessed_step = current_step;
        metrics_.hits.fetch_add(1, std::memory_order_relaxed);
        return &slots_[slot_idx];
    }

    metrics_.misses.fetch_add(1, std::memory_order_relaxed);
    return nullptr;
}

ExpertSlot* ExpertCache::acquire_slot_for_loading(int32_t layer_id, int32_t expert_id, uint64_t current_step) {
    std::lock_guard<std::mutex> lock(mutex_);
    ExpertKey new_key{layer_id, expert_id};

    // If already in cache, return it
    auto it = index_map_.find(new_key);
    if (it != index_map_.end()) {
        int32_t slot_idx = it->second;
        slots_[slot_idx].last_accessed_step = current_step;
        return &slots_[slot_idx];
    }

    // 1. Look for an unused slot
    for (auto& slot : slots_) {
        if (!slot.is_valid) {
            slot.key = new_key;
            slot.last_accessed_step = current_step;
            slot.is_valid = true;
            slot.pin_count = 0;
            index_map_[new_key] = slot.slot_id;
            return &slot;
        }
    }

    // 2. No empty slot: find LRU unpinned slot
    int32_t victim_idx = -1;
    uint64_t oldest_step = UINT64_MAX;

    for (size_t i = 0; i < slots_.size(); ++i) {
        if (slots_[i].pin_count == 0) {
            if (slots_[i].last_accessed_step < oldest_step) {
                oldest_step = slots_[i].last_accessed_step;
                victim_idx = static_cast<int32_t>(i);
            }
        }
    }

    if (victim_idx < 0) {
        // All slots are pinned! Fallback to emergency unpin on oldest
        std::cerr << "[SmolMax ExpertCache] WARNING: All slots pinned! Forcing eviction of slot 0." << std::endl;
        victim_idx = 0;
    }

    // Evict victim
    ExpertSlot& victim = slots_[victim_idx];
    index_map_.erase(victim.key);
    metrics_.evictions.fetch_add(1, std::memory_order_relaxed);

    // Repurpose slot
    victim.key = new_key;
    victim.last_accessed_step = current_step;
    victim.pin_count = 0;
    victim.is_valid = true;
    index_map_[new_key] = victim_idx;

    return &victim;
}

void ExpertCache::pin_expert(ExpertSlot* slot) {
    if (slot) {
        slot->pin_count++;
    }
}

void ExpertCache::unpin_expert(ExpertSlot* slot) {
    if (slot && slot->pin_count > 0) {
        slot->pin_count--;
    }
}

bool ExpertCache::is_cached(int32_t layer_id, int32_t expert_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    return index_map_.find({layer_id, expert_id}) != index_map_.end();
}

void ExpertCache::clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    index_map_.clear();
    for (auto& slot : slots_) {
        slot.is_valid = false;
        slot.key = {-1, -1};
        slot.pin_count = 0;
        slot.last_accessed_step = 0;
    }
}

size_t ExpertCache::get_active_count() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return index_map_.size();
}

} // namespace smolmax
