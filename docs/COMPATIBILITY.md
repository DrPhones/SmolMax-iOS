# SmolMax iOS — Model & Hardware Compatibility Matrix

This document provides the definitive compatibility specification for Large Language Models running on **SmolMax iOS** on **iPhone 13 Pro (6GB RAM / Apple A15 Bionic)**.

---

## 1. Supported Model Architectures

| Architecture | GGUF Arch Key | Supported in SmolMax | Native MoE Paging Support | Notes |
|---|---|---|---|---|
| LLaMA 2 / 3 / 3.1 / 3.2 | `llama` |  YES | N/A (Dense) | Up to 3B recommended |
| Qwen 2 / 2.5 | `qwen2` |  YES | N/A (Dense) | 0.5B, 1.5B, 3B supported |
| Qwen 2 MoE / Qwen3 MoE | `qwen2moe` |  YES |  YES | Supported via ExpertPager |
| Ling-mini (Ant Group) | `qwen2moe` / `llama` |  YES |  YES | Flagship 16B target (Stage C) |
| Mistral / Mixtral | `mistral` |  YES |  YES | Mixtral 8x7B requires Stage D |
| Gemma / Gemma 2 | `gemma` / `gemma2` |  YES | N/A (Dense) | Gemma-2-2B supported |
| Phi 2 / 3 / 3.5 | `phi2` / `phi3` |  YES | N/A (Dense) | Phi-3.5-mini supported |
| DeepSeek V2 / V3 Lite | `deepseek2` |  Experimental |  YES | High expert count |

---

## 2. Quantization Format Support

| Quantization Type | Bits/Weight | Engine Support | Recommended Use |
|---|---|---|---|
| **Q4_K_M** | 4.5 |  Full Support (Primary) | **Recommended default for all models** (optimal quality/RAM balance) |
| **Q4_0** | 4.5 |  Full Support | Fast NEON SIMD dequantization |
| **Q5_K_M** | 5.5 |  Full Support | Small models (0.5B – 1.5B) where RAM permits |
| **Q8_0** | 8.0 |  Full Support | Small embeddings or router weights |
| **Q3_K_M** | 3.5 |  Full Support | 35B MoE experimental staging |
| **Q2_K** | 2.5 |  Supported | High-compression MoE expert layers |
| **IQ4_XS** | 4.25 |  Supported | Importance-matrix quantized models |
| **IQ3_XXS** | 3.06 |  Supported | Extreme compression |
| **Q1_0 / Ternary** | 1.0 – 1.6 |  Conditional | Supported only when compatible repacked kernels are present |

---

## 3. Comprehensive Model Staging Roadmap

### Stage A — Baseline Small Dense Models (Production Ready)
- **Goal**: Guaranteed offline inference stability on iPhone 13 Pro.
- **Models**:
  - `Qwen2.5-0.5B-Instruct` (Q4_K_M, ~398 MB) — 100% stable, ~45 tok/s.
  - `Llama-3.2-1B-Instruct` (Q4_K_M, ~820 MB) — 100% stable, ~28 tok/s.
  - `SmolLM2-1.7B-Instruct` (Q4_K_M, ~1.1 GB) — 100% stable, ~20 tok/s.
  - `Llama-3.2-3B-Instruct` (Q4_K_M, ~2.0 GB) — Safe Mode recommended.

---

### Stage B — Medium Dense Models (7B – 8B)
- **Analysis**:
  - A dense 7B/8B model in Q4_K_M requires **~4.5 GB to 5.2 GB** of RAM.
  - iPhone 13 Pro physical RAM is 6 GB; iOS limits user apps to ~3.5 GB.
  - **Verdict**: Dense 7B/8B models cannot run fully in RAM without risking Jetsam memory kills. Users attempting to load them receive a clear warning in the app UI.

---

### Stage C — Smolmaxxing Flagship 16B MoE (`Ling-mini-2.0`)
- **Model**: `inclusionAI/Ling-mini-2.0` (16B total parameters, 1.4B active per token).
- **File Size**: ~8.4 GB (GGUF Q4_K_M).
- **Execution Mechanism**:
  - Non-expert tensors (~1.2 GB) mapped into RAM.
  - Expert pool (6 slots in RAM, ~96 MB).
  - Storage-backed paging via POSIX `pread()` on NVMe flash.
- **Total Working Set RAM**: **~1.85 GB** (Safely within the 3.5 GB iOS budget!).
- **Status**: Core target of this implementation.

---

### Stage D — Experimental 35B MoE (`Qwen3.6-35B-A3B`)
- **Model**: `Qwen3.6-35B-A3B-phone-GGUF` (~12.3 GB file size, ~3B active per token).
- **Execution Mechanism**:
  - Expert Paging with 4-slot pool.
  - Context window clamped to 1024 or 2048 in Safe Mode.
- **Feasibility**: High potential; requires sustained ~1 GB/s NVMe read bandwidth.
- **Status**: Enabled in Experimental Mode with memory safety warnings.

---

### Stage E — Research 80B MoE (`Qwen3-Next-80B-A3B`)
- **Model**: `Qwen3-Next-80B-A3B-phone-GGUF` (~27.6 GB file size).
- **Status**: Research feasibility exploration.
- **Key Caveat**: Qwen3-Next features variable activated experts per token, requiring dynamic multi-slot allocation. Only to be enabled after physical validation of Stage C and Stage D.
