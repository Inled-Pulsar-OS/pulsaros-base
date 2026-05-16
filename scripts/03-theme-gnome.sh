#!/bin/bash
set -e
ROOTFS="$(realpath -m build/rootfs)"
THEME_REPO="https://github.com/Inled-Pulsar-OS/MacTahoe-gtk-theme"
ICONS_REPO="https://github.com/Inled-Pulsar-OS/MacTahoe-icon-theme"
FILDEM_REPO="https://github.com/InledGroup/Fildem"
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

echo "🎨 Configurando Tema MacTahoe, Iconos, GDM y Fildem HUD..."

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
if [ ! -d "$BUILD_DIR/Fildem/.git" ]; then
    echo "Clonando repositorio de Fildem HUD..."
    rm -rf "$BUILD_DIR/Fildem"
    git clone "$FILDEM_REPO" "$BUILD_DIR/Fildem" --depth=1
fi

# 2. Instalar temas e iconos DENTRO del rootfs
echo "Preparando archivos en el rootfs..."
pkexec rm -rf "$ROOTFS/tmp/MacTahoe" "$ROOTFS/tmp/MacTahoe-Icons" "$ROOTFS/tmp/Fildem"
pkexec cp -r "$BUILD_DIR/MacTahoe" "$ROOTFS/tmp/"
pkexec cp -r "$BUILD_DIR/MacTahoe-Icons" "$ROOTFS/tmp/"
pkexec cp -r "$BUILD_DIR/Fildem" "$ROOTFS/tmp/"

# Asegurar que el usuario jaime (UID 1000) puede leer los archivos temporales
pkexec chown -R 1000:1000 "$ROOTFS/tmp/MacTahoe"
pkexec chown -R 1000:1000 "$ROOTFS/tmp/MacTahoe-Icons"
pkexec chown -R 1000:1000 "$ROOTFS/tmp/Fildem"

# --- Preparar entorno (Mounts) ---
echo "Montando sistemas de archivos virtuales..."
pkexec mount -t proc proc "$ROOTFS/proc" || true
pkexec mount -t sysfs sys "$ROOTFS/sys" || true
pkexec mount --bind /dev "$ROOTFS/dev" || true
pkexec mount --bind /dev/pts "$ROOTFS/dev/pts" || true

# Descargar fondo de pantalla por defecto
echo "Descargando fondo de pantalla Pulsar OS..."
pkexec mkdir -p "$ROOTFS/usr/share/backgrounds"
pkexec wget -q -O "$ROOTFS/usr/share/backgrounds/pulsar-os-tahoe.png" "https://raw.githubusercontent.com/Inled-Pulsar-OS/pulsar-art/refs/heads/main/pulsar-os-tahoe.png"

# Instalación global GTK y GDM (Corremos como ROOT para permitir --silent-mode)
echo "Aplicando temas GTK..."
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/MacTahoe && ./install.sh -b -c dark -l --silent-mode"

echo "Aplicando GDM tweaks..."
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/MacTahoe && ./tweaks.sh -g --silent-mode"

echo "Preparando perfiles de Firefox para el tema MacTahoe..."
for USER_HOME in "/root" "/home/jaime" "/etc/skel"; do
    pkexec mkdir -p "$ROOTFS$USER_HOME/.mozilla/firefox/pulsar.default"
    cat <<EOF | pkexec tee "$ROOTFS$USER_HOME/.mozilla/firefox/profiles.ini" > /dev/null
[General]
StartWithLastProfile=1

[Profile0]
Name=default
IsRelative=1
Path=pulsar.default
Default=1
EOF
done
pkexec chown -R 1000:1000 "$ROOTFS/home/jaime/.mozilla"

# PARCHE: Eliminar la llamada a full_sudo que bloquea el modo silent en chroot
pkexec sed -i 's/full_sudo "${1}"; silent_mode/silent_mode/g' "$ROOTFS/tmp/MacTahoe/tweaks.sh"

# PARCHE AGRESIVO: Forzar que el script ignore si Firefox está "inicializado"
# pkexec sed -i 's/elif \[\[ ! -d "${FIREFOX_DIR_HOME}" && ! -d "${FIREFOX_FLATPAK_DIR_HOME}" && ! -d "${FIREFOX_SNAP_DIR_HOME}" \]\]; then/elif false; then/g' "$ROOTFS/tmp/MacTahoe/tweaks.sh"

echo "Aplicando Firefox MacTahoe theme..."
# Ejecutamos para root y para jaime
# pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/MacTahoe && ./tweaks.sh -f --silent-mode"
# pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/MacTahoe && sudo -u jaime ./tweaks.sh -f --silent-mode"

# Instalación global de ICONOS
echo "Instalando iconos MacTahoe..."
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/MacTahoe-Icons && ./install.sh -t blue -d /usr/share/icons"

# Instalación de Fildem HUD
echo "Instalando Fildem HUD (App y Extension)..."
# PARCHE: Corregir bug de detección de Wayland en Fildem que provoca crash si las variables no están seteadas
pkexec sed -i "s/return 'wayland' in (disp or type)/return 'wayland' in (disp or type or '')/" "$ROOTFS/tmp/Fildem/fildem/utils/wayland.py"
pkexec sed -i "s/os.environ\['XDG_SESSION_TYPE'\]/os.environ.get('XDG_SESSION_TYPE', '')/g" "$ROOTFS/tmp/Fildem/fildem/run.py"

# PARCHE: Corregir instalación de Fildem usando setup.py correctamente
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "cd /tmp/Fildem && python3 setup.py install"

# Asegurar que el binario de fildem sea reconocido forzando un symlink si es necesario
pkexec /usr/sbin/chroot "$ROOTFS" ln -sf /usr/local/bin/fildem /usr/bin/fildem || true
pkexec /usr/sbin/chroot "$ROOTFS" ln -sf /usr/local/bin/fildem-hud /usr/bin/fildem-hud || true

# Configurar el servicio systemd de fildem de forma global para todos los usuarios
echo "Configurando Fildem HUD Systemd Service..."
pkexec mkdir -p "$ROOTFS/usr/lib/systemd/user/default.target.wants"
pkexec cp "$ROOTFS/tmp/Fildem/fildem.service" "$ROOTFS/usr/lib/systemd/user/"
pkexec ln -sf "/usr/lib/systemd/user/fildem.service" "$ROOTFS/usr/lib/systemd/user/default.target.wants/fildem.service"

# Instalar la extensión globalmente en lugar de localmente
pkexec mkdir -p "$ROOTFS/usr/share/gnome-shell/extensions/fildem@inled.es"
pkexec cp -r "$ROOTFS/tmp/Fildem/fildem@inled.es/"* "$ROOTFS/usr/share/gnome-shell/extensions/fildem@inled.es/"
pkexec /usr/sbin/chroot "$ROOTFS" glib-compile-schemas "/usr/share/gnome-shell/extensions/fildem@inled.es/schemas/"

# Configurar GTK Modules para Fildem (Global)
echo "Configurando GTK Modules para Fildem..."
pkexec mkdir -p "$ROOTFS/etc/gtk-3.0"
cat <<EOF | pkexec tee "$ROOTFS/etc/gtk-3.0/settings.ini"
[Settings]
gtk-modules=appmenu-gtk-module
EOF

pkexec mkdir -p "$ROOTFS/etc/gtk-2.0"
echo 'gtk-modules="appmenu-gtk-module"' | pkexec tee "$ROOTFS/etc/gtk-2.0/gtkrc"

# Replicar en skel y home/jaime
for TARGET in "/etc/skel" "/home/jaime"; do
    pkexec mkdir -p "$ROOTFS$TARGET/.config/gtk-3.0"
    pkexec cp "$ROOTFS/etc/gtk-3.0/settings.ini" "$ROOTFS$TARGET/.config/gtk-3.0/settings.ini"
    pkexec cp "$ROOTFS/etc/gtk-2.0/gtkrc" "$ROOTFS$TARGET/.gtkrc-2.0"
done

# Configurar Autostart para Fildem
echo "Configurando autostart para Fildem..."
pkexec mkdir -p "$ROOTFS/etc/xdg/autostart"
cat <<EOF | pkexec tee "$ROOTFS/etc/xdg/autostart/fildem.desktop"
[Desktop Entry]
Type=Application
Exec=fildem
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Fildem HUD
Comment=Global Menu and HUD
EOF

# FIX AGRESIVO PARA LIBADWAITA (GTK4)
echo "Distribuyendo fix agresivo de Libadwaita (GTK4)..."
for TARGET in "/etc/skel" "/home/jaime"; do
    pkexec mkdir -p "$ROOTFS$TARGET/.config/gtk-4.0"
    pkexec cp -rf "$ROOTFS/usr/share/themes/MacTahoe-Dark/gtk-4.0/"* "$ROOTFS$TARGET/.config/gtk-4.0/" 2>/dev/null || true
    pkexec cp -rf "$ROOTFS/root/.config/gtk-4.0/"* "$ROOTFS$TARGET/.config/gtk-4.0/" 2>/dev/null || true
done
pkexec chown -R 1000:1000 "$ROOTFS/home/jaime/.config"

# --- SISTEMA DE DESCARGA DE EXTENSIONES DESDE extensions.gnome.org ---
GNOME_VER=$(pkexec /usr/sbin/chroot "$ROOTFS" gnome-shell --version | cut -d' ' -f3 | cut -d'.' -f1)
echo "Detectada versión de GNOME: $GNOME_VER"

install_extension_ego() {
    local uuid=$1
    echo "Instalando desde EGO: $uuid"
    local info_url="https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${GNOME_VER}"
    local download_path=$(curl -s "$info_url" | jq -r '.download_url')

    if [ "$download_path" != "null" ] && [ ! -z "$download_path" ]; then
        local full_url="https://extensions.gnome.org${download_path}"
        echo "Descargando: $full_url"
        local tmp_zip="/tmp/${uuid}.zip"
        if curl -L -s -o "$tmp_zip" "$full_url"; then
            pkexec mkdir -p "$ROOTFS/usr/share/gnome-shell/extensions/${uuid}"
            pkexec unzip -o "$tmp_zip" -d "$ROOTFS/usr/share/gnome-shell/extensions/${uuid}"
            pkexec chmod -R 755 "$ROOTFS/usr/share/gnome-shell/extensions/${uuid}"
            rm "$tmp_zip"
            echo "✅ $uuid instalada correctamente."
        fi
    else
        echo "⚠️ No se encontró versión compatible en EGO para $uuid"
    fi
}

EGO_EXTENSIONS=(
    "search-light@icedman.github.com"
    "kiwimenu@kemma"
    "compiz-alike-magic-lamp-effect@hermes83.github.com"
    "fullscreen-to-empty-workspace2@corgijan.dev"
    "blur-my-shell@aunetx"
    "dash-to-dock@micxgx.gmail.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "appmenu-is-back@fthx"
    "just-perfection-desktop@just-perfection"
    "appindicatorsupport@rgcjonas.gmail.com"
)
for uuid in "${EGO_EXTENSIONS[@]}"; do install_extension_ego "$uuid"; done

# Compilar esquemas de las extensiones instaladas
echo "Compilando esquemas de extensiones..."
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "find /usr/share/gnome-shell/extensions -name schemas -type d -exec glib-compile-schemas {} \;"

# --- NUEVO MÉTODO: GSCHEMA OVERRIDE (Más fiable para Debian) ---
echo "Configurando gschema overrides para forzar extensiones, fondo y ajustes..."
# Priorizamos fildem@inled.es
EXTENSIONS_LIST="['user-theme@gnome-shell-extensions.gcampax.github.com', 'dash-to-dock@micxgx.gmail.com', 'blur-my-shell@aunetx', 'search-light@icedman.github.com', 'kiwimenu@kemma', 'compiz-alike-magic-lamp-effect@hermes83.github.com', 'fullscreen-to-empty-workspace2@corgijan.dev', 'just-perfection-desktop@just-perfection', 'fildem@inled.es', 'appmenu-is-back@fthx', 'appindicatorsupport@rgcjonas.gmail.com']"
FAVORITES_LIST="['firefox-esr.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Geary.desktop', 'org.gnome.Calendar.desktop', 'org.gnome.Calculator.desktop', 'com.github.xournalpp.xournalpp.desktop', 'org.gnome.Loupe.desktop', 'io.bassi.Amberol.desktop', 'org.gnome.clocks.desktop', 'org.gnome.Weather.desktop', 'org.gnome.Software.desktop']"

cat <<EOF | pkexec tee "$ROOTFS/usr/share/glib-2.0/schemas/90_pulsaros.gschema.override"
[org.gnome.shell]
enabled-extensions=$EXTENSIONS_LIST
favorite-apps=$FAVORITES_LIST
disable-extension-version-validation=true

[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/pulsar-os-tahoe.png'
picture-uri-dark='file:///usr/share/backgrounds/pulsar-os-tahoe.png'
picture-options='zoom'

[org.gnome.desktop.screensaver]
picture-uri='file:///usr/share/backgrounds/pulsar-os-tahoe.png'
picture-options='zoom'

[org.gnome.desktop.interface]
gtk-theme='MacTahoe-Dark'
cursor-theme='MacTahoe-blue-dark'
icon-theme='MacTahoe-blue-dark'
color-scheme='prefer-dark'

[org.gnome.desktop.wm.preferences]
button-layout='close,minimize,maximize:'

[org.gnome.shell.extensions.dash-to-dock]
dock-position='BOTTOM'
extend-height=false
dash-max-icon-size=48
click-action='minimize-or-previews'
running-indicator-style='DOTS'
intellihide=true
dock-fixed=false
transparency-mode='FIXED'
background-opacity=0.2
custom-theme-shrink=true
show-apps-at-top=true
show-trash=true
# Habilitar el anclaje y movimiento de iconos
move-to-monitor=true

[org.gnome.shell.extensions.just-perfection]
activities-button=false
app-menu=false
clock-menu-position=1
clock-menu-position-offset=12
clock-menu-visibility=true
workspace-indicator=false
panel-height=32
panel-button-padding-size=10
panel-indicator-padding-size=10
animation-speed=200
startup-status=0
dash-icon-size=0

[org.gnome.shell.extensions.kiwimenu]
activity-menu-visibility=false
icon=10

[org.gnome.shell.extensions.blur-my-shell.appfolder]
brightness=0.6
sigma=30

[org.gnome.shell.extensions.blur-my-shell.applications]
blur=true
blur-on-overview=false
corner-when-maximized=true
dynamic-opacity=false
enable-all=true
opacity=255
sigma=23

[org.gnome.shell.extensions.blur-my-shell.dash-to-dock]
blur=true
brightness=0.6
override-background=true
pipeline='pipeline_default_rounded'
sigma=30
static-blur=true
style-dash-to-dock=2
unblur-in-overview=true

[org.gnome.shell.extensions.blur-my-shell.panel]
brightness=0.6
corner-radius=0
force-light-text=false
sigma=30

[org.gnome.shell.extensions.blur-my-shell.window-list]
brightness=0.6
sigma=30
EOF

pkexec /usr/sbin/chroot "$ROOTFS" glib-compile-schemas /usr/share/glib-2.0/schemas/

# 3. Mantener dconf como backup de seguridad
echo "Configurando dconf default..."
pkexec mkdir -p "$ROOTFS/etc/dconf/db/local.d"
cat <<EOF | pkexec tee "$ROOTFS/etc/dconf/db/local.d/00-pulsaros-theme"
[org/gnome/desktop/interface]
gtk-theme='MacTahoe-Dark'
cursor-theme='MacTahoe-blue-dark'
icon-theme='MacTahoe-blue-dark'
color-scheme='prefer-dark'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/pulsar-os-tahoe.png'
picture-uri-dark='file:///usr/share/backgrounds/pulsar-os-tahoe.png'

[org/gnome/desktop/wm/preferences]
button-layout='close,minimize,maximize:'

[org/gnome/shell/extensions/user-theme]
name='MacTahoe-Dark'

[org/gnome/shell]
enabled-extensions=$EXTENSIONS_LIST
favorite-apps=$FAVORITES_LIST
disable-extension-version-validation=true

[org/gnome/shell/extensions/dash-to-dock]
dock-position='BOTTOM'
extend-height=false
dash-max-icon-size=48
click-action='minimize-or-previews'
running-indicator-style='DOTS'
intellihide=true
dock-fixed=false
transparency-mode='FIXED'
background-opacity=0.2
custom-theme-shrink=true
show-apps-at-top=true
show-trash=true
move-to-monitor=true

[org/gnome/shell/extensions/just-perfection]
activities-button=false
app-menu=false
clock-menu-position=1
clock-menu-position-offset=12
clock-menu-visibility=true
workspace-indicator=false
panel-height=32
panel-button-padding-size=10
panel-indicator-padding-size=10
animation-speed=200
startup-status=0
dash-icon-size=0

[org/gnome/shell/extensions/kiwimenu]
activity-menu-visibility=false
icon=10

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

pkexec /usr/sbin/chroot "$ROOTFS" dconf update

# 4. Bloquear configuraciones críticas (Locks) para evitar que se desactiven
echo "Bloqueando configuraciones críticas (Locks)..."
pkexec mkdir -p "$ROOTFS/etc/dconf/db/local.d/locks"
cat <<EOF | pkexec tee "$ROOTFS/etc/dconf/db/local.d/locks/00-pulsaros-theme"
/org/gnome/shell/enabled-extensions
/org/gnome/shell/disable-extension-version-validation
/org/gnome/desktop/background/picture-uri
/org/gnome/desktop/background/picture-uri-dark
/org/gnome/desktop/wm/preferences/button-layout
EOF

pkexec /usr/sbin/chroot "$ROOTFS" dconf update

# --- Finalización ---
echo "Limpiando archivos temporales..."
pkexec rm -rf "$ROOTFS/tmp/MacTahoe" "$ROOTFS/tmp/MacTahoe-Icons" "$ROOTFS/tmp/Fildem"
echo "✅ Pulsar OS Personalizado."
