#!/bin/bash
set -e
ROOTFS="$(realpath -m build/rootfs)"
THEME_REPO="https://github.com/Inled-Pulsar-OS/MacTahoe-gtk-theme"
BUILD_DIR="build/themes"

echo "🎨 Configurando Tema MacTahoe para GNOME..."

# 1. Clonar el tema si no existe
mkdir -p "$BUILD_DIR"
if [ ! -d "$BUILD_DIR/MacTahoe" ]; then
    echo "Clonando repositorio del tema..."
    git clone "$THEME_REPO" "$BUILD_DIR/MacTahoe" --depth=1
fi

# 2. Instalar el tema DENTRO del rootfs
echo "Instalando tema en el sistema..."
cp -r "$BUILD_DIR/MacTahoe" "$ROOTFS/tmp/"

# Instalación global (/usr/share/themes) y local para el fix de libadwaita
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/MacTahoe && ./install.sh -l -b -c dark --silent-mode"

# Truco: Copiar la configuración de libadwaita generada a /etc/skel para que todos los usuarios la tengan
echo "Aplicando fix de libadwaita a /etc/skel..."
pkexec mkdir -p "$ROOTFS/etc/skel/.config/gtk-4.0"
pkexec cp -r "$ROOTFS/root/.config/gtk-4.0/"* "$ROOTFS/etc/skel/.config/gtk-4.0/" 2>/dev/null || true
# También aplicarlo al usuario jaime si ya existe
pkexec mkdir -p "$ROOTFS/home/jaime/.config/gtk-4.0"
pkexec cp -r "$ROOTFS/root/.config/gtk-4.0/"* "$ROOTFS/home/jaime/.config/gtk-4.0/" 2>/dev/null || true
pkexec chown -R 1000:1000 "$ROOTFS/home/jaime/.config"

# 3. Configurar dconf para que el tema se aplique por defecto y activar extensiones
echo "Configurando dconf default y extensiones..."
pkexec mkdir -p "$ROOTFS/etc/dconf/db/local.d"
cat <<EOF | pkexec tee "$ROOTFS/etc/dconf/db/local.d/00-pulsaros-theme"
[org/gnome/desktop/interface]
gtk-theme='MacTahoe-Dark'
cursor-theme='MacTahoe-Dark'
icon-theme='MacTahoe-Dark'
color-scheme='prefer-dark'
font-name='Sans 11'

[org/gnome/shell/extensions/user-theme]
name='MacTahoe-Dark'

[org/gnome/shell]
enabled-extensions=['user-theme@gnome-shell-extensions.gcampax.github.com', 'dash-to-dock@micxgx.gmail.com', 'blur-my-shell@aunetx']
EOF

# Actualizar base de datos dconf
pkexec /usr/sbin/chroot "$ROOTFS" dconf update

# Limpiar
pkexec rm -rf "$ROOTFS/tmp/MacTahoe"

echo "✅ Tema MacTahoe inyectado y configurado."
