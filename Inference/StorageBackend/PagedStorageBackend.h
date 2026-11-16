#ifndef SMOLMAX_PAGED_STORAGE_BACKEND_H
#define SMOLMAX_PAGED_STORAGE_BACKEND_H

#include <string>
#include <vector>
#include <memory>
#include <mutex>
#include <future>
#include <queue>
#include <chrono>
#include <atomic>
#include <cstdint>

namespace smolmax {

/// Statistics on storage I/O
struct StorageMetrics {
    std::atomic<uint64_t> total_reads{0};
    std::atomic<uint64_t> total_bytes_read{0};
    std::atomic<double> total_read_time_ms{0.0};
    
    double get_average_bandwidth_mb_s() const {
        double time_sec = total_read_time_ms.load() / 1000.0;
        if (time_sec <= 0.0) return 0.0;
        return (total_bytes_read.load() / (1024.0 * 1024.0)) / time_sec;
    }
    
    void reset() {
        total_reads = 0;
        total_bytes_read = 0;
        total_read_time_ms = 0.0;
    }
};

/// High-performance POSIX file-descriptor storage backend optimized for iOS APFS flash storage.
/// Uses pread() to load arbitrary byte ranges without polluting memory mapping tables.
class PagedStorageBackend {
public:
    PagedStorageBackend();
    ~PagedStorageBackend();

    // Disable copy
    PagedStorageBackend(const PagedStorageBackend&) = delete;
    PagedStorageBackend& operator=(const PagedStorageBackend&) = delete;

    /// Open GGUF file for reading with F_NOCACHE hint if supported
    bool open_file(const std::string& filepath);

    /// Close the opened file
    void close_file();

    /// Check if file is currently open
    bool is_open() const;

    /// Synchronously read bytes from an exact file offset into buffer using pread()
    bool read_exact(uint64_t offset, size_t size, void* destination_buffer);

    /// Queue asynchronous prefetch of an offset range into destination
    std::future<bool> prefetch_async(uint64_t offset, size_t size, void* destination_buffer);

    /// Get current storage throughput and I/O metrics
    const StorageMetrics& get_metrics() const { return metrics_; }

    /// File size in bytes
    uint64_t get_file_size() const { return file_size_; }

private:
    int file_descriptor_;
    uint64_t file_size_;
    std::string filepath_;
    mutable std::mutex read_mutex_;
    StorageMetrics metrics_;
};

} // namespace smolmax

#endif // SMOLMAX_PAGED_STORAGE_BACKEND_H
