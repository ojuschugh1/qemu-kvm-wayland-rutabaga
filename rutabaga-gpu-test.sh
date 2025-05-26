#!/bin/bash

# ========================
# Combined Script: try3.sh + try3part2.sh
# ========================

# ---- Begin try3.sh ----

build_qemu_with_rutabaga() {
    set -e  # Exit on any error
    set -x  # Enable debug tracing

    # Colors for output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color

    # Configuration
    WORK_DIR="$HOME/qemu-rutabaga-build"
    QEMU_VERSION="stable-8.2"
    INSTALL_PREFIX="/usr/local"
    BUILD_JOBS=$(nproc)

    echo -e "${BLUE}=== QEMU with Rutabaga Complete Build Script ===${NC}"
    echo -e "${YELLOW}This script will:${NC}"
    echo "1. Remove existing QEMU installations"
    echo "2. Install build dependencies"
    echo "3. Build rutabaga_gfx library"
    echo "4. Build QEMU with rutabaga support"
    echo "5. Install the new build"
    echo ""

    # Function to print colored output
    print_status() {
        echo -e "${GREEN}[INFO]${NC} $1"
    }

    print_warning() {
        echo -e "${YELLOW}[WARNING]${NC} $1"
    }

    print_error() {
        echo -e "${RED}[ERROR]${NC} $1"
    }

    # Check if running as root for system-wide installation
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root - will install system-wide"
        SUDO=""
    else
        print_status "Running as user - will use sudo for installation"
        SUDO="sudo"
    fi

    # Step 1: Remove existing QEMU installations
    print_status "Step 1: Removing existing QEMU installations..."

    # Remove system packages
    if command -v apt >/dev/null 2>&1; then
        print_status "Removing QEMU packages (Debian/Ubuntu)..."
        $SUDO apt remove -y qemu qemu-kvm qemu-system qemu-system-x86 qemu-utils || true
        $SUDO apt autoremove -y || true
    elif command -v dnf >/dev/null 2>&1; then
        print_status "Removing QEMU packages (Fedora)..."
        $SUDO dnf remove -y qemu qemu-kvm qemu-system-x86 || true
    elif command -v pacman >/dev/null 2>&1; then
        print_status "Removing QEMU packages (Arch)..."
        $SUDO pacman -R --noconfirm qemu qemu-desktop qemu-system-x86 || true
    fi

    # Remove from common installation directories
    print_status "Removing QEMU from common directories..."
    $SUDO rm -rf /usr/local/bin/qemu*
    $SUDO rm -rf /usr/local/share/qemu
    $SUDO rm -rf /usr/local/libexec/qemu*
    $SUDO rm -rf /usr/bin/qemu*
    $SUDO rm -rf /usr/share/qemu

    # Remove old build directory
    print_status "Cleaning old build directory..."
    rm -rf "$WORK_DIR"

    # Step 2: Install build dependencies
    print_status "Step 2: Installing build dependencies..."

    if command -v apt >/dev/null 2>&1; then
        print_status "Installing dependencies (Debian/Ubuntu)..."
        $SUDO apt update
        $SUDO apt install -y \
            build-essential \
            git \
            libglib2.0-dev \
            libfdt-dev \
            libpixman-1-dev \
            zlib1g-dev \
            libnfs-dev \
            libiscsi-dev \
            ninja-build \
            libslirp-dev \
            libvirglrenderer-dev \
            libepoxy-dev \
            libdrm-dev \
            libgbm-dev \
            libx11-dev \
            libwayland-dev \
            wayland-protocols \
            libwayland-egl-backend-dev \
            libxkbcommon-dev \
            libgtk-3-dev \
            libvte-2.91-dev \
            libsdl2-dev \
            libspice-protocol-dev \
            libspice-server-dev \
            libaio-dev \
            libbluetooth-dev \
            libbrlapi-dev \
            libbz2-dev \
            libcap-dev \
            libcap-ng-dev \
            libcurl4-gnutls-dev \
            libgtk-3-dev \
            libibverbs-dev \
            libjpeg8-dev \
            libncurses5-dev \
            libnuma-dev \
            librbd-dev \
            librdmacm-dev \
            libsasl2-dev \
            libsdl2-dev \
            libseccomp-dev \
            libsnappy-dev \
            libssh-dev \
            libvde-dev \
            libvdeplug-dev \
            libxen-dev \
            liblzo2-dev \
            valgrind \
            xfslibs-dev \
            libnfs-dev \
            libiscsi-dev \
            python3-pip \
            python3-sphinx \
            python3-sphinx-rtd-theme \
            cargo \
            rustc

    elif command -v dnf >/dev/null 2>&1; then
        print_status "Installing dependencies (Fedora)..."
        $SUDO dnf install -y --skip-unavailable \
            gcc \
            gcc-c++ \
            git \
            glib2-devel \
            libfdt-devel \
            pixman-devel \
            zlib-devel \
            zlib-ng-compat-devel \
            ninja-build \
            libslirp-devel \
            virglrenderer-devel \
            libepoxy-devel \
            libdrm-devel \
            mesa-libgbm-devel \
            libX11-devel \
            wayland-devel \
            wayland-protocols-devel \
            wayland-devel \
            libxkbcommon-devel \
            gtk3-devel \
            vte291-devel \
            SDL2-devel \
            spice-protocol \
            spice-server-devel \
            libaio-devel \
            bluez-libs-devel \
            brlapi-devel \
            bzip2-devel \
            libcap-devel \
            libcap-ng-devel \
            libcurl-devel \
            rdma-core-devel \
            libjpeg-turbo-devel \
            ncurses-devel \
            numactl-devel \
            librbd-devel \
            cyrus-sasl-devel \
            libseccomp-devel \
            snappy-devel \
            libssh-devel \
            vde2-devel \
            lzo-devel \
            valgrind \
            xfsprogs-devel \
            libnfs-devel \
            libiscsi-devel \
            python3-pip \
            python3-sphinx \
            cargo \
            rust

    elif command -v pacman >/dev/null 2>&1; then
        print_status "Installing dependencies (Arch)..."
        $SUDO pacman -S --needed --noconfirm \
            base-devel \
            git \
            glib2 \
            dtc \
            pixman \
            zlib \
            ninja \
            libslirp \
            virglrenderer \
            libepoxy \
            libdrm \
            mesa \
            libx11 \
            wayland \
            wayland-protocols \
            libxkbcommon \
            gtk3 \
            vte3 \
            sdl2 \
            spice-protocol \
            spice \
            libaio \
            bluez-libs \
            brltty \
            bzip2 \
            libcap \
            libcap-ng \
            curl \
            libibverbs \
            libjpeg-turbo \
            ncurses \
            numactl \
            ceph-libs \
            librdmacm \
            libsasl \
            libseccomp \
            snappy \
            libssh \
            vde2 \
            lzo \
            valgrind \
            xfsprogs \
            libnfs \
            libiscsi \
            python-pip \
            python-sphinx \
            rust \
            cargo
    fi

    # Step 3: Create work directory and build rutabaga
    print_status "Step 3: Setting up work directory..."
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"

    print_status "Cloning and building rutabaga_gfx..."
    git clone https://chromium.googlesource.com/chromiumos/platform/crosvm
    cd crosvm

    # Initialize submodules
    print_status "Initializing git submodules..."
    git submodule update --init --recursive

    cd rutabaga_gfx

    # Build rutabaga_gfx with minimal features to avoid dependency issues
    print_status "Building rutabaga_gfx library..."
    cargo build --release --no-default-features --features=gfxstream

    # Check if build succeeded, if not try alternative approach
    if [ ! -f "target/release/librutabaga_gfx.so" ] && [ ! -f "target/release/librutabaga_gfx.a" ]; then
        print_warning "Standard build failed, trying alternative build..."
        
        # Try building with different feature set
        cargo build --release --no-default-features --features=virgl_renderer || \
        cargo build --release --no-default-features || \
        {
            print_error "Rutabaga build failed. Proceeding without rutabaga library (QEMU will build its own)"
            cd "$WORK_DIR"
            rm -rf crosvm
            SKIP_RUTABAGA_LIB=1
        }
    fi

    # Install rutabaga library if build succeeded
    if [ "$SKIP_RUTABAGA_LIB" != "1" ]; then
        print_status "Installing rutabaga library..."
        
        # Find the built library files
        if [ -f "target/release/librutabaga_gfx.so" ]; then
            $SUDO cp target/release/librutabaga_gfx.so /usr/local/lib/
        fi
        if [ -f "target/release/librutabaga_gfx.a" ]; then
            $SUDO cp target/release/librutabaga_gfx.a /usr/local/lib/
        fi
        
        # Install headers if available
        $SUDO mkdir -p /usr/local/include/rutabaga_gfx
        if [ -f "src/rutabaga_gfx.h" ]; then
            $SUDO cp src/rutabaga_gfx.h /usr/local/include/rutabaga_gfx/
        fi
        if [ -f "ffi/src/rutabaga_gfx_ffi.h" ]; then
            $SUDO cp ffi/src/rutabaga_gfx_ffi.h /usr/local/include/rutabaga_gfx/
        fi
        
        $SUDO ldconfig
        print_status "Rutabaga library installed successfully"
    else
        print_warning "Skipping rutabaga library installation - QEMU will use built-in support"
    fi

    cd "$WORK_DIR"

    # Step 4: Clone and build QEMU
    print_status "Step 4: Cloning QEMU..."
    git clone https://github.com/qemu/qemu.git
    cd qemu
    git checkout "$QEMU_VERSION"

    print_status "Configuring QEMU build with rutabaga support..."

    # Configure QEMU with rutabaga and minimal features for better compatibility
    ./configure \
        --prefix="$INSTALL_PREFIX" \
        --target-list=x86_64-softmmu,aarch64-softmmu \
        --enable-kvm \
        --enable-rutabaga-gfx \
        --enable-virglrenderer \
        --enable-opengl \
        --enable-gtk \
        --enable-sdl \
        --enable-spice \
        --enable-vnc \
        --enable-curses \
        --enable-linux-aio \
        --enable-cap-ng \
        --enable-attr \
        --enable-vhost-net \
        --enable-vhost-crypto \
        --enable-vhost-kernel \
        --enable-vhost-user \
        --enable-vhost-vdpa \
        --enable-slirp \
        --audio-drv-list=pa,alsa \
        --disable-werror

    print_status "Building QEMU (this may take a while)..."
    make -j"$BUILD_JOBS"

    # Step 5: Install QEMU
    print_status "Step 5: Installing QEMU..."
    $SUDO make install

    # Create symlinks for common commands
    print_status "Creating convenient symlinks..."
    $SUDO ln -sf "$INSTALL_PREFIX/bin/qemu-system-x86_64" /usr/local/bin/qemu || true
    $SUDO ln -sf "$INSTALL_PREFIX/bin/qemu-img" /usr/local/bin/qemu-img || true

    # Update library cache
    $SUDO ldconfig

    # Step 6: Verify installation
    print_status "Step 6: Verifying installation..."
    echo ""
    echo -e "${GREEN}=== Installation Complete! ===${NC}"
    echo ""

    # Check QEMU version
    if command -v "$INSTALL_PREFIX/bin/qemu-system-x86_64" >/dev/null 2>&1; then
        echo -e "${GREEN}QEMU Version:${NC}"
        "$INSTALL_PREFIX/bin/qemu-system-x86_64" --version
        echo ""
        
        echo -e "${GREEN}Available devices (checking for rutabaga):${NC}"
        "$INSTALL_PREFIX/bin/qemu-system-x86_64" -device help | grep -i rutabaga || echo "Rutabaga device not found in help output"
        echo ""
        
        echo -e "${GREEN}Installation paths:${NC}"
        echo "QEMU binary: $INSTALL_PREFIX/bin/qemu-system-x86_64"
        echo "QEMU images: $INSTALL_PREFIX/bin/qemu-img"
        echo "Rutabaga lib: /usr/local/lib/librutabaga_gfx.so"
        echo ""
        
        echo -e "${GREEN}Example VM command with Wayland forwarding:${NC}"
        cat << 'EOF'
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
EOF
        echo ""
        
        echo -e "${GREEN}Build directory (can be removed):${NC} $WORK_DIR"
        echo ""
        echo -e "${YELLOW}Note: You may need to add $INSTALL_PREFIX/bin to your PATH${NC}"
        echo -e "${YELLOW}Run: export PATH=$INSTALL_PREFIX/bin:\$PATH${NC}"
        
    else
        print_error "Installation verification failed!"
        exit 1
    fi

    # Optional cleanup
    echo ""
    read -p "Remove build directory $WORK_DIR? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleaning up build directory..."
        rm -rf "$WORK_DIR"
        echo -e "${GREEN}Build directory removed.${NC}"
    fi

    echo ""
    echo -e "${GREEN}Setup complete! QEMU with rutabaga support is ready.${NC}"
}

# ---- End try3.sh ----

# ---- Begin try3part2.sh ----

# Complete QEMU/KVM VM with Wayland Forwarding Setup Script
# Target: Fedora 41 Workstation (Live USB or fresh installation)
# Features: virtio-gpu-rutabaga, hardware acceleration, Wayland forwarding

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VM_NAME="wayland-test-vm"
VM_DIR="$HOME/wayland-vm"
VM_DISK="$VM_DIR/${VM_NAME}.qcow2"
VM_DISK_SIZE="20G"
VM_RAM="4G"
VM_CPUS="4"
ISO_DIR="$VM_DIR/iso"
FEDORA_ISO_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/41/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-41-1.4.iso"
FEDORA_ISO="$ISO_DIR/fedora-41-workstation.iso"

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if running on Fedora
check_fedora() {
    if ! grep -q "Fedora" /etc/os-release 2>/dev/null; then
        print_error "This script is designed for Fedora 41. Please run on Fedora."
        exit 1
    fi
    local version=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    print_status "Detected Fedora $version"
    if [[ "$version" != "41" ]]; then
        print_warning "This script is optimized for Fedora 41, but will try to work on version $version"
    fi
}

install_packages() {
    print_header "Installing Required Packages"
    print_status "Updating system packages..."
    sudo dnf update -y --skip-unavailable
    print_status "Installing virtualization packages..."
    sudo dnf install -y --skip-unavailable \
        qemu-kvm \
        qemu-img \
        libvirt \
        libvirt-daemon-kvm \
        virt-manager \
        bridge-utils \
        curl \
        wget \
        unzip \
        rsync
    print_status "Installing development packages..."
    sudo dnf install -y --skip-unavailable \
        gcc \
        gcc-c++ \
        make \
        cmake \
        git \
        pkgconfig \
        meson \
        ninja-build
    print_status "Installing graphics and Wayland packages..."
    sudo dnf install -y --skip-unavailable \
        mesa-dri-drivers \
        mesa-vulkan-drivers \
        libdrm \
        wayland-devel \
        wayland-protocols-devel \
        libxkbcommon \
        weston \
        foot \
        gedit \
        firefox \
        gnome-terminal
    print_status "Enabling libvirt service..."
    sudo systemctl enable --now libvirtd
    print_status "Adding user to libvirt group..."
    sudo usermod -a -G libvirt $(whoami)
    print_status "Package installation complete"
}

check_qemu_rutabaga() {
    print_header "Checking QEMU Rutabaga Support"
    local qemu_path=""
    if [[ -x "/usr/local/bin/qemu-system-x86_64" ]]; then
        qemu_path="/usr/local/bin/qemu-system-x86_64"
        print_status "Found custom QEMU at $qemu_path"
    elif [[ -x "/usr/bin/qemu-system-x86_64" ]]; then
        qemu_path="/usr/bin/qemu-system-x86_64"
        print_status "Found system QEMU at $qemu_path"
    else
        print_error "QEMU not found. Please install QEMU first."
        exit 1
    fi
    if $qemu_path -device help | grep -q "virtio-gpu-rutabaga"; then
        print_status "✅ QEMU has rutabaga support"
        QEMU_BIN="$qemu_path"
    else
        print_error "❌ QEMU does not have rutabaga support. Please build QEMU with rutabaga."
        print_error "Run the previous rutabaga build script first."
        exit 1
    fi
    print_status "Available rutabaga devices:"
    $qemu_path -device help | grep rutabaga | sed 's/^/  /'
}

setup_vm_directory() {
    print_header "Setting Up VM Directory Structure"
    mkdir -p "$VM_DIR"
    mkdir -p "$ISO_DIR"
    mkdir -p "$VM_DIR/scripts"
    mkdir -p "$VM_DIR/shared"
    print_status "VM directory created at: $VM_DIR"
}

download_fedora_iso() {
    print_header "Preparing Fedora ISO"
    if [[ -f "$FEDORA_ISO" ]]; then
        print_status "Fedora ISO already exists: $FEDORA_ISO"
        return 0
    fi
    print_status "Downloading Fedora 41 Workstation ISO..."
    print_status "This may take a while (approximately 2GB download)"
    curl -L -o "$FEDORA_ISO.tmp" "$FEDORA_ISO_URL"
    mv "$FEDORA_ISO.tmp" "$FEDORA_ISO"
    print_status "✅ Fedora ISO downloaded: $FEDORA_ISO"
}

create_vm_disk() {
    print_header "Creating VM Disk"
    if [[ -f "$VM_DISK" ]]; then
        print_warning "VM disk already exists: $VM_DISK"
        read -p "Do you want to recreate it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Using existing VM disk"
            return 0
        fi
        rm -f "$VM_DISK"
    fi
    print_status "Creating $VM_DISK_SIZE QEMU disk..."
    qemu-img create -f qcow2 "$VM_DISK" "$VM_DISK_SIZE"
    print_status "✅ VM disk created: $VM_DISK"
}

create_guest_autostart() {
    print_header "Creating Guest Autostart Script"
    local guest_script="$VM_DIR/scripts/guest-autostart.sh"
    cat > "$guest_script" << 'EOF'
#!/bin/bash
# Guest VM autostart script
# This script will be copied into the VM and run on boot
sleep 5
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WAYLAND_DISPLAY="wayland-0"
export GDK_BACKEND="wayland"
export QT_QPA_PLATFORM="wayland"
export MOZ_ENABLE_WAYLAND=1
mkdir -p "$XDG_RUNTIME_DIR"
wait_for_wayland() {
    local timeout=30
    local count=0
    while [[ $count -lt $timeout ]]; do
        if [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
            echo "Wayland display found"
            return 0
        fi
        sleep 1
        ((count++))
    done
    echo "Wayland display not found after \\${timeout}s"
    return 1
}
start_applications() {
    echo "Starting Wayland applications..."
    if command -v foot >/dev/null 2>&1; then
        echo "Starting foot terminal..."
        foot &
        sleep 2
    elif command -v gnome-terminal >/dev/null 2>&1; then
        echo "Starting gnome-terminal..."
        gnome-terminal &
        sleep 2
    fi
    if command -v gedit >/dev/null 2>&1; then
        echo "Starting gedit..."
        gedit &
        sleep 2
    fi
    if command -v firefox >/dev/null 2>&1; then
        echo "Starting Firefox..."
        firefox &
        sleep 3
    fi
    echo "Applications started"
}
echo "=== Guest Autostart Script ==="
echo "Waiting for Wayland to be available..."
if wait_for_wayland; then
    start_applications
    echo "✅ Guest setup complete"
else
    echo "❌ Failed to detect Wayland display"
    echo "Attempting to start applications without Wayland detection..."
    start_applications
fi
sleep 5
echo "Guest autostart script finished"
EOF
    chmod +x "$guest_script"
    print_status "✅ Guest autostart script created: $guest_script"
    # Copy to shared folder for guest access
    cp "$guest_script" "$VM_DIR/shared/guest-autostart.sh"
    # Create a helper script for the guest
    cat > "$VM_DIR/shared/setup-guest-autostart.sh" << 'EOS'
#!/bin/bash
set -e
# Mount the shared folder
sudo mkdir -p /mnt/hostshare
sudo mount -t 9p -o trans=virtio hostshare /mnt/hostshare
# Copy the autostart script to the user's home
cp /mnt/hostshare/guest-autostart.sh ~/
chmod +x ~/guest-autostart.sh
# Add to .bash_profile if not already present
if ! grep -q guest-autostart.sh ~/.bash_profile 2>/dev/null; then
    echo '~/guest-autostart.sh &' >> ~/.bash_profile
fi
echo "Guest autostart script installed. It will run on next login."
EOS
    chmod +x "$VM_DIR/shared/setup-guest-autostart.sh"
    print_status "✅ Guest autostart helper created: $VM_DIR/shared/setup-guest-autostart.sh"
    # Create a minimal Fedora kickstart file for auto-install
    cat > "$VM_DIR/shared/ks.cfg" << 'KSEND'
#version=DEVEL
lang en_US.UTF-8
keyboard us
timezone UTC
rootpw --plaintext fedora
user --name=fedora --password=fedora --plaintext --gecos="Fedora User"
auth --useshadow --passalgo=sha512
firewall --enabled
selinux --enforcing
network --bootproto=dhcp --device=eth0 --onboot=on
url --url="https://download.fedoraproject.org/pub/fedora/linux/releases/41/Everything/x86_64/os/"
bootloader --location=mbr
zerombr
clearpart --all --initlabel
autopart
reboot
%packages
@^workstation-product-environment
@gnome-desktop
firefox
foot
gedit
%end
%post
cp /mnt/hostshare/guest-autostart.sh /home/fedora/
chmod +x /home/fedora/guest-autostart.sh
echo '/home/fedora/guest-autostart.sh &' >> /home/fedora/.bash_profile
chown fedora:fedora /home/fedora/guest-autostart.sh /home/fedora/.bash_profile
%end
KSEND
    print_status "✅ Kickstart file created: $VM_DIR/shared/ks.cfg"
}

create_vm_launcher() {
    print_header "Creating VM Launcher Script"
    local launcher="$VM_DIR/start-wayland-vm.sh"
    cat > "$launcher" << 'EOF'
#!/bin/bash
set -e
VM_NAME="wayland-test-vm"
VM_DIR="$HOME/wayland-vm"
VM_DISK="$VM_DIR/${VM_NAME}.qcow2"
FEDORA_ISO="$VM_DIR/iso/fedora-41-workstation.iso"
QEMU_BIN="/usr/local/bin/qemu-system-x86_64"
KERNEL="$VM_DIR/vmlinuz"
INITRD="$VM_DIR/initrd.img"
VM_RAM="4G"
VM_CPUS="4"
ISO_LABEL=$(isoinfo -d -i "$FEDORA_ISO" 2>/dev/null | grep 'Volume id:' | awk -F': ' '{print $2}' || echo 'Fedora-WS-Live-41-1-4')
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
print_status() {
    echo -e "${GREEN}[VM]${NC} $1"
}
print_warning() {
    echo -e "${YELLOW}[VM]${NC} $1"
}
print_error() {
    echo -e "${RED}[VM]${NC} $1"
}
print_status "VM_NAME: $VM_NAME"
print_status "VM_DIR: $VM_DIR"
print_status "VM_DISK: $VM_DISK"
print_status "FEDORA_ISO: $FEDORA_ISO"
print_status "QEMU_BIN: $QEMU_BIN"
print_status "KERNEL: $KERNEL"
print_status "INITRD: $INITRD"
print_status "VM_RAM: $VM_RAM"
print_status "VM_CPUS: $VM_CPUS"
print_status "ISO_LABEL: $ISO_LABEL"

# --- Ensure ks.iso exists ---
if [ -f "$VM_DIR/shared/ks.cfg" ] && [ ! -f "$VM_DIR/shared/ks.iso" ]; then
    print_status "Creating ks.iso from ks.cfg for kickstart..."
    genisoimage -output "$VM_DIR/shared/ks.iso" -volid "KICKSTART" -joliet -rock -graft-points ks.cfg="$VM_DIR/shared/ks.cfg"
fi

INSTALL_MODE=false
DIRECT_KERNEL=false
QEMU_EXTRA_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --install)
            INSTALL_MODE=true
            shift
            ;;
        --direct-kernel)
            DIRECT_KERNEL=true
            shift
            ;;
        *)
            QEMU_EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done
BOOT_FROM_ISO=""
KERNEL_APPEND=""
if [[ "$INSTALL_MODE" == "true" ]] || [[ ! -s "$VM_DISK" ]]; then
    if [[ -f "$FEDORA_ISO" ]]; then
        if [[ "$DIRECT_KERNEL" == "true" ]]; then
            print_status "Booting with direct kernel/initrd and kickstart (fully automated)"
            exec "$QEMU_BIN" \
                -name "$VM_NAME" \
                -machine type=q35,accel=kvm \
                -cpu host \
                -m $VM_RAM \
                -smp $VM_CPUS \
                -enable-kvm \
                -display gtk,gl=on \
                -device virtio-gpu-rutabaga-pci,hostmem=256M,cross-domain=on,wsi=surfaceless \
                -drive file="$VM_DISK",format=qcow2,if=virtio,cache=writeback \
                -drive file="$FEDORA_ISO",media=cdrom,readonly=on \
                -drive file="$VM_DIR/shared/ks.iso",media=cdrom,readonly=on \
                -kernel "$KERNEL" \
                -initrd "$INITRD" \
                -append "inst.stage2=cdrom inst.ks=cdrom:/ks.cfg inst.lang=en_US.UTF-8 inst.keymap=us inst.text" \
                -netdev user,id=net0,hostfwd=tcp::2222-:22 \
                -device virtio-net-pci,netdev=net0 \
                -audiodev pa,id=audio0 \
                -device intel-hda \
                -device hda-duplex,audiodev=audio0 \
                -device virtio-keyboard-pci \
                -device usb-tablet \
                -rtc base=localtime \
                -usb \
                -monitor stdio \
                -virtfs local,path="$VM_DIR/shared",mount_tag=hostshare,security_model=passthrough,id=hostshare \
                "${QEMU_EXTRA_ARGS[@]}"
        else
            print_status "Booting from ISO for installation (with kickstart, semi-automated)"
            exec "$QEMU_BIN" \
                -name "$VM_NAME" \
                -machine type=q35,accel=kvm \
                -cpu host \
                -m $VM_RAM \
                -smp $VM_CPUS \
                -enable-kvm \
                -display gtk,gl=on \
                -device virtio-gpu-rutabaga-pci,hostmem=256M,cross-domain=on,wsi=surfaceless \
                -drive file="$VM_DISK",format=qcow2,if=virtio,cache=writeback \
                -cdrom "$FEDORA_ISO" -boot d \
                -drive file="$VM_DIR/shared/ks.iso",media=cdrom,readonly=on \
                -netdev user,id=net0,hostfwd=tcp::2222-:22 \
                -device virtio-net-pci,netdev=net0 \
                -audiodev pa,id=audio0 \
                -device intel-hda \
                -device hda-duplex,audiodev=audio0 \
                -device virtio-keyboard-pci \
                -device usb-tablet \
                -rtc base=localtime \
                -usb \
                -monitor stdio \
                -virtfs local,path="$VM_DIR/shared",mount_tag=hostshare,security_model=passthrough,id=hostshare \
                "${QEMU_EXTRA_ARGS[@]}"
        fi
    else
        print_error "ISO not found at $FEDORA_ISO"
        print_error "Please run the setup script first to download the ISO"
        exit 1
    fi
else
    print_status "Booting from disk"
    exec "$QEMU_BIN" \
        -name "$VM_NAME" \
        -machine type=q35,accel=kvm \
        -cpu host \
        -m $VM_RAM \
        -smp $VM_CPUS \
        -enable-kvm \
        -display gtk,gl=on \
        -device virtio-gpu-rutabaga-pci,hostmem=256M,cross-domain=on,wsi=surfaceless \
        -drive file="$VM_DISK",format=qcow2,if=virtio,cache=writeback \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0 \
        -audiodev pa,id=audio0 \
        -device intel-hda \
        -device hda-duplex,audiodev=audio0 \
        -device virtio-keyboard-pci \
        -device usb-tablet \
        -rtc base=localtime \
        -usb \
        -monitor stdio \
        -virtfs local,path="$VM_DIR/shared",mount_tag=hostshare,security_model=passthrough,id=hostshare \
        "${QEMU_EXTRA_ARGS[@]}"
fi
EOF
    chmod +x "$launcher"
    print_status "✅ VM launcher created: $launcher"
}

create_install_helper() {
    print_header "Creating Installation Helper"
    local helper="$VM_DIR/install-helper.sh"
    cat > "$helper" << 'EOF'
#!/bin/bash
# Installation Helper for VM Setup
echo "=== VM Installation Helper ==="
echo "This script helps with the VM installation process."
echo ""
echo "Steps for VM setup:"
echo "1. Run the VM with: ./start-wayland-vm.sh --install"
echo "2. Install Fedora normally in the VM"
echo "3. After installation, reboot and run: ./start-wayland-vm.sh"
echo ""
echo "During Fedora installation:"
echo "- Choose 'Fedora Workstation' installation"
echo "- Enable Wayland (default in Fedora)"
echo "- Install additional packages if prompted"
echo ""
echo "After installation, the VM will boot with:"
echo "- Hardware-accelerated graphics via rutabaga"
echo "- Wayland display server"
echo "- Auto-starting applications (foot, gedit, firefox)"
echo ""
read -p "Press Enter to continue..."
EOF
    chmod +x "$helper"
    print_status "✅ Installation helper created: $helper"
}

create_test_script() {
    print_header "Creating Test Script"
    local test_script="$VM_DIR/test-wayland.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
# Test script to verify Wayland forwarding
echo "=== Wayland VM Test Script ==="
echo ""
if pgrep -f "wayland-test-vm" >/dev/null; then
    echo "✅ VM is running"
else
    echo "❌ VM is not running"
    echo "   Start with: ./start-wayland-vm.sh"
    exit 1
fi
echo "Checking QEMU rutabaga support:"
if /usr/local/bin/qemu-system-x86_64 -device help 2>/dev/null | grep -q rutabaga; then
    echo "✅ QEMU has rutabaga support"
else
    echo "❌ QEMU missing rutabaga support"
fi
echo ""
echo "Host Wayland status:"
if [[ -n "$WAYLAND_DISPLAY" ]] && [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
    echo "✅ Host Wayland is running: $WAYLAND_DISPLAY"
else
    echo "⚠️  Host Wayland not detected (may be using X11)"
fi
echo ""
echo "VM should be running with:"
echo "- virtio-gpu-rutabaga graphics device"
echo "- Hardware acceleration enabled"
echo "- Wayland applications (foot, gedit, firefox)"
echo ""
echo "If applications are not visible, check VM display settings"
echo "and ensure Wayland is properly configured in the guest."
EOF
    chmod +x "$test_script"
    print_status "✅ Test script created: $test_script"
}

create_readme() {
    print_header "Creating Documentation"
    local readme="$VM_DIR/README.md"
    cat > "$readme" << 'EOF'
# QEMU/KVM VM with Wayland Forwarding
This setup provides a QEMU/KVM virtual machine with hardware-accelerated graphics using virtio-gpu-rutabaga and Wayland forwarding capabilities.
## Target System
- **Host OS**: Fedora 41 Workstation
- **Guest OS**: Fedora 41 Workstation  
- **Graphics**: virtio-gpu-rutabaga with hardware acceleration
- **Display**: Wayland forwarding
## Files Created
- `start-wayland-vm.sh` - Main VM launcher script
- `install-helper.sh` - Installation guidance
- `test-wayland.sh` - Test and verification script
- `scripts/guest-autostart.sh` - Guest applications autostart
- `shared/` - Directory for host-guest file sharing
- `README.md` - This documentation
## Usage
### First Time Setup (Installation)
1. Run VM with installation ISO:
   ```bash
   ./start-wayland-vm.sh --install
   ```
2. Install Fedora Workstation in the VM:
   - Choose standard Fedora Workstation installation
   - Create user account
   - Ensure Wayland is enabled (default)
3. After installation completes, shut down the VM
### Normal Operation
```bash
./start-wayland-vm.sh
```
### Testing
```bash
./test-wayland.sh
```
## Features
- **Hardware Acceleration**: Uses virtio-gpu-rutabaga for GPU acceleration
- **Wayland Forwarding**: Native Wayland support with rutabaga
- **Auto-start Applications**: Automatically starts foot terminal, gedit, and Firefox
- **Audio Support**: PulseAudio passthrough
- **Network**: NAT networking with SSH forwarding (host:2222 -> guest:22)
## Technical Details
### QEMU Configuration
- Machine: q35 with KVM acceleration
- Graphics: virtio-gpu-rutabaga-pci with 256M hostmem
- Display: GTK with OpenGL enabled
- Cross-domain support enabled
- WSI: surfaceless for Wayland compatibility
### Guest Applications
The VM automatically starts:
- **foot**: Wayland-native terminal emulator
- **gedit**: Text editor with Wayland support  
- **Firefox**: Web browser with Wayland backend
### Performance
- Host memory: 4GB allocated to VM
- CPU cores: 4 cores passed through
- Storage: 20GB qcow2 disk with virtio interface
- Graphics: Hardware-accelerated via rutabaga
## Troubleshooting
### VM Won't Start
- Check if KVM is available: `lsmod | grep kvm`
- Verify QEMU has rutabaga: `qemu-system-x86_64 -device help | grep rutabaga`
- Check file permissions on VM disk
### No Graphics Acceleration
- Ensure host has proper GPU drivers
- Check if Wayland is running on host
- Verify rutabaga library is installed
### Applications Don't Start
- Check guest autostart script logs
- Verify Wayland is running in guest
- Test manual application launch
### Network Issues
- SSH to guest: `ssh -p 2222 user@localhost`
- Check if firewall is blocking connections
## Customization
### Modify VM Resources
Edit `start-wayland-vm.sh` and change:
- RAM: Modify `-m 4G` parameter
- CPUs: Modify `-smp 4` parameter
- Disk size: Recreate with different size
### Add More Applications
Edit `scripts/guest-autostart.sh` to include additional applications.
### Different Guest OS
Replace the Fedora ISO URL in the setup script with your preferred distribution.
## Notes
- This setup is optimized for Fedora 41 host and guest
- Requires QEMU built with rutabaga support
- Works best with modern AMD/Intel GPUs
- Wayland forwarding provides better performance than traditional X11 forwarding
EOF
    print_status "✅ Documentation created: $readme"
}

main() {
    build_qemu_with_rutabaga
    print_header "QEMU/KVM VM with Wayland Forwarding Setup"
    print_status "Target: Fedora 41 Workstation"
    print_status "Graphics: virtio-gpu-rutabaga"
    echo ""
    check_fedora
    install_packages
    check_qemu_rutabaga
    setup_vm_directory
    download_fedora_iso
    create_vm_disk
    create_guest_autostart
    create_vm_launcher
    create_install_helper
    create_test_script
    create_readme
    print_header "Setup Complete!"
    echo ""
    print_status "✅ VM environment ready at: $VM_DIR"
    echo ""
    print_status "Next steps:"
    echo "  1. cd $VM_DIR"
    echo "  2. ./install-helper.sh  # Read installation guide"
    echo "  3. ./start-wayland-vm.sh --install  # Install Fedora in VM"
    echo "  4. ./start-wayland-vm.sh  # Run VM normally"
    echo "  5. ./test-wayland.sh  # Test and verify setup"
    echo ""
    print_status "The VM will feature:"
    echo "  • Hardware-accelerated graphics via virtio-gpu-rutabaga"
    echo "  • Wayland display server with forwarding"
    echo "  • Auto-starting applications (foot, gedit, firefox)"
    echo "  • Audio and network connectivity"
    echo ""
    print_warning "Note: First boot requires Fedora installation via GUI"
    print_warning "Subsequent boots will automatically start Wayland applications"
    echo ""
    cd "$VM_DIR"
    # --- Full automation: extract kernel/initrd and use direct kernel boot for install ---
    if [ ! -f "vmlinuz" ] || [ ! -f "initrd.img" ]; then
        print_status "Extracting kernel and initrd from Fedora ISO..."
        # Try bsdtar first, fallback to 7z
        if command -v bsdtar >/dev/null 2>&1; then
            bsdtar -C "$VM_DIR" -xf "$ISO_DIR/fedora-41-workstation.iso" --include vmlinuz --include initrd.img || true
            # If not found, try common paths
            bsdtar -C "$VM_DIR" -xf "$ISO_DIR/fedora-41-workstation.iso" LiveOS/vmlinuz LiveOS/initrd.img || true
        elif command -v 7z >/dev/null 2>&1; then
            7z e "$ISO_DIR/fedora-41-workstation.iso" -o"$VM_DIR" vmlinuz initrd.img || true
            7z e "$ISO_DIR/fedora-41-workstation.iso" -o"$VM_DIR" LiveOS/vmlinuz LiveOS/initrd.img || true
        else
            print_error "Neither bsdtar nor 7z found. Please install one to extract kernel/initrd."
            exit 1
        fi
    fi
    if [ ! -f "vmlinuz" ] || [ ! -f "initrd.img" ]; then
        print_error "Could not extract vmlinuz and initrd.img from ISO."
        exit 1
    fi
    print_status "Starting VM in installation mode (direct kernel boot, fully automated)."
    exec ./start-wayland-vm.sh --install --direct-kernel
}

main "$@"

# ---- End try3part2.sh ---- 
