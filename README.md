# ⚡️ nvzkit – NVIDIA Container Toolkit for Zig

![Built with Zig](https://img.shields.io/badge/Built%20with-Zig-f7a41d?logo=zig\&logoColor=black)
![NVIDIA](https://img.shields.io/badge/NVIDIA-GPU-green?logo=nvidia\&logoColor=white)
![Zig Version](https://img.shields.io/badge/Zig-v0.15.0-orange?logo=zig)

> **nvzkit** is a high-performance, next-gen NVIDIA container toolkit built with Zig.<br>
> Designed for seamless GPU passthrough, runtime detection, and lightning-fast management of GPU-accelerated containers.

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

## 🛠️ Planned Commands

* `nvzkit info` – Show all detected GPUs, driver/version info, health
* `nvzkit run` – Launch container with GPU passthrough
* `nvzkit shell` – Drop into a container shell with GPU context
* `nvzkit mount` – Mount NVIDIA driver files/bind mounts
* `nvzkit debug` – Print detailed logs for troubleshooting

---

## 🤝 Compatibility

* **NVIDIA Drivers**: 515+ (Open & Proprietary)
* **Container Engines**: Docker, Podman, Zig-native
* **OS**: Linux (x86\_64, aarch64)
* **Zig**: v0.15 or newer

---

## 💡 Why Zig?

* Ultra-low overhead, **native perf**
* Easy static binaries, tiny footprint
* Safer FFI for future toolkit plugins

---

## 📢 Roadmap

* [ ] Container runtime auto-detect
* [ ] GPU isolation/sandboxing helpers
* [ ] Better diagnostics & healthcheck UX
* [ ] Full podman/docker drop-in support

---

## 🧙‍♂️ About

nvzkit is an independent project, not affiliated with NVIDIA.
Built for hackers, homelabbers, and power users who want to push their GPU infrastructure further—with Zig.

---

