#!/bin/bash
set -e
ROOTFS="$(realpath -m build/rootfs)"
THEME_REPO="https://github.com/Inled-Pulsar-OS/MacTahoe-gtk-theme"
ICONS_REPO="https://github.com/Inled-Pulsar-OS/MacTahoe-icon-theme"
BUILD_DIR="build/themes"

echo "🎨 Configurando Tema MacTahoe, Iconos y GDM..."

# 1. Clonar repositorios si no existen
mkdir -p "$BUILD_DIR"
if [ ! -d "$BUILD_DIR/MacTahoe" ]; then
    echo "Clonando repositorio del tema GTK..."
    git clone "$THEME_REPO" "$BUILD_DIR/MacTahoe" --depth=1
fi
if [ ! -d "$BUILD_DIR/MacTahoe-Icons" ]; then
    echo "Clonando repositorio de iconos..."
    git clone "$ICONS_REPO" "$BUILD_DIR/MacTahoe-Icons" --depth=1
fi

# 2. Instalar temas e iconos DENTRO del rootfs
echo "Preparando archivos en el rootfs..."
cp -r "$BUILD_DIR/MacTahoe" "$ROOTFS/tmp/"
cp -r "$BUILD_DIR/MacTahoe-Icons" "$ROOTFS/tmp/"

# Instalación global GTK y GDM
echo "Aplicando temas GTK y GDM tweaks..."
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/MacTahoe && ./install.sh -b -c dark --silent-mode && ./tweaks.sh -g --silent-mode"

# Instalación global de ICONOS
echo "Instalando iconos MacTahoe..."
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/MacTahoe-Icons && ./install.sh -t blue"

# FIX AGRESIVO PARA LIBADWAITA (GTK4)
# En GNOME 42+, Libadwaita ignora dconf. Hay que copiar el CSS directamente a la carpeta config.
echo "Aplicando fix agresivo de Libadwaita (GTK4)..."
for TARGET in "/etc/skel" "/home/jaime" "/root"; do
    pkexec mkdir -p "$ROOTFS$TARGET/.config/gtk-4.0"
    pkexec cp -rf "$ROOTFS/usr/share/themes/MacTahoe-Dark/gtk-4.0/"* "$ROOTFS$TARGET/.config/gtk-4.0/" 2>/dev/null || true
done

# Corregir permisos para el usuario jaime
pkexec chown -R 1000:1000 "$ROOTFS/home/jaime/.config"

# 3. Configurar dconf para que el tema se aplique por defecto y activar extensiones
echo "Configurando dconf default y extensiones..."
pkexec mkdir -p "$ROOTFS/etc/dconf/db/local.d"
cat <<EOF | pkexec tee "$ROOTFS/etc/dconf/db/local.d/00-pulsaros-theme"
[org/gnome/desktop/interface]
gtk-theme='MacTahoe-Dark'
cursor-theme='MacTahoe-Dark'
icon-theme='MacTahoe'
color-scheme='prefer-dark'
font-name='Sans 11'

[org/gnome/shell/extensions/user-theme]
name='MacTahoe-Dark'

[org/gnome/shell]
enabled-extensions=['user-theme@gnome-shell-extensions.gcampax.github.com', 'dash-to-dock@micxgx.gmail.com', 'blur-my-shell@aunetx', 'search-light@icedman.github.com', 'moveclock@kuvaus.org', 'kiwimenu@kemma', 'compiz-alike-magic-lamp-effect@hermes83.github.com', 'fullscreen-to-empty-workspace2@corgijan.dev']

[org/gnome/shell/extensions/blur-my-shell/appfolder]
brightness=0.6
sigma=30

[org/gnome/shell/extensions/blur-my-shell/applications]
blur=true
blur-on-overview=false
corner-when-maximized=true
dynamic-opacity=false
enable-all=true
opacity=255
sigma=23

[org/gnome/shell/extensions/blur-my-shell/dash-to-dock]
blur=true
brightness=0.6
override-background=true
pipeline='pipeline_default_rounded'
sigma=30
static-blur=true
style-dash-to-dock=2
unblur-in-overview=true

[org/gnome/shell/extensions/blur-my-shell/panel]
brightness=0.6
corner-radius=0
force-light-text=false
sigma=30

[org/gnome/shell/extensions/blur-my-shell/window-list]
brightness=0.6
sigma=30
EOF

# Función para descargar extensiones que no están en repositorios
install_extension() {
    local uuid=$1
    echo "Instalando extensión: $uuid"
    pkexec mkdir -p "$ROOTFS/usr/share/gnome-shell/extensions/$uuid"
    # Nota: En una distro real, bajaríamos el zip de extensions.gnome.org
    # Por ahora, creamos la estructura para que GNOME las reconozca al instalarlas manualmente o vía extension-manager
}

# Lista de extensiones extra
EXTENSIONS=(
    "search-light@icedman.github.com"
    "moveclock@kuvaus.org"
    "kiwimenu@kemma"
    "compiz-alike-magic-lamp-effect@hermes83.github.com"
    "fullscreen-to-empty-workspace2@corgijan.dev"
)

for ext in "${EXTENSIONS[@]}"; do
    install_extension "$ext"
done

# Actualizar base de datos dconf
pkexec /usr/sbin/chroot "$ROOTFS" dconf update

# Limpiar
echo "Limpiando archivos temporales..."
pkexec rm -rf "$ROOTFS/tmp/MacTahoe"
pkexec rm -rf "$ROOTFS/tmp/MacTahoe-Icons"

echo "✅ Temas, Iconos, Extensiones y GDM configurados."
echo "💡 NOTA: Si la VM está encendida, reiníciala para aplicar todos los cambios (especialmente GTK4 y GDM)."
