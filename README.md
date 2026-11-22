# Waydroid on Linux — X11-friendly Android, headless emulator, and ADB automation

Run Android apps on Linux **without** a heavy emulator, even if you log into
**X11** (no Wayland session). Includes a **headless emulator** you can drive
from an AI agent or CI with ADB (install, launch, screenshots, taps).

Built and battle-tested on **Linux Mint 22.3** with an **Intel i5-4300U (2
cores)**, 11 GB RAM, and a 5400 rpm HDD — hardware where the Android Studio
emulator is painful. Waydroid (LXC + binder) runs Android directly on the host
kernel, so it's dramatically lighter than a full VM.

---

## Why this exists

Android Studio's emulator = a full Android VM. On modest hardware (dual-core
CPU, HDD, limited RAM) it thrashes swap and takes forever to boot.

**Waydroid** runs Android in an LXC container using the host kernel + `binder`.
No CPU virtualization overhead. The catch: Waydroid is a **Wayland** app, and
most desktops (Cinnamon, Xfce, MATE on X11) don't run a Wayland compositor.
These scripts fix that by running a **nested Wayland compositor (weston) on X11**.

---

## Features

- **`waydroid-ui`** — launches Android in a window on your X11 desktop.
  - Starts/reuses a nested weston compositor.
  - Boots the Waydroid session and waits until Android is *actually* ready.
  - Auto-restarts a headless session so the UI becomes visible.
  - Cleans everything up when you close the window.
- **`waydroid-emu`** — headless Android + ADB for automation/agents.
  - Boots Android with **no window** (headless weston).
  - Exposes ADB over the network (`adb connect <ip>:5555`).
  - Install, launch, screenshot, tap, swipe, type, key events, logcat.
  - **Keep-warm**: a warm start is <1s (vs ~60s cold).
- **`waydroid-tune`** — optional CPU governor tweak for faster cold boot.

---

## Requirements

- **Waydroid** installed and initialized (`waydroid init`).
- **weston** (Wayland compositor) — `sudo apt install weston`
- **adb** (platform-tools) — `sudo apt install adb`
- **binder kernel module** — `sudo modprobe binder_linux` (usually auto-loaded by Waydroid's service)
- `waydroid-container` service enabled — `sudo systemctl enable --now waydroid-container`
- A Wayland-capable GPU (Intel/AMD/NVIDIA with Mesa) for best performance.

Check everything with:

```bash
./install.sh --check
```

---

## Install

```bash
git clone <this-repo>
cd waydroid-linux/waydroid-linux
./install.sh
```

This copies the scripts to `~/.local/bin` and installs a **Waydroid** desktop
entry. Then:

- **Menu:** open **Waydroid** from your app menu.
- **Terminal:** `waydroid-ui` (windowed) or `waydroid-emu start` (headless).

---

## Usage

### Windowed (normal app use)
```bash
waydroid-ui
```
Or click **Waydroid** in your app menu. First boot ~60s; once it's up,
re-launching is instant.

### Headless emulator (for agents / CI)
```bash
waydroid-emu start          # boot headless + connect adb
waydroid-emu status         # session + adb state
waydroid-emu install app.apk
waydroid-emu launch com.example.app
waydroid-emu shot out.png   # screenshot (720x1248 PNG)
waydroid-emu tap 360 640
waydroid-emu text "hello"
waydroid-emu key KEYCODE_BACK
waydroid-emu logcat 300
waydroid-emu shell "getprop ro.product.model"
waydroid-emu stop
```

While it's running, plain ADB works too:
```bash
adb connect $(waydroid-emu ip)
adb -s 192.168.240.112:5555 exec-out screencap -p > shot.png
```

### Optional: faster cold boot
```bash
sudo waydroid-tune performance   # pin CPU governor
sudo waydroid-tune schedutil     # restore default
```

---

## How it works (the technical bits)

1. **Wayland on X11.** Waydroid needs a Wayland display. `waydroid-ui` starts
   `weston --backend=x11-backend.so` and points `WAYLAND_DISPLAY` at it, so
   Android renders into a window on your X11 desktop.
2. **Binder.** Waydroid's root service loads `binder_linux` with
   `devices="anbox-binder,..."`, mounts binderfs, and symlinks the nodes.
3. **Readiness.** `waydroid status` flips to RUNNING as soon as the LXC
   container starts — long before Android is usable. The scripts poll the
   session log for `Android with user 0 is ready` instead.
4. **No freeze.** With no UI activity Android suspends and Waydroid freezes the
   container, hanging ADB. The emulator keeps the screen on
   (`svc power stayon true`) and calls the D-Bus `Unfreeze` method defensively.
5. **ADB.** The container gets `192.168.240.112` via the `waydroid0` NAT bridge;
   ADB connects to `<ip>:5555`.
6. **Networking.** All container traffic is NAT'd through the host
   (`waydroid-net.sh` + dnsmasq), so Android uses your PC's internet.

---

## Known limitations

- **Camera / video capture** does not work on many setups: SurfaceFlinger
  crashes importing the camera's YV12 buffer
  (`RenderEngine: Failed to create a valid texture ... format:YV12`). This is a
  Waydroid `minigbm` gralloc limitation. Workarounds: use an image with a
  different gralloc, or try `debug.renderengine.renderengine=gl`.
- **Cold boot** is ~60s on HDD + dual-core CPUs (disk I/O bound). Keep it warm
  for instant restarts.
- **No Google Play** (VANILLA image) — install APKs via ADB or an app store.
- **No GPS / real sensors / Bluetooth** — no host hardware.

---

## Credits

- [Waydroid](https://waydro.id/) — Android in a container.
- [weston](https://wayland.freedesktop.org/) — Wayland compositor.
- The scripts in `bin/` are original work by [@emerald](https://github.com/emerald).

## License

MIT — see [LICENSE](LICENSE).