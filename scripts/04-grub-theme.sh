#!/bin/bash
set -e
ROOTFS="$(realpath -m build/rootfs)"
GRUB_THEME_REPO="https://github.com/Inled-Pulsar-OS/grub.theme"
BUILD_DIR="$(realpath -m build/themes)"

# Función de limpieza para asegurar desmontaje
cleanup() {
    echo "🧹 Finalizando y liberando recursos..."
    pkexec umount -l "$ROOTFS/proc" || true
    pkexec umount -l "$ROOTFS/sys" || true
    pkexec umount -l "$ROOTFS/dev/pts" || true
    pkexec umount -l "$ROOTFS/dev" || true
}
trap cleanup EXIT INT TERM

echo "🎨 Instalando Tema de GRUB Pulsar OS..."

# 1. Clonar el tema si no existe
mkdir -p "$BUILD_DIR"
if [ ! -d "$BUILD_DIR/grub-theme" ]; then
    echo "Clonando repositorio del tema GRUB..."
    git clone "$GRUB_THEME_REPO" "$BUILD_DIR/grub-theme" --depth=1
fi

# 2. Inyectar el tema en el rootfs
pkexec cp -r "$BUILD_DIR/grub-theme" "$ROOTFS/tmp/"

# --- Preparar entorno (Mounts) ---
echo "Montando sistemas de archivos virtuales..."
pkexec mount -t proc proc "$ROOTFS/proc" || true
pkexec mount -t sysfs sys "$ROOTFS/sys" || true
pkexec mount --bind /dev "$ROOTFS/dev" || true
pkexec mount --bind /dev/pts "$ROOTFS/dev/pts" || true

# Ejecutar el instalador del tema dentro del chroot
# Usamos un "shim" para grub-probe para evitar fallos en entornos de construcción/chroot
echo "Aplicando tema de GRUB..."
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "
    export PATH=\$PATH:/usr/sbin
    # Mock de grub-probe para evitar fallos si no hay dispositivo real
    echo '#!/bin/sh' > /usr/local/bin/grub-probe
    echo 'exit 0' >> /usr/local/bin/grub-probe
    chmod +x /usr/local/bin/grub-probe
    
    cd /tmp/grub-theme
    ./install.sh -t window -s 2k || echo 'Aviso: El instalador de GRUB reportó errores, pero continuamos...'
    
    rm /usr/local/bin/grub-probe
"

# 3. Limpiar
pkexec rm -rf "$ROOTFS/tmp/grub-theme"

echo "✅ Tema de GRUB inyectado."
