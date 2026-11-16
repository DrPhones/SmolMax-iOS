#ifndef SMOLMAX_EXPERT_PAGER_H
#define SMOLMAX_EXPERT_PAGER_H

#include "ExpertCache.h"
#include "MoERoutingPolicy.h"
#include "PagedStorageBackend.h"

#include <string>
#include <vector>
#include <unordered_map>
#include <memory>
#include <functional>

namespace smolmax {

struct ExpertTensorLocation {
    uint64_t offset_in_file;
    size_t size_bytes;
};

/// High-level Expert Paging coordinator orchestrating storage reads, caching, and execution
class ExpertPager {
public:
    ExpertPager();
    ~ExpertPager();

    /// Setup the pager for an MoE model
    bool setup(
        const std::string& gguf_filepath,
        int32_t num_layers,
        int32_t num_experts_per_layer,
        int32_t top_k,
        size_t expert_pool_size,
        size_t expert_tensor_size_bytes
    );

    /// Register tensor offset for a specific expert
    void register_expert_location(int32_t layer_id, int32_t expert_id, uint64_t offset, size_t size);

    /// Prepare (fetch or retrieve from cache) an expert for immediate computation
    ExpertSlot* prepare_expert(int32_t layer_id, int32_t expert_id, uint64_t step_counter);

    /// Done with computation, release pin
    void finish_expert(ExpertSlot* slot);

    /// Select and load all required experts for a token in a given layer
    std::vector<std::pair<RoutedExpert, ExpertSlot*>> route_and_prepare(
        int32_t layer_id,
        const float* router_logits,
        uint64_t step_counter
    );

    /// Set runtime configuration
    void set_routing_bias(float bias) { routing_bias_ = bias; }
    void set_prefetch_enabled(bool enabled) { prefetch_enabled_ = enabled; }
    void set_top_k(int32_t k) { top_k_ = k; }

    /// Query metrics
    double get_cache_hit_rate() const { return cache_.get_metrics().get_hit_rate(); }
    uint64_t get_cache_hits() const { return cache_.get_metrics().hits.load(); }
    uint64_t get_cache_misses() const { return cache_.get_metrics().misses.load(); }
    uint64_t get_storage_reads() const { return storage_.get_metrics().total_reads.load(); }
    double get_disk_throughput_mb_s() const { return storage_.get_metrics().get_average_bandwidth_mb_s(); }
    size_t get_active_expert_count() const { return cache_.get_active_count(); }

    /// Clear cache on memory warning
    void on_memory_pressure_warning();

private:
    PagedStorageBackend storage_;
    ExpertCache cache_;

    int32_t num_layers_{0};
    int32_t num_experts_per_layer_{0};
    int32_t top_k_{2};
    float routing_bias_{0.0f};
    bool prefetch_enabled_{true};

    // Location map: [layer_id, expert_id] -> file offset and size
    std::unordered_map<ExpertKey, ExpertTensorLocation, ExpertKeyHash> location_map_;
};

} // namespace smolmax

#endif // SMOLMAX_EXPERT_PAGER_H
