# SmolMax iOS

**Run Large Language Models locally on your iPhone — no internet required.**

SmolMax iOS is a native iOS application that enables fully offline LLM inference on iPhone, leveraging Expert Paging technology from the [smolmaxxing](https://github.com/hyperionaidev/smolmaxxing) project to run models that exceed the device's physical RAM.

## Features

- 🧠 **Local Inference** — Run LLMs directly on-device using llama.cpp
- 📱 **Native iOS** — Pure SwiftUI interface with Arabic RTL support
- 🔄 **Expert Paging** — Run MoE models larger than RAM via storage-backed expert loading
- 📦 **GGUF Import** — Import models from Files app or download from trusted sources
- 📊 **Performance Dashboard** — Real-time tokens/sec, memory, cache metrics
- 🔒 **Privacy First** — No internet during inference, no analytics, no trackers
- 🌙 **Dark Mode** — Full light/dark theme support

## Target Device

| Property | Specification |
|----------|--------------|
| Device | iPhone 13 Pro |
| Processor | Apple A15 Bionic |
| RAM | 6GB |
| Architecture | arm64 |
| iOS | 17.0+ |

## Model Support Tiers

| Stage | Models | Status |
|-------|--------|--------|
| A — Baseline | 0.5B–4B GGUF Q4 | Primary target |
| B — Medium | 7B–8B quantized | With memory checks |
| C — Smolmaxxing | Ling-mini-2.0 16B MoE | Expert Paging required |
| D — Experimental | Qwen3.6-35B-A3B | Requires validation |
| E — Research | Qwen3-Next-80B-A3B | Feasibility study |

## Building

### Prerequisites
- macOS with Xcode 15+
- iOS 17.0+ SDK
- CMake 3.21+

### Local Build
```bash
cd SmolMax-iOS
open SmolMax-iOS.xcodeproj
# Select iPhone target, build (Cmd+B)
```

### CI Build (GitHub Actions)
```bash
git push  # Triggers .github/workflows/build-ios.yml
# Download IPA from Actions artifacts
```

## Installation

See [INSTALL_AR.md](docs/INSTALL_AR.md) for Arabic installation guide with signing instructions.

1. Build or download the unsigned IPA
2. Sign using your external signing service
3. Install on device
4. Import GGUF models from Files app

## Architecture

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed engine architecture.

```
SmolMax-iOS/
├── App/           — Entry point & configuration
├── Presentation/  — SwiftUI views (Chat, Models, Performance, Settings)
├── Domain/        — Entities, use cases, protocols
├── Data/          — Model repository, downloader, persistence
├── Inference/     — llama.cpp bridge, expert pager, memory manager
├── ThirdParty/    — llama.cpp, ggml
├── Tests/         — Unit & integration tests
└── Scripts/       — Build helpers
```

## License

This project uses code from:
- [llama.cpp](https://github.com/ggml-org/llama.cpp) — MIT License
- [smolmaxxing](https://github.com/hyperionaidev/smolmaxxing) — Check repository license

See [THIRD_PARTY_LICENSES.md](docs/THIRD_PARTY_LICENSES.md) for full details.

## Credits

- [Hyperion AI](https://github.com/hyperionaidev) — smolmaxxing Expert Paging concept
- [ggml-org](https://github.com/ggml-org) — llama.cpp inference engine
