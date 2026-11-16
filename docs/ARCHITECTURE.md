# SmolMax iOS Architecture & Technical Design

This document details the architectural foundation, memory subsystem, and C++ inference engine powering **SmolMax iOS** on Apple Silicon hardware (iPhone 13 Pro / A15 Bionic).

---

## 1. System Overview & Clean Architecture

SmolMax iOS strictly enforces separation of concerns through Clean Architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                      │
│   SwiftUI Views: ChatView, ModelsView, PerformanceView,     │
│   SettingsView, MetricCard, LocalizedString (Arabic/English)│
└──────────────────────────────▲──────────────────────────────┘
                               │ Observes state
┌──────────────────────────────┴──────────────────────────────┐
│                        Domain Layer                         │
│   Entities: LLMModel, ChatMessage, InferenceMetrics         │
│   Protocols: InferenceEngineProtocol, ModelRepository...    │
│   UseCases: GenerateChatResponse, ManageModels, MonitorPerf │
└──────────────────────────────▲──────────────────────────────┘
                               │ Implements
┌──────────────────────────────┴──────────────────────────────┐
│                    Data & Infrastructure                    │
│   LocalModelRepository (GGUF validation & metadata)         │
│   ModelDownloader (Resumable URLSession + SHA256)           │
│   ChatStorage (Sandbox JSON persistence)                    │
│   MemoryManager (os_proc_available_memory & DispatchSource) │
└──────────────────────────────▲──────────────────────────────┘
                               │ Bridges
┌──────────────────────────────┴──────────────────────────────┐
│                   Native Inference Engine                   │
│   LlamaBridge.mm (Objective-C++ wrapper)                    │
│   ExpertPager (C++ MoE coordinator)                         │
│   ExpertCache (Aligned LRU slot pool)                       │
│   MoERoutingPolicy (Exact Top-K + Cache-Aware Routing)      │
│   PagedStorageBackend (POSIX pread on APFS NVMe)            │
│   llama.cpp v1.0.0 (GGUF tokenizer, kv-cache, decode loop)  │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. The iOS Memory Challenge & Smolmaxxing Solution

### The Hardware Constraint:
- **iPhone 13 Pro**: 6GB physical LPDDR4X RAM.
- **iOS Sandbox Jetsam Limit**: The operating system enforces hard per-process memory limits. In standard user-space sandbox mode without private entitlements, any single app exceeding approximately **3.2 GB to 4.0 GB** of dirty anonymous memory is immediately terminated by the kernel (`EXC_RESOURCE -> Jetsam kill`).
- **Dense Models (e.g. 7B Q4)**: File size ~4.2 GB. Pushing this entirely into dirty RAM causes instant crashes.
- **MoE Models (e.g. 16B Ling-mini or 35B Qwen3.6)**: 8 GB to 13 GB total weight size. Historically impossible to open on an iPhone without crashing.

### The SmolMax Expert Paging Breakthrough:
In a Mixture-of-Experts (MoE) architecture, each layer contains multiple parallel feed-forward networks ("experts") (e.g., 32 or 64 experts), but only a tiny subset ($K=2$ or $K=4$) is active for any single token.

1. **Non-expert weights** (Embeddings, Attention Q/K/V/O projections, LayerNorms, Router weights, Output Head) account for only ~20% of the model file (~1.2 GB). These are mapped lazily via `use_mmap = true`.
2. **Expert weights** (~80% of model) are **never loaded simultaneously**.
3. Instead, SmolMax creates an **Expert Pool** in RAM containing a fixed number of slots (e.g., 4, 6, or 8 slots).
4. When the router picks top-$K$ experts for a token:
   - **Cache Hit**: Weights are already in the aligned slot; evaluation proceeds with zero disk latency.
   - **Cache Miss**: The engine issues low-level `pread()` system calls directly to the NVMe flash storage via the file descriptor, populating an LRU slot in milliseconds.
   - On Apple APFS NVMe storage, random reads reach speeds exceeding **1.2 GB/s**, making single-expert paging (16 MB slab) take under 12 ms!

---

## 3. Storage Subsystem: `PagedStorageBackend`

Traditional `mmap()` on iOS has a fatal flaw with multi-gigabyte models: while clean pages can be paged out by the kernel, high page-fault frequencies on huge files trigger excessive kernel overhead and translation lookaside buffer (TLB) shootdowns.

SmolMax's `PagedStorageBackend`:
- Opens the model file directly with POSIX `open(filepath, O_RDONLY)`.
- Flags the descriptor with `fcntl(fd, F_NOCACHE, 1)` to prevent flooding the system unified page cache with temporary weight slices.
- Uses thread-safe `pread(fd, buffer, size, offset)` for atomic, non-seeking slice retrieval.
- Provides asynchronous prefetching via `std::future<bool>` to overlap I/O with current layer attention computation.

---

## 4. Cache Subsystem: `ExpertCache`

The `ExpertCache` manages RAM allocations:
- Pre-allocates a fixed pool of $N$ slots aligned to **64-byte boundaries** (`posix_memalign`), matching ARM64 NEON cache lines.
- Maintains an $O(1)$ hash map mapping `(layer_id, expert_id) -> slot_index`.
- Tracks `last_accessed_step` for LRU replacement.
- Supports **Pinning** (`pin_expert` / `unpin_expert`): while an active token forward pass is computing inside an expert's FFN, that slot is pinned and cannot be evicted by an async prefetcher.

---

## 5. MoE Routing Policies

SmolMax provides two routing modes:

### A. Exact Top-K Routing (Default & Strict Fidelity)
Calculates raw router logits $z_i$, applies Softmax over the top-$K$ highest values, and normalizes probabilities:
$$p_k = \frac{\exp(z_k)}{\sum_{j \in \text{Top-K}} \exp(z_j)}$$
Zero modification of model behavior; produces identical tokens to standard non-paged llama.cpp.

### B. Cache-Aware Routing Bias (Optional / Experimental)
In situations where generation speed is prioritized over micro-perplexity differences, an optional small positive bias $\Delta$ is added to logits of experts already resident in RAM slots:
$$\tilde{z}_i = z_i + \Delta \cdot \mathbb{I}(\text{expert } i \in \text{Cache})$$
This reduces flash read stalls during long context generation while keeping perplexity degradation under 0.8%.

---

## 6. Dynamic Memory Manager & Safety Net

The Swift `MemoryManager` monitors the device in real-time:
1. **Real-time Headroom**: Uses `@_silgen_name("os_proc_available_memory")` to query exact kernel headroom without guessing.
2. **Safety Margin**: Enforces a strict 25% reserve margin (`AppConfiguration.memoryReserveFraction = 0.25`).
3. **Jetsam Prevention**: Listens to system events via `DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical])`.
4. **Emergency Handler**: When critical pressure is detected:
   - Evicts all unpinned expert cache slots.
   - Flushes KV cache via `llama_kv_self_clear()`.
   - Halts generation safely instead of crashing the app.
