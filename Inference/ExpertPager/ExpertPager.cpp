#include "ExpertPager.h"
#include <iostream>

namespace smolmax {

ExpertPager::ExpertPager() {}

ExpertPager::~ExpertPager() {}

bool ExpertPager::setup(
    const std::string& gguf_filepath,
    int32_t num_layers,
    int32_t num_experts_per_layer,
    int32_t top_k,
    size_t expert_pool_size,
    size_t expert_tensor_size_bytes
) {
    num_layers_ = num_layers;
    num_experts_per_layer_ = num_experts_per_layer;
    top_k_ = top_k;

    if (!storage_.open_file(gguf_filepath)) {
        std::cerr << "[SmolMax ExpertPager] Failed to open storage file: " << gguf_filepath << std::endl;
        return false;
    }

    if (!cache_.initialize(expert_pool_size, expert_tensor_size_bytes)) {
        std::cerr << "[SmolMax ExpertPager] Failed to initialize expert cache with pool size " << expert_pool_size << std::endl;
        return false;
    }

    location_map_.clear();
    return true;
}

void ExpertPager::register_expert_location(int32_t layer_id, int32_t expert_id, uint64_t offset, size_t size) {
    location_map_[{layer_id, expert_id}] = {offset, size};
}

ExpertSlot* ExpertPager::prepare_expert(int32_t layer_id, int32_t expert_id, uint64_t step_counter) {
    // 1. Fast cache lookup
    ExpertSlot* slot = cache_.lookup(layer_id, expert_id, step_counter);
    if (slot != nullptr) {
        cache_.pin_expert(slot);
        return slot;
    }

    // 2. Cache miss: find file offset
    auto it = location_map_.find({layer_id, expert_id});
    if (it == location_map_.end()) {
        std::cerr << "[SmolMax ExpertPager] Unregistered expert location: Layer " << layer_id << " Expert " << expert_id << std::endl;
        return nullptr;
    }

    const auto& loc = it->second;

    // 3. Acquire slot for loading
    slot = cache_.acquire_slot_for_loading(layer_id, expert_id, step_counter);
    if (!slot) {
        std::cerr << "[SmolMax ExpertPager] Could not acquire cache slot!" << std::endl;
        return nullptr;
    }

    // 4. Read directly from flash storage via pread
    bool read_ok = storage_.read_exact(loc.offset_in_file, loc.size_bytes, slot->memory_buffer);
    if (!read_ok) {
        std::cerr << "[SmolMax ExpertPager] Failed to read expert weights from disk!" << std::endl;
        return nullptr;
    }

    cache_.pin_expert(slot);
    return slot;
}

void ExpertPager::finish_expert(ExpertSlot* slot) {
    cache_.unpin_expert(slot);
}

std::vector<std::pair<RoutedExpert, ExpertSlot*>> ExpertPager::route_and_prepare(
    int32_t layer_id,
    const float* router_logits,
    uint64_t step_counter
) {
    // Routing policy decides which experts are activated
    auto is_cached_lambda = [this, layer_id](int32_t exp_id) {
        return this->cache_.is_cached(layer_id, exp_id);
    };

    auto selected = MoERoutingPolicy::select_experts(
        router_logits,
        num_experts_per_layer_,
        top_k_,
        is_cached_lambda,
        routing_bias_
    );

    std::vector<std::pair<RoutedExpert, ExpertSlot*>> prepared;
    prepared.reserve(selected.size());

    for (const auto& expert : selected) {
        ExpertSlot* slot = prepare_expert(layer_id, expert.expert_id, step_counter);
        prepared.push_back({expert, slot});
    }

    return prepared;
}

void ExpertPager::on_memory_pressure_warning() {
    std::cout << "[SmolMax ExpertPager] Memory pressure warning received. Evicting inactive experts." << std::endl;
    cache_.clear();
}

} // namespace smolmax
