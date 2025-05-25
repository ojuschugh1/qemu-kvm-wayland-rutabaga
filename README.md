# wayland-gpu-test


---

# QEMU/KVM with virtio-gpu-rutabaga & Wayland Forwarding

This repository contains two Bash scripts:

1. **`part1.sh`** – Builds a custom QEMU from source with `virtio-gpu-rutabaga` (Rutabaga) support.
2. **`part2.sh`** – Sets up, configures, and launches a Fedora 41 VM that uses the newly built QEMU binary, enables Wayland-forwarded graphics via Rutabaga, and installs example Wayland applications (e.g. Foot, Gedit, Firefox) in the guest.

Together, they reproduce a feature similar to Chromium OS’s hardware-accelerated Wayland integration on a “standard” Linux distribution (Fedora 41). You can run them on a fresh Fedora 41 installation or a Fedora 41 Live USB session (as long as you have network access and the standard Fedora repos enabled).

---

## Table of Contents

1. [High-Level Overview](#high-level-overview)
2. [Prerequisites](#prerequisites)
3. [Script 1: `part1.sh` (Build QEMU with Rutabaga)](#script-1-part1sh-build-qemu-with-rutabaga)

   1. [What It Does](#what-it-does)
   2. [How It Works (Step by Step)](#how-it-works-step-by-step)
   3. [Usage](#usage-1)
4. [Script 2: `part2.sh` (VM Setup & Launcher)](#script-2-part2sh-vm-setup-launcher)

   1. [What It Does](#what-it-does-1)
   2. [How It Works (Step by Step)](#how-it-works-step-by-step-1)
   3. [Usage](#usage-2)
5. [Resulting Files & Directory Layout](#resulting-files-directory-layout)
6. [Troubleshooting](#troubleshooting)
7. [Customization & Advanced Topics](#customization-advanced-topics)

---

## High-Level Overview

* **Phase 1 (`part1.sh`):**

  1. Remove any existing QEMU packages or binaries from common system paths.
  2. Install build dependencies (C toolchain, libraries, Rust/Cargo, etc.).
  3. Clone the Chromium OS `crosvm` repository, build the `rutabaga_gfx` library from source (so that QEMU can use it).
  4. Clone QEMU from its official GitHub mirror, configure it with `--enable-rutabaga-gfx`, along with VirglRenderer, OpenGL, GTK, SDL, SPICE, and other virtualization features.
  5. Compile and install QEMU under `/usr/local`.
  6. Verify installation and print out an example QEMU command line using `virtio-gpu-rutabaga`.

* **Phase 2 (`part2.sh`):**

  1. Detect that you are on Fedora 41 (or at least warn if you are not).
  2. Install host-side packages required for virtualization (`qemu-kvm`, `libvirt`, `virt-manager`, plus development tools, Wayland libraries, Foot, Gedit, Firefox, etc.).
  3. Confirm that the newly installed (or system) QEMU binary actually has Rutabaga support.
  4. Create a VM workspace under `~/wayland-vm/` (by default).
  5. Download the Fedora 41 Workstation Live ISO (if not already present).
  6. Create a fresh qcow2 disk (20 GB by default).
  7. Generate several helper scripts inside `~/wayland-vm/`:

     * `guest-autostart.sh` – a script meant to run inside the guest on boot, which waits for Wayland and launches Foot, Gedit, Firefox.
     * `start-wayland-vm.sh` – the QEMU launcher that boots from ISO (on first run) or from disk thereafter, with a full `virtio-gpu-rutabaga` command line. It also mounts `~/wayland-vm/scripts/` into the guest via 9p.
     * `install-helper.sh` – instructions for how to copy `guest-autostart.sh` into the guest filesystem and register it as a systemd service so it actually executes on first real login.
     * `test-wayland.sh` – a simple host-side check that verifies QEMU’s Rutabaga support and host Wayland status.
     * `README.md` – (this file) full documentation of the entire process.

Once both scripts have run successfully, you will have:

* A custom QEMU binary with Rutabaga in `/usr/local/bin/qemu-system-x86_64`.
* A self-contained VM workspace in `~/wayland-vm/` that can:

  1. Launch a new Fedora 41 install (`start-wayland-vm.sh --install`).
  2. After installation, automatically enable `guest-autostart.sh` inside the VM so that example Wayland apps start at login.
  3. Boot normally from the installed disk, with hardware-accelerated graphics and Wayland forwarding.

---

## Prerequisites

1. **Host Operating System**

   * Fedora 41 Workstation (Live USB or a fresh install).
   * Internet access (to fetch packages via `dnf` and download the Fedora ISO).

2. **Free Disk Space & Memory**

   * ≥ 30 GB of free space in `$HOME` (for QEMU build artifacts and the VM disk).
   * ≥ 8 GB RAM free (we allocate 4 GB to the VM by default).

3. **User Privileges**

   * Your user must be in the `libvirt` (and/or `kvm`) group so that KVM acceleration can work.
   * The scripts will escalate with `sudo` where needed (for package installs, `make install`, `ldconfig`, etc.).

4. **Network Access**

   * For `part1.sh`: to `git clone` QEMU and `crosvm`, to `dnf install` packages.
   * For `part2.sh`: to `dnf install` virtualization/Wayland packages and to `curl` the Fedora ISO.

---

## Script 1: `part1.sh` (Build QEMU with Rutabaga)

### What It Does

* Completely removes any existing QEMU binaries or libraries from your system (via package manager and `/usr/local/bin`, `/usr/bin`, `/usr/local/share`, etc.).
* Installs all necessary build dependencies (C compiler, development libraries, Rust, Cargo, Python-sphinx, tools like Ninja).
* Clones and builds Chromium OS’s `rutabaga_gfx` library from source (to supply QEMU with the correct version).
* Clones the official QEMU repository at tag `stable-8.2`, configures it with support for:

  * KVM acceleration
  * virtio-gpu-rutabaga (Rutabaga)
  * virglrenderer & OpenGL
  * GTK, SDL, SPICE, VNC, curses, SLIRP networking, vhost, CAP-NG, and a variety of Linux AIO and block/device features
* Compiles QEMU (`make -j$(nproc)`) and installs it under `/usr/local` by default.
* Creates symlinks so that `/usr/local/bin/qemu` and `qemu-img` point to the newly built binaries.
* Verifies the installation by running `qemu-system-x86_64 --version` and checking for `virtio-gpu-rutabaga` in `qemu-system-x86_64 -device help`.

### How It Works (Step by Step)

1. **Initialize & Color Setup**

   * Sets `set -e` (exit on error).
   * Defines color codes for informational, warning, and error outputs.
   * Detects if running as root (`$EUID == 0`) or normal user; if non-root, uses `sudo` for privileged commands.

2. **Step 1: Remove Existing QEMU**

   * If `apt` is detected (Debian/Ubuntu), run `apt remove qemu*`; if `dnf` (Fedora), run `dnf remove qemu*`; if `pacman` (Arch), run `pacman -R qemu*`.
   * Deletes any leftover QEMU files from `/usr/local/bin`, `/usr/local/share/qemu`, `/usr/bin/qemu*`, `/usr/share/qemu`, etc.
   * Deletes the previous build directory (`$WORK_DIR`, default is `~/qemu-rutabaga-build`).

3. **Step 2: Install Build Dependencies**

   * Detects package manager again and installs a long list of development packages, including:

     * Base tools (`git`, `gcc`, `g++`, `make`, `ninja-build`)
     * Libraries for graphics: `libepoxy-devel`, `libdrm-devel`, `mesa-libgbm-devel`, `virglrenderer-devel`, etc.
     * Wayland support: `wayland-devel`, `wayland-protocols-devel`, `libxkbcommon-devel`, etc.
     * Window toolkits: `gtk3-devel`, `libsdl2-dev`, `libspice-server-dev`, etc.
     * Storage/net features: `libaio-devel`, `libcap-ng-devel`, `libcurl-devel`, etc.
     * Rust toolchain (`cargo`, `rustc`) and Python Sphinx for generating docs if needed.

4. **Step 3: Build `rutabaga_gfx` Library**

   * Creates `$WORK_DIR` (default `~/qemu-rutabaga-build`) and `cd` into it.
   * Clones `https://chromium.googlesource.com/chromiumos/platform/crosvm`.
   * Enters `crosvm/rutabaga_gfx` and runs:

     ```
     cargo build --release --no-default-features --features=gfxstream
     ```
   * If `librutabaga_gfx.so` or `.a` is not produced, tries alternative Cargo features (`virgl_renderer`, then fallback).
   * If successful, copies `librutabaga_gfx.so` and/or `.a` to `/usr/local/lib/`, and headers (`rutabaga_gfx.h`, `rutabaga_gfx_ffi.h`) to `/usr/local/include/rutabaga_gfx`.
   * Runs `sudo ldconfig` to update the library cache.
   * If all builds fail, sets `SKIP_RUTABAGA_LIB=1` so that QEMU’s own built-in Rutabaga fallback is used.

5. **Step 4: Clone & Build QEMU**

   * `git clone https://github.com/qemu/qemu.git` and `cd qemu && git checkout $QEMU_VERSION` (default `stable-8.2`).
   * Runs `./configure` with:

     ```
     --prefix=/usr/local
     --target-list=x86_64-softmmu,aarch64-softmmu
     --enable-kvm
     --enable-rutabaga-gfx
     --enable-virglrenderer
     --enable-opengl
     --enable-gtk
     --enable-sdl
     --enable-spice
     --enable-vnc
     --enable-curses
     --enable-linux-aio
     --enable-cap-ng
     --enable-attr
     --enable-vhost-net
     --enable-vhost-crypto
     --enable-vhost-kernel
     --enable-vhost-user
     --enable-vhost-vdpa
     --enable-slirp
     --audio-drv-list=pa,alsa
     --disable-werror
     ```
   * Runs `make -j$(nproc)` to compile.

6. **Step 5: Install QEMU**

   * Runs `sudo make install` (installing QEMU into `/usr/local/bin`, libraries in `/usr/local/lib`, share files, etc.).
   * Creates symlinks:

     ```
     sudo ln -sf /usr/local/bin/qemu-system-x86_64 /usr/local/bin/qemu
     sudo ln -sf /usr/local/bin/qemu-img /usr/local/bin/qemu-img
     ```
   * Runs `sudo ldconfig` again.

7. **Step 6: Verify Installation**

   * Checks that `/usr/local/bin/qemu-system-x86_64` exists.
   * Prints:

     * QEMU version (`qemu-system-x86_64 --version`).
     * Verifies `virtio-gpu-rutabaga` appears in `qemu-system-x86_64 -device help`.
     * Displays installation paths for the binary, `qemu-img`, and `librutabaga_gfx.so`.
   * Prints an example VM command line:

     ```bash
     qemu-system-x86_64 \
       -enable-kvm \
       -m 4G \
       -smp 4 \
       -display gtk,gl=on \
       -device virtio-gpu-rutabaga,hostmem=256M,cross-domain=on,wsi=surfaceless \
       -netdev user,id=net0 \
       -device virtio-net-pci,netdev=net0 \
       -drive file=your-disk.qcow2,format=qcow2,if=virtio \
       -boot order=c
     ```
   * Asks interactively if you want to remove the build directory (`~/qemu-rutabaga-build`).

### Usage

1. **Make the script executable**:

   ```bash
   chmod +x part1.sh
   ```

2. **Run it** (as your regular user with sudo privileges):

   ```bash
   ./part1.sh
   ```

   * If you’re not root, it will automatically prefix `sudo` where needed.
   * It may take several minutes, depending on your CPU/RAM, to build Rust libs and QEMU.

3. **Once complete**, confirm:

   ```bash
   /usr/local/bin/qemu-system-x86_64 --version
   qemu-system-x86_64 -device help | grep -i rutabaga
   ```

   You should see something like:

   ```
   QEMU emulator version 8.2.0 ...
   virtio-gpu-rutabaga-pci
   virtio-gpu-rutabaga
   ```

   This confirms QEMU has been successfully built with Rutabaga support.

---

## Script 2: `part2.sh` (VM Setup & Launcher)

### What It Does

* Detects you are on Fedora 41 (warns if you are not).
* Installs all host-side packages you need to run and build VMs with Wayland and Rutabaga (`qemu-kvm`, `virt-manager`, `libvirt`, plus development, graphics, and Wayland libraries).
* Checks that your system QEMU (or `/usr/local/bin/qemu-system-x86_64`) has Rutabaga support.
* Creates a directory structure under `~/wayland-vm/` for the new VM.
* Downloads the Fedora 41 Workstation Live ISO to `~/wayland-vm/iso/fedora-41-workstation.iso` (if missing).
* Creates a 20 GB qcow2 disk (`~/wayland-vm/wayland-test-vm.qcow2`).
* Generates helper scripts inside `~/wayland-vm/`:

  * **`scripts/guest-autostart.sh`** – to be injected or copied into the Fedora guest. When executed in the guest, it waits for a running Wayland socket and then launches Foot, Gedit, Firefox automatically.
  * **`start-wayland-vm.sh`** – launches QEMU with:

    * `-machine type=q35,accel=kvm -cpu host -m 4G -smp 4`
    * `-virtfs local,path=~/wayland-vm/scripts, …` to share `guest-autostart.sh` into the guest under `/mnt/hostscripts`.
    * `-device virtio-gpu-rutabaga-pci,hostmem=256M,cross-domain=on,wsi=surfaceless` for hardware-accelerated graphics.
    * A user-mode network with SSH forwarding from host port 2222 → guest port 22.
    * Audio, input (keyboard, mouse), USB tablet, and an interactive monitor.
    * Boots from ISO on `--install` or from disk otherwise.
  * **`install-helper.sh`** – host-side instructions that tell you how, once you’ve finished installing Fedora in the VM, to copy `guest-autostart.sh` into the guest’s filesystem (`/usr/local/bin/guest-autostart.sh`) and register a systemd unit (`wayland-autostart.service`) so that it runs at graphical boot.
  * **`test-wayland.sh`** – verifies on the host that QEMU has Rutabaga support and that your host is running Wayland.

### How It Works (Step by Step)

1. **Initialize & Color Setup**

   * `set -e` to exit on errors.
   * Defines color codes again for consistency (these are reused from `part1.sh`).

2. **Function: `check_fedora()`**

   * Reads `/etc/os-release` and verifies “Fedora”.
   * Warns if `VERSION_ID` is not exactly `"41"`.
   * If not Fedora at all, it prints an error and exits.

3. **Function: `install_packages()`**

   * Updates `dnf` repositories (`sudo dnf update -y --skip-unavailable`).
   * Installs virtualization packages:

     ```
     sudo dnf install -y qemu-kvm qemu-img libvirt libvirt-daemon-kvm virt-manager bridge-utils curl wget unzip rsync
     ```
   * Installs development toolchain (GCC, make, CMake, Git, Meson, Ninja).
   * Installs graphics & Wayland packages:

     ```
     sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers libdrm wayland-devel wayland-protocols-devel libxkbcommon weston foot gedit firefox gnome-terminal
     ```
   * Enables and starts `libvirtd` (`sudo systemctl enable --now libvirtd`).
   * Adds your user to the `libvirt` group (`sudo usermod -a -G libvirt $(whoami)`).

4. **Function: `check_qemu_rutabaga()`**

   * Tries to detect a QEMU binary at `/usr/local/bin/qemu-system-x86_64` (the one built by `part1.sh`).
   * Falls back to `/usr/bin/qemu-system-x86_64` if the custom one isn’t found.
   * If neither is found, errors out.
   * Runs `$QEMU_BIN -device help | grep -q "virtio-gpu-rutabaga"`.

     * If found, confirms “QEMU has rutabaga support”.
     * Otherwise, errors out, telling you to run `part1.sh` first.
   * Lists available Rutabaga devices (`qemu-system-x86_64 -device help | grep rutabaga`).

5. **Function: `setup_vm_directory()`**

   * Creates the following directories under `$HOME/wayland-vm` (default):

     ```
     ~/wayland-vm/
       ├── iso/
       ├── scripts/
       ├── shared/       ← (for host-guest sharing if needed)
       └── (VM disk and helper scripts in $HOME/wayland-vm/)
     ```
   * Prints the base path: `VM directory created at: ~/wayland-vm`.

6. **Function: `download_fedora_iso()`**

   * Checks if `~/wayland-vm/iso/fedora-41-workstation.iso` already exists. If not, runs:

     ```bash
     curl -L -o ~/wayland-vm/iso/fedora-41-workstation.iso.tmp $FEDORA_ISO_URL
     mv ~/wayland-vm/iso/fedora-41-workstation.iso.tmp ~/wayland-vm/iso/fedora-41-workstation.iso
     ```
   * Prints a confirmation once complete.

7. **Function: `create_vm_disk()`**

   * Checks if `~/wayland-vm/wayland-test-vm.qcow2` already exists.

     * If yes, asks interactively if you want to recreate it.
     * If no (or if you confirm recreation), runs:

       ```bash
       qemu-img create -f qcow2 ~/wayland-vm/wayland-test-vm.qcow2 20G
       ```

8. **Function: `create_guest_autostart()`**

   * Writes `~/wayland-vm/scripts/guest-autostart.sh` with content that:

     * Sleeps 5 s.
     * Exports `XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY`, `GDK_BACKEND`, `QT_QPA_PLATFORM`, `MOZ_ENABLE_WAYLAND`.
     * Waits (up to 30 s) for the Wayland socket to appear (`/run/user/$UID/wayland-0`).
     * Once found, launches (in background) `foot`, `gedit`, `firefox` (if each is installed).
     * Prints status messages to stdout.
   * Marks it executable (`chmod +x ...`).

9. **Function: `create_vm_launcher()`**

   * Writes `~/wayland-vm/start-wayland-vm.sh` as a self-contained QEMU launcher. Key points:

     * If you pass `--install` (or if the VM disk does not exist), sets `-cdrom $FEDORA_ISO -boot d` to boot from the Fedora Live ISO.
     * Checks for a Wayland socket on the host:

       ```bash
       if [[ -n "$WAYLAND_DISPLAY" ]] && [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
         WAYLAND_ARGS="-display gtk,gl=on"
       else
         WAYLAND_ARGS="-display gtk,gl=on"
         (warning about falling back to X11, though the command is the same)
       fi
       ```
     * Verifies `$QEMU_BIN` exists and has “virtio-gpu-rutabaga” support.
     * Finally, `exec "$QEMU_BIN" \` with:

       ```
       -name "$VM_NAME"
       -machine type=q35,accel=kvm
       -cpu host
       -m 4G -smp 4
       -enable-kvm
       $WAYLAND_ARGS
       -device virtio-gpu-rutabaga-pci,hostmem=256M,cross-domain=on,wsi=surfaceless
       -drive file="$VM_DISK",format=qcow2,if=virtio,cache=writeback
       $BOOT_FROM_ISO
       -netdev user,id=net0,hostfwd=tcp::2222-:22
       -device virtio-net-pci,netdev=net0
       -audiodev pa,id=audio0
       -device intel-hda -device hda-duplex,audiodev=audio0
       -device virtio-keyboard-pci -device virtio-mouse-pci
       -virtfs local,path="$VM_DIR/scripts",mount_tag=hostscripts,security_model=passthrough,id=hostscripts
       -rtc base=localtime -usb -device usb-tablet -monitor stdio
       ```
     * The key is `-virtfs local,path=...,mount_tag=hostscripts,security_model=passthrough,id=hostscripts`, which exposes `~/wayland-vm/scripts/` inside the guest at the mount point you choose (e.g. `/mnt/hostscripts`).

10. **Function: `create_install_helper()`**

    * Writes `~/wayland-vm/install-helper.sh`, which contains instructions to be run **inside the guest** once Fedora is installed:

      1. Copy `/mnt/hostscripts/guest-autostart.sh` → `/usr/local/bin/guest-autostart.sh`.
      2. Make it executable.
      3. Create a systemd unit (`/etc/systemd/system/wayland-autostart.service`) that runs it at graphical­-target time.
      4. Enable that service (`systemctl enable wayland-autostart.service`).
      5. Reboot the VM.
    * You must open a terminal in the guest (or SSH to port 2222) to run this helper.

11. **Function: `create_test_script()`**

    * Creates `~/wayland-vm/test-wayland.sh` for the host. It:

      * Checks if a QEMU process matching “wayland-test-vm” is running.
      * Checks if `/usr/local/bin/qemu-system-x86_64 -device help | grep rutabaga` succeeds.
      * Detects if `$WAYLAND_DISPLAY` and `$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY` exist on the host.
      * Prints a summary of what the VM should be doing.
    * Marks it executable.

12. **Function: `create_readme()`**

    * Generates `~/wayland-vm/README.md` as a shorter VM-focused README. (You can ignore it or keep it; we are replacing it with this top-level README.)

13. **`main()`**

    * Prints a header and runs, in order:

      1. `check_fedora`
      2. `install_packages`
      3. `check_qemu_rutabaga`
      4. `setup_vm_directory`
      5. `download_fedora_iso`
      6. `create_vm_disk`
      7. `create_guest_autostart`
      8. `create_vm_launcher`
      9. `create_install_helper`
      10. `create_test_script`
      11. `create_readme`
    * Prints “Setup Complete!” and reminds you how to proceed:

      1. `cd ~/wayland-vm`
      2. `./install-helper.sh`
      3. `./start-wayland-vm.sh --install` (first-time install)
      4. `./start-wayland-vm.sh` (normal boot)
      5. `./test-wayland.sh` (verify)
    * Optionally, it will immediately prompt “Start VM installation now? (y/N)”. If you press `y`, it runs `./start-wayland-vm.sh --install` automatically.

### Usage

1. **Make the script executable**:

   ```bash
   chmod +x part2.sh
   ```

2. **Run it** (as your regular user; it will prompt for sudo where necessary):

   ```bash
   ./part2.sh
   ```

3. **Follow the output**. Once it finishes, you will have a directory structure under `~/wayland-vm/` as described below. By default, the script will ask “Start VM installation now? (y/N):”. If you press `y`, the VM boots into the Fedora Live ISO automatically.

4. **Inside the VM (installation phase)**:

   * After Fedora’s installer finishes, reboot the guest.
   * Open a terminal or use SSH (`ssh -p 2222 user@localhost` — replace `user` with the username you created during Fedora install).
   * Run:

     ```bash
     sudo ./install-helper.sh
     ```

     This will:

     * Copy `guest-autostart.sh` from the 9p-mounted `~/wayland-vm/scripts/` into `/usr/local/bin/guest-autostart.sh` inside the guest.
     * Create and enable `wayland-autostart.service` so that, on next graphical boot, the script will start Foot, Gedit, and Firefox for you.

5. **Next guest reboot**:

   * The VM will now boot from the installed disk instead of the ISO.
   * On reaching the Fedora desktop (Wayland session), you should see Foot, Gedit, and Firefox launch automatically after a short delay.

6. **Subsequent boots**:

   ```bash
   cd ~/wayland-vm
   ./start-wayland-vm.sh
   ```

   – The script will detect that `wayland-test-vm.qcow2` exists, skip the ISO, and boot directly from disk with hardware-accelerated Rutabaga graphics.

7. **Testing from the host**:

   ```bash
   cd ~/wayland-vm
   ./test-wayland.sh
   ```

   – Verifies that:

   * The VM process (`wayland-test-vm`) is running.
   * QEMU has Rutabaga support.
   * The host is running a Wayland session.

---

## Resulting Files & Directory Layout

Once you’ve run both scripts (`part1.sh` and `part2.sh`), you will have:

```
├── part1.sh
├── part2.sh
└── wayland-vm/
    ├── iso/
    │   └── fedora-41-workstation.iso
    │
    ├── scripts/
    │   └── guest-autostart.sh
    │
    ├── shared/             # (Empty by default; for future host-guest sharing)
    │
    ├── wayland-test-vm.qcow2   # 20 GB qcow2 disk image
    │
    ├── start-wayland-vm.sh  # VM launcher
    ├── install-helper.sh    # Guest instructions to enable autostart
    ├── test-wayland.sh      # Host-side test script
    └── README.md            # (This file, to be replaced by your top-level README)
```

* **`part1.sh`** (lives in your working folder, e.g. `~/` or wherever you put it).
* **`part2.sh`** (lives alongside `part1.sh`).
* **`wayland-vm/`** is created by `part2.sh`. Inside it, all VM-related files appear as above.

Additionally, after `part1.sh` completes, you will have installed QEMU under `/usr/local/`.

* **Binaries:** `/usr/local/bin/qemu-system-x86_64`, `/usr/local/bin/qemu-img`, `/usr/local/bin/qemu` (symlink).
* **Libraries:** `/usr/local/lib/librutabaga_gfx.so`, plus other QEMU-related libs.
* **Headers (optional):** `/usr/local/include/rutabaga_gfx/*.h`.

---

## Troubleshooting

1. **`part1.sh` **fails during build****

   * **Rust/Cargo errors**: Make sure `rustc` and `cargo` are installed (`dnf install cargo rust`). If you have an incompatible Rust version, you may need to update or install via `rustup`.
   * **Missing dependencies**: Double-check that `dnf install …` never failed. Look for lines like `Error: Package xxx-yyy is unavailable`.
   * **Out of disk space**: Check `df -h $HOME`. Building QEMU + Rutabaga can use several gigabytes.

2. **After `part1.sh`, `qemu-system-x86_64 -device help` does not list `virtio-gpu-rutabaga`**

   * You might have `SKIP_RUTABAGA_LIB=1`, which falls back to QEMU’s built-in support.
   * Re-run `part1.sh` from scratch:

     ```bash
     ./part1.sh
     ```

     Watch carefully for any “Rutaga build failed” warnings.

3. **`part2.sh` **errors out with “This script is designed for Fedora 41”****

   * Make sure `/etc/os-release` contains `NAME="Fedora"` and `VERSION_ID="41"`.
   * If you are on Fedora 42 or RHEL/CentOS, you will see that warning—it will continue (with a “will try to work on version X”) but if it cannot find Fedora 41 repos, subsequent `dnf install` may fail.

4. **Guest autostart does not run inside the VM**

   * Confirm that, after Fedora’s installer, you ran `install-helper.sh` **inside the guest** (via a terminal or SSH).
   * Inside the guest, check:

     ```bash
     systemctl status wayland-autostart.service
     journalctl -u wayland-autostart.service
     ls -l /usr/local/bin/guest-autostart.sh
     ```
   * Ensure `/mnt/hostscripts/guest-autostart.sh` actually exists (the 9p mount must be active when the VM is running). If not, check `start-wayland-vm.sh` for the correct `-virtfs` line.

5. **Foot/Gedit/Firefox fail to launch inside guest**

   * Make sure you installed them via `install-helper.sh` or manually:

     ```bash
     sudo dnf install -y foot gedit firefox
     ```
   * Check that `/usr/local/bin/guest-autostart.sh` has execute permission (`chmod +x`).
   * Manually run `/usr/local/bin/guest-autostart.sh` inside the guest to see any errors.

6. **VM window shows a blank screen or black display**

   * On the host, verify you have a GPU driver loaded with KMS and that you are running Wayland (e.g. Fedora’s default Gnome Wayland).
   * Run on the host:

     ```bash
     echo $WAYLAND_DISPLAY
     ls -l $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY
     ```

     If those files don’t exist, confirm you are in a Wayland session (not X11).
   * In `start-wayland-vm.sh`, you can force X11 by removing `-display gtk,gl=on` and substituting `-display sdl,gl=on` or `-display cocoa,gl=on` (depending on platform).

7. **SSH to guest (port 2222) does not work**

   * Ensure `-netdev user,id=net0,hostfwd=tcp::2222-:22` is present.
   * Inside the guest, check `sudo dnf install -y openssh-server && sudo systemctl enable --now sshd`.
   * Verify Fedora’s firewall (e.g. `sudo firewall-cmd --add-service=ssh --permanent && sudo firewall-cmd --reload`) or disable it temporarily (`sudo systemctl disable --now firewalld`) to allow port 22.

8. **Performance is slow / high CPU usage**

   * Confirm KVM acceleration is working:

     ```bash
     lsmod | grep kvm
     ```
   * Confirm QEMU is using `-machine type=q35,accel=kvm -cpu host`. If not, add `-enable-kvm` explicitly.
   * You can reduce VM RAM (e.g. `-m 2G`) or CPUs (`-smp 2`) in `start-wayland-vm.sh` if your host is constrained.
   * For graphics, check that your host GPU drivers (Mesa/Radeon/Intel) support kms and that you’re running a current kernel.

---

## Customization & Advanced Topics

1. **Change VM Disk Size or Location**

   * Edit `VM_DISK_SIZE="20G"` or `VM_DIR="$HOME/wayland-vm"` at the top of `part2.sh` before running.
   * You can place the VM directory on any mount point (e.g. an external SSD) by changing `VM_DIR`.

2. **Adjust VM Memory/CPU**

   * In `part2.sh`, modify `VM_RAM="4G"` or `VM_CPUS="4"`.
   * In the generated `start-wayland-vm.sh`, these values appear under:

     ```bash
     -m 4G -smp 4
     ```
   * After first run, you can also edit `start-wayland-vm.sh` directly to set custom memory/CPU.

3. **Use a Different Guest Distribution**

   * Replace `FEDORA_ISO_URL` with the URL for your chosen distro’s Live ISO.
   * Update `PATH` to the ISO accordingly.
   * Modify `install-helper.sh` instructions to match that distro’s package manager (e.g., `apt` for Ubuntu).
   * Ensure any Wayland apps you want to auto-start are available in that distro’s repo.

4. **Share Host-Guest Files**

   * The `-virtfs` line in `start-wayland-vm.sh` exposes the host’s `~/wayland-vm/scripts` under the `mount_tag=hostscripts`.
   * Inside the guest, you can mount it at boot by adding to `/etc/fstab` (on the installed VM):

     ```
     hostscripts   /mnt/hostscripts   9p   trans=virtio,version=9p2000.L,rw,_netdev   0  0
     ```
   * This lets you edit scripts on the host and have them immediately visible in the guest.

5. **Switch to virtio-fs (if your Fedora kernel supports it)**

   * Replace the `-virtfs local,…` line with:

     ```
     -virtio-fs /home/$USER/wayland-vm/scripts,mount_tag=hostscripts
     ```

     and inside the guest:

     ```
     sudo mkdir -p /mnt/hostscripts
     sudo mount -t virtiofs hostscripts /mnt/hostscripts
     ```

6. **Enable SPICE with virtio-gpu**

   * In `start-wayland-vm.sh`, you could add:

     ```
     -spice port=5930,disable-ticketing,gl=on
     -device virtio-gpu-pci,virgl=on
     ```

     in place of the Rutabaga line if you prefer a SPICE window instead of GTK.

7. **Automate Guest Customization (virt-customize / cloud-init)**

   * Instead of asking the user to run `install-helper.sh` manually inside the guest, you can:

     * Install `libguestfs-tools` on the host.
     * After creating `wayland-test-vm.qcow2`, run:

       ```bash
       sudo virt-customize -a wayland-test-vm.qcow2 \
         --copy-in scripts/guest-autostart.sh:/usr/local/bin/guest-autostart.sh \
         --run-command 'chmod +x /usr/local/bin/guest-autostart.sh' \
         --run-command 'cat << "EOF" > /etc/systemd/system/wayland-autostart.service
       [Unit]
       Description=Run Guest Wayland Autostart
       After=graphical.target

       [Service]
       Type=simple
       ExecStart=/usr/local/bin/guest-autostart.sh

       [Install]
       WantedBy=graphical.target
       EOF' \
         --run-command 'systemctl enable wayland-autostart.service'
       ```
     * Then your VM is pre-injected with the autostart files before it ever boots.

---

### In Summary

* **`part1.sh`** builds a custom QEMU with `virtio-gpu-rutabaga` from scratch.
* **`part2.sh`** uses that custom QEMU to create a Fedora 41 VM that boots with hardware-accelerated Wayland graphics.
* You end up with a self-contained workflow:

  1. Run `part1.sh` → compile/install QEMU + Rutabaga.
  2. Run `part2.sh` → install prerequisites + generate VM files.
  3. Boot VM (`start-wayland-vm.sh --install`), install Fedora guest.
  4. Inside guest, run `install-helper.sh` → copy `guest-autostart.sh`, enable systemd service.
  5. Reboot guest → Foot, Gedit, Firefox launch automatically under Wayland.
  6. From now on, `start-wayland-vm.sh` always resumes the installed guest with accelerated graphics.

At this point, you have reproduced Chromium OS–style hardware-accelerated Wayland via `virtio-gpu-rutabaga` on a “normal” Linux distribution (Fedora 41). All steps are fully scripted in Bash, require only Fedora’s official repositories plus direct compilation of Rutabaga and QEMU, and do not depend on libvirt or virt-manager (though those packages are installed for convenience).

Feel free to refer back to this README whenever you need to understand or customize any part of the build or VM setup. Enjoy your accelerated Wayland VM!
ojuschugh@gmail.com
