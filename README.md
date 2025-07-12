# ⚡️ nvzkit – NVIDIA Container Toolkit for Zig

![Built with Zig](https://img.shields.io/badge/Built%20with-Zig-f7a41d?logo=zig\&logoColor=black)
![NVIDIA](https://img.shields.io/badge/NVIDIA-GPU-green?logo=nvidia\&logoColor=white)
![Zig Version](https://img.shields.io/badge/Zig-v0.15.0-orange?logo=zig)

> **nvzkit** is a high-performance, next-gen NVIDIA container toolkit built with Zig.<br>
> Designed for seamless GPU passthrough, runtime detection, and lightning-fast management of GPU-accelerated containers.

**⚠️ v0.1.0 is an MVP release. Some features may be experimental. Please report bugs or contribute!**

---

## 🚀 Features

* **Blazing fast Zig core** – minimal overhead, zero GC
* **Full NVIDIA GPU detection** (vGPU and legacy)
* **Drop-in replacement for nvidia-docker** workflows
* **Optimized for cloud & bare metal**
* **Toolkit design** – run, shell, info, mount, debug & more
* **Simple config, single static binary**
* **Clean, modern CLI UX** (just like Zig itself)

---

## 🖥️ Quickstart

```sh
# Install Zig v0.15 or newer
# Build
zig build -Drelease-fast

# Run
sudo ./nvzkit info
sudo ./nvzkit run --gpu ...
```

---

## 🛠️ Current Commands (v0.1.0)

* ✅ `nvzkit info` – Show all detected GPUs, driver/version info, health
* ✅ `nvzkit run` – Launch container with GPU passthrough
* ✅ `nvzkit shell` – Drop into a container shell with GPU context
* ✅ `nvzkit help` – Show help and usage information

---

## 🚧 Planned Features

* [ ] `nvzkit mount` – Advanced NVIDIA driver files/bind mount management
* [ ] `nvzkit debug` – Detailed logs and troubleshooting diagnostics
* [ ] CDI (Container Device Interface) mode support
* [ ] CSV mode compatibility
* [ ] TOML configuration file support
* [ ] Container runtime auto-detection improvements
* [ ] GPU isolation/sandboxing helpers
* [ ] Better error handling and user feedback
* [ ] Comprehensive test suite
* [ ] Performance benchmarking vs nvidia-container-toolkit

---

## ⚠️ Known Issues

* **CSV and CDI modes**: Not yet implemented (legacy mode works)
* **Container runtime detection**: Basic implementation, may need manual specification
* **Error handling**: Some edge cases may not be gracefully handled
* **Testing**: Limited test coverage on different GPU configurations
* **Configuration**: TOML parsing not yet implemented
* **Documentation**: Some features need better documentation

---

## 🤝 Compatibility

* **NVIDIA Drivers**: 515+ (Open & Proprietary)
* **Container Engines**: Docker, Podman (basic support)
* **OS**: Linux (x86\_64, aarch64)
* **Zig**: v0.15 or newer

---

## 💡 Why Zig?

* Ultra-low overhead, **native perf**
* Easy static binaries, tiny footprint
* Safer FFI for future toolkit plugins

---

## 🧙‍♂️ About

nvzkit is an independent project, not affiliated with NVIDIA.
Built for hackers, homelabbers, and power users who want to push their GPU infrastructure further—with Zig.

This project implements functionality compatible with the [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-container-toolkit).
nvzkit is an independent clean-room reimplementation and does not include any original NVIDIA source code.

---

## 📄 License & Attribution

nvzkit is licensed under the MIT License. See the [NOTICE](NOTICE) file for 
attribution to the original NVIDIA Container Toolkit project and third-party dependencies.

---

