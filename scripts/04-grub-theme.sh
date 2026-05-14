#!/bin/bash
set -e
ROOTFS="$(realpath -m build/rootfs)"
GRUB_THEME_REPO="https://github.com/Inled-Pulsar-OS/grub.theme"
BUILD_DIR="build/themes"

echo "🎨 Instalando Tema de GRUB Pulsar OS..."

# 1. Clonar el tema si no existe
mkdir -p "$BUILD_DIR"
if [ ! -d "$BUILD_DIR/grub-theme" ]; then
    echo "Clonando repositorio del tema GRUB..."
    git clone "$GRUB_THEME_REPO" "$BUILD_DIR/grub-theme" --depth=1
fi

# 2. Inyectar el tema en el rootfs
cp -r "$BUILD_DIR/grub-theme" "$ROOTFS/tmp/"

# Ejecutar el instalador del tema dentro del chroot
# -t window: estilo ventana
# -s 2k: resolución 2k (ajustable)
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/grub-theme && ./install.sh -t window -s 2k"

# 3. Limpiar
pkexec rm -rf "$ROOTFS/tmp/grub-theme"

echo "✅ Tema de GRUB inyectado."
