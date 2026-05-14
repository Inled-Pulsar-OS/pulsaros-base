#!/bin/bash
set -e
ROOTFS="$(realpath -m build/rootfs)"
THEME_REPO="https://github.com/Inled-Pulsar-OS/MacTahoe-gtk-theme"
ICONS_REPO="https://github.com/Inled-Pulsar-OS/MacTahoe-icon-theme"
BUILD_DIR="$(realpath -m build/themes)"

echo "🎨 Configurando Tema MacTahoe, Iconos y GDM..."

# 1. Clonar repositorios si no existen
mkdir -p "$BUILD_DIR"
if [ ! -d "$BUILD_DIR/MacTahoe/.git" ]; then
    echo "Clonando repositorio del tema GTK..."
    rm -rf "$BUILD_DIR/MacTahoe"
    git clone "$THEME_REPO" "$BUILD_DIR/MacTahoe" --depth=1
fi
if [ ! -d "$BUILD_DIR/MacTahoe-Icons/.git" ]; then
    echo "Clonando repositorio de iconos..."
    rm -rf "$BUILD_DIR/MacTahoe-Icons"
    git clone "$ICONS_REPO" "$BUILD_DIR/MacTahoe-Icons" --depth=1
fi

# 2. Instalar temas e iconos DENTRO del rootfs
echo "Preparando archivos en el rootfs..."
# Limpiamos primero con privilegios por si acaso
pkexec rm -rf "$ROOTFS/tmp/MacTahoe" "$ROOTFS/tmp/MacTahoe-Icons"

# Copiamos usando pkexec y rutas ABSOLUTAS
pkexec cp -r "$BUILD_DIR/MacTahoe" "$ROOTFS/tmp/"
pkexec cp -r "$BUILD_DIR/MacTahoe-Icons" "$ROOTFS/tmp/"

# Asegurar que el usuario jaime (UID 1000) puede leer los archivos temporales
pkexec chown -R 1000:1000 "$ROOTFS/tmp/MacTahoe"
pkexec chown -R 1000:1000 "$ROOTFS/tmp/MacTahoe-Icons"

# Instalación global GTK y GDM (Corremos como ROOT para permitir --silent-mode)
echo "Aplicando temas GTK..."
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/MacTahoe && ./install.sh -b -c dark -l --silent-mode"

echo "Aplicando GDM tweaks..."
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/MacTahoe && ./tweaks.sh -g --silent-mode"

# Instalación global de ICONOS
echo "Instalando iconos MacTahoe..."
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/MacTahoe-Icons && ./install.sh -t blue -d /usr/share/icons"

# FIX AGRESIVO PARA LIBADWAITA (GTK4)
# En GNOME 42+, Libadwaita ignora dconf. Hay que copiar el CSS directamente a la carpeta config.
# Como hemos corrido como root, los archivos de GTK4 están en /root/.config. 
echo "Distribuyendo fix agresivo de Libadwaita (GTK4)..."
for TARGET in "/etc/skel" "/home/jaime"; do
    pkexec mkdir -p "$ROOTFS$TARGET/.config/gtk-4.0"
    # Copiamos desde /root/.config/gtk-4.0 (generado por el instalador) 
    # y también aseguramos los archivos del tema global
    pkexec cp -rf "$ROOTFS/usr/share/themes/MacTahoe-Dark/gtk-4.0/"* "$ROOTFS$TARGET/.config/gtk-4.0/" 2>/dev/null || true
    pkexec cp -rf "$ROOTFS/root/.config/gtk-4.0/"* "$ROOTFS$TARGET/.config/gtk-4.0/" 2>/dev/null || true
done

# Corregir permisos para el usuario jaime (UID 1000)
pkexec chown -R 1000:1000 "$ROOTFS/home/jaime/.config"

# 3. Configurar dconf para que el tema se aplique por defecto y activar extensiones
echo "Configurando dconf default y extensiones..."
pkexec mkdir -p "$ROOTFS/etc/dconf/db/local.d"
cat <<EOF | pkexec tee "$ROOTFS/etc/dconf/db/local.d/00-pulsaros-theme"
[org/gnome/desktop/interface]
gtk-theme='MacTahoe-Dark'
cursor-theme='MacTahoe-blue-dark'
icon-theme='MacTahoe-blue-dark'
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

# Función para descargar e instalar extensiones de GNOME de forma real
install_extension() {
    local uuid=$1
    local url=$2
    echo "Instalando extensión: $uuid"
    
    # Crear directorio destino en el rootfs
    pkexec mkdir -p "$ROOTFS/usr/share/gnome-shell/extensions/$uuid"
    
    # Descargar en el host y copiar al rootfs
    if [ ! -z "$url" ]; then
        local tmp_zip="/tmp/$uuid.zip"
        if wget -qO "$tmp_zip" "$url"; then
            pkexec unzip -o "$tmp_zip" -d "$ROOTFS/usr/share/gnome-shell/extensions/$uuid"
            pkexec chmod -R 755 "$ROOTFS/usr/share/gnome-shell/extensions/$uuid"
            rm "$tmp_zip"
        else
            echo "⚠️ Fallo al descargar la extensión: $uuid"
        fi
    fi
}

# Lista de extensiones con sus URLs de descarga
install_extension "search-light@icedman.github.com" "https://github.com/icedman/search-light/releases/latest/download/search-light@icedman.github.com.shell-extension.zip"
install_extension "moveclock@kuvaus.org" "https://github.com/kuvaus/gnome-shell-extension-move-clock/archive/refs/heads/master.zip"
install_extension "compiz-alike-magic-lamp-effect@hermes83.github.com" "https://github.com/hermes83/compiz-alike-magic-lamp-effect/archive/refs/heads/master.zip"
# Para las que no tienen zip directo fácil, el registro ya está en dconf

# Actualizar base de datos dconf
pkexec /usr/sbin/chroot "$ROOTFS" dconf update

# Limpiar
echo "Limpiando archivos temporales..."
pkexec rm -rf "$ROOTFS/tmp/MacTahoe"
pkexec rm -rf "$ROOTFS/tmp/MacTahoe-Icons"

echo "✅ Temas, Iconos, Extensiones y GDM configurados."
echo "💡 NOTA: Si la VM está encendida, reiníciala para aplicar todos los cambios (especialmente GTK4 y GDM)."
