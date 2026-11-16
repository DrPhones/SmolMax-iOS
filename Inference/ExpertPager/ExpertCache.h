#ifndef SMOLMAX_EXPERT_CACHE_H
#define SMOLMAX_EXPERT_CACHE_H

#include <vector>
#include <unordered_map>
#include <memory>
#include <mutex>
#include <atomic>
#include <cstdint>
#include <cstddef>

namespace smolmax {

/// Key uniquely identifying an expert across transformer layers
struct ExpertKey {
    int32_t layer_id;
    int32_t expert_id;

    bool operator==(const ExpertKey& other) const {
        return layer_id == other.layer_id && expert_id == other.expert_id;
    }
};

struct ExpertKeyHash {
    std::size_t operator()(const ExpertKey& key) const {
        return (std::hash<int32_t>()(key.layer_id) ^ (std::hash<int32_t>()(key.expert_id) << 1));
    }
};

/// A single RAM memory slot hosting one expert's weights
struct ExpertSlot {
    int32_t slot_id;
    ExpertKey key{-1, -1};
    void* memory_buffer{nullptr};
    size_t capacity_bytes{0};
    uint64_t last_accessed_step{0};
    int32_t pin_count{0}; // >0 means currently in active evaluation, do not evict
    bool is_valid{false};
};

/// Metrics for expert cache operations
struct ExpertCacheMetrics {
    std::atomic<uint64_t> hits{0};
    std::atomic<uint64_t> misses{0};
    std::atomic<uint64_t> evictions{0};

    double get_hit_rate() const {
        uint64_t h = hits.load();
        uint64_t m = misses.load();
        uint64_t total = h + m;
        return total == 0 ? 0.0 : (static_cast<double>(h) / total) * 100.0;
    }

    void reset() {
        hits = 0;
        misses = 0;
        evictions = 0;
    }
};

/// High-performance Least-Recently-Used (LRU) Expert Cache with bounded memory footprint
class ExpertCache {
public:
    ExpertCache();
    ~ExpertCache();

    // Disable copy
    ExpertCache(const ExpertCache&) = delete;
    ExpertCache& operator=(const ExpertCache&) = delete;

    /// Initialize cache with a fixed number of slots and slot buffer size
    bool initialize(size_t pool_size, size_t max_expert_size_bytes);

    /// Release all slot allocations
    void teardown();

    /// Find an expert in cache. Returns slot pointer if hit, nullptr if miss.
    ExpertSlot* lookup(int32_t layer_id, int32_t expert_id, uint64_t current_step);

    /// Allocate or evict an LRU unpinned slot to receive a new expert
    ExpertSlot* acquire_slot_for_loading(int32_t layer_id, int32_t expert_id, uint64_t current_step);

    /// Pin an expert so it cannot be evicted during calculation
    void pin_expert(ExpertSlot* slot);

    /// Unpin an expert after calculation completes
    void unpin_expert(ExpertSlot* slot);

    /// Check if expert is resident in cache
    bool is_cached(int32_t layer_id, int32_t expert_id) const;

    /// Evict all entries
    void clear();

    /// Get current cache size and metrics
    size_t get_pool_size() const { return slots_.size(); }
    size_t get_active_count() const;
    const ExpertCacheMetrics& get_metrics() const { return metrics_; }

private:
    mutable std::mutex mutex_;
    std::vector<ExpertSlot> slots_;
    std::unordered_map<ExpertKey, int32_t, ExpertKeyHash> index_map_;
    size_t max_expert_size_bytes_{0};
    ExpertCacheMetrics metrics_;
};

} // namespace smolmax

#endif // SMOLMAX_EXPERT_CACHE_H
