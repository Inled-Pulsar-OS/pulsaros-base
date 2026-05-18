#!/bin/bash
# Script para probar el rootfs rápidamente en QEMU usando 9pfs
# No requiere crear imágenes de disco, monta la carpeta directamente.

ROOTFS="$(realpath -m build/rootfs)"

if [ ! -d "$ROOTFS" ]; then
    echo "Error: No existe el rootfs en $ROOTFS. Ejecuta ./build.sh primero."
    exit 1
fi

# Buscar Kernel e Initrd (nombres dinámicos según versión) usando rutas absolutas
KERNEL=$(ls "$ROOTFS"/boot/vmlinuz-* 2>/dev/null | head -n 1)
INITRD=$(ls "$ROOTFS"/boot/initrd.img-* 2>/dev/null | head -n 1)

if [ -z "$KERNEL" ] || [ -z "$INITRD" ]; then
    echo "Error: No se encontró kernel/initrd en $ROOTFS/boot/"
    echo "Contenido de $ROOTFS/boot/:"
    ls -F "$ROOTFS/boot/"
    exit 1
fi

echo "🧹 Limpiando procesos previos de QEMU y liberando puerto VNC (5900)..."
pkexec fuser -k 5900/tcp 2>/dev/null || true
sleep 1

# Detectar Arquitectura y establecer consola
HOST_ARCH=$(uname -m)
case "$HOST_ARCH" in
    x86_64)
        QEMU_BIN="qemu-system-x86_64"
        ACCEL="-enable-kvm -cpu host"
        CONSOLE="tty0 console=ttyS0"
        ;;
    aarch64|arm64)
        QEMU_BIN="qemu-system-aarch64"
        CONSOLE="ttyAMA0"
        # En una VM de Linux en Mac (M-series), usamos KVM si está disponible
        if [ -e /dev/kvm ]; then
            ACCEL="-enable-kvm -cpu host"
        else
            ACCEL="-cpu max"
        fi
        # Añadir máquina virt para ARM64
        ACCEL="$ACCEL -M virt -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd"
        ;;
    *)
        QEMU_BIN="qemu-system-x86_64"
        ACCEL=""
        CONSOLE="tty0"
        ;;
esac

echo "🖥️ Iniciando QEMU ($QEMU_BIN)..."
echo "📂 Rootfs: $ROOTFS"
echo "🍎 Kernel: $KERNEL"

# Exportar variables de entorno para que QEMU encuentre la pantalla y la GPU
pkexec env \
    DISPLAY="$DISPLAY" \
    XAUTHORITY="$XAUTHORITY" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    __NV_PRIME_RENDER_OFFLOAD=1 \
    __GLX_VENDOR_LIBRARY_NAME=nvidia \
    $QEMU_BIN \
    -m 4G \
    -smp 4 \
    $ACCEL \
    -kernel "$KERNEL" \
    -initrd "$INITRD" \
    -append "root=rootfs rw rootfstype=9p rootflags=trans=virtio,version=9p2000.L,msize=262144 console=$CONSOLE quiet splash plymouth.ignore-serial-consoles fbcon=nodefer loglevel=3" \
    -fsdev local,id=rootfs,path="$ROOTFS",security_model=passthrough \
    -device virtio-9p-pci,fsdev=rootfs,mount_tag=rootfs \
    -device virtio-vga-gl \
    -display sdl,gl=on \
    -serial mon:stdio
