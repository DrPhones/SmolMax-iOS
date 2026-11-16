#include "PagedStorageBackend.h"

#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <iostream>
#include <cerrno>
#include <cstring>

namespace smolmax {

PagedStorageBackend::PagedStorageBackend()
    : file_descriptor_(-1), file_size_(0) {}

PagedStorageBackend::~PagedStorageBackend() {
    close_file();
}

bool PagedStorageBackend::open_file(const std::string& filepath) {
    std::lock_guard<std::mutex> lock(read_mutex_);
    
    if (file_descriptor_ >= 0) {
        close(file_descriptor_);
        file_descriptor_ = -1;
    }

    filepath_ = filepath;
    
    // Open read-only in binary mode
    file_descriptor_ = ::open(filepath.c_str(), O_RDONLY);
    if (file_descriptor_ < 0) {
        std::cerr << "[SmolMax PagedStorage] Failed to open file: " << filepath 
                  << " Error: " << strerror(errno) << std::endl;
        return false;
    }

    // On iOS APFS, we can hint F_NOCACHE to avoid filling system unified page cache
    // with bulky weights that we manage explicitly in our expert pool
#ifdef F_NOCACHE
    fcntl(file_descriptor_, F_NOCACHE, 1);
#endif

    // Query file size via fstat
    struct stat st;
    if (fstat(file_descriptor_, &st) == 0) {
        file_size_ = static_cast<uint64_t>(st.st_size);
    } else {
        file_size_ = 0;
    }

    metrics_.reset();
    return true;
}

void PagedStorageBackend::close_file() {
    std::lock_guard<std::mutex> lock(read_mutex_);
    if (file_descriptor_ >= 0) {
        ::close(file_descriptor_);
        file_descriptor_ = -1;
    }
    file_size_ = 0;
    filepath_.clear();
}

bool PagedStorageBackend::is_open() const {
    return file_descriptor_ >= 0;
}

bool PagedStorageBackend::read_exact(uint64_t offset, size_t size, void* destination_buffer) {
    if (file_descriptor_ < 0 || !destination_buffer || size == 0) {
        return false;
    }

    if (offset + size > file_size_) {
        std::cerr << "[SmolMax PagedStorage] Read bounds exceeded! Offset: " 
                  << offset << " Size: " << size << " FileSize: " << file_size_ << std::endl;
        return false;
    }

    auto start_time = std::chrono::high_resolution_clock::now();

    size_t bytes_remaining = size;
    uint8_t* target = reinterpret_cast<uint8_t*>(destination_buffer);
    uint64_t current_offset = offset;

    while (bytes_remaining > 0) {
        ssize_t bytes_read = ::pread(file_descriptor_, target, bytes_remaining, current_offset);
        if (bytes_read < 0) {
            if (errno == EINTR) continue; // Interrupted by signal, retry
            std::cerr << "[SmolMax PagedStorage] pread failed: " << strerror(errno) << std::endl;
            return false;
        }
        if (bytes_read == 0) {
            // Unexpected EOF
            return false;
        }

        bytes_remaining -= bytes_read;
        target += bytes_read;
        current_offset += bytes_read;
    }

    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli> duration = end_time - start_time;

    metrics_.total_reads.fetch_add(1, std::memory_order_relaxed);
    metrics_.total_bytes_read.fetch_add(size, std::memory_order_relaxed);
    
    // Accumulate time in milliseconds
    double prev = metrics_.total_read_time_ms.load(std::memory_order_relaxed);
    while (!metrics_.total_read_time_ms.compare_exchange_weak(prev, prev + duration.count(), std::memory_order_relaxed)) {}

    return true;
}

std::future<bool> PagedStorageBackend::prefetch_async(uint64_t offset, size_t size, void* destination_buffer) {
    return std::async(std::launch::async, [this, offset, size, destination_buffer]() {
        return this->read_exact(offset, size, destination_buffer);
    });
}

} // namespace smolmax
