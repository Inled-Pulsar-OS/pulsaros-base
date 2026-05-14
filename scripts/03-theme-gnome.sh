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
# Usamos un script temporal dentro del chroot para ejecutar el install.sh del tema
echo "Instalando tema en el sistema..."
cp -r "$BUILD_DIR/MacTahoe" "$ROOTFS/tmp/"

# Ejecutamos la instalación con las opciones solicitadas:
# -l: libadwaita fix
# -b: blur version
# -c dark: versión oscura
# --silent-mode: para que no pregunte nada
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/MacTahoe && ./install.sh -l -b -c dark --silent-mode"

# 3. Configurar dconf para que el tema se aplique por defecto
# Creamos un archivo de perfil dconf para que todos los usuarios lo hereden
echo "Configurando dconf default para el tema..."
pkexec mkdir -p "$ROOTFS/etc/dconf/profile"
echo "user-db:user" | pkexec tee "$ROOTFS/etc/dconf/profile/user"
echo "system-db:local" | pkexec tee -a "$ROOTFS/etc/dconf/profile/user"

pkexec mkdir -p "$ROOTFS/etc/dconf/db/local.d"
cat <<EOF | pkexec tee "$ROOTFS/etc/dconf/db/local.d/00-pulsaros-theme"
[org/gnome/desktop/interface]
gtk-theme='MacTahoe-Dark'
cursor-theme='MacTahoe-Dark'
icon-theme='MacTahoe-Dark'
color-scheme='prefer-dark'

[org/gnome/shell/extensions/user-theme]
name='MacTahoe-Dark'
EOF

# Actualizar base de datos dconf
pkexec /usr/sbin/chroot "$ROOTFS" dconf update

# Limpiar
pkexec rm -rf "$ROOTFS/tmp/MacTahoe"

echo "✅ Tema MacTahoe inyectado y configurado."
