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

echo "🖥️ Iniciando QEMU con Aceleración KVM + VirGL..."
echo "📂 Rootfs: $ROOTFS"
echo "🍎 Kernel: $KERNEL"
echo "💡 Usando NVIDIA/VirGL para renderizado."

# Exportar variables de entorno para que QEMU encuentre la pantalla y la GPU
# __NV_PRIME_RENDER_OFFLOAD=1 ayuda en portátiles con NVIDIA híbrida (como la 920MX)
pkexec env \
    DISPLAY="$DISPLAY" \
    XAUTHORITY="$XAUTHORITY" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    __NV_PRIME_RENDER_OFFLOAD=1 \
    __GLX_VENDOR_LIBRARY_NAME=nvidia \
    qemu-system-x86_64 \
    -m 4G \
    -smp 4 \
    -enable-kvm \
    -cpu host \
    -kernel "$KERNEL" \
    -initrd "$INITRD" \
    -append "root=rootfs rw rootfstype=9p rootflags=trans=virtio,version=9p2000.L,msize=262144 console=ttyS0 loglevel=7" \
    -fsdev local,id=rootfs,path="$ROOTFS",security_model=passthrough \
    -device virtio-9p-pci,fsdev=rootfs,mount_tag=rootfs \
    -device virtio-vga-gl \
    -display sdl,gl=on \
    -serial mon:stdio
