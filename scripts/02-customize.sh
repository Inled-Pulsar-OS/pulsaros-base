#!/bin/bash
set -e
ROOTFS="$(realpath -m build/rootfs)"

if [ ! -d "$ROOTFS/etc" ]; then
    echo "Error: El rootfs no parece estar completo en $ROOTFS"
    exit 1
fi

# Función de limpieza para asegurar desmontaje
cleanup() {
    echo "🧹 Finalizando y liberando recursos..."
    pkexec umount -l "$ROOTFS/proc" || true
    pkexec umount -l "$ROOTFS/sys" || true
    pkexec umount -l "$ROOTFS/dev/pts" || true
    pkexec umount -l "$ROOTFS/dev" || true
    
    # Restaurar DNS original tras la instalación si quedó el backup
    if [ -f "$ROOTFS/etc/resolv.conf.bak" ]; then
        pkexec mv "$ROOTFS/etc/resolv.conf.bak" "$ROOTFS/etc/resolv.conf" || true
    fi
}
trap cleanup EXIT INT TERM

echo "--- Personalizando Distro (Branding) ---"

# Establecer nombre del host
echo "pulsaros" | pkexec tee "$ROOTFS/etc/hostname"

# Personalizar el mensaje de bienvenida (TTY)
echo "Welcome to PulsarOS Base (\n \l)" | pkexec tee "$ROOTFS/etc/issue"

# Asegurar directorios de configuración
pkexec mkdir -p "$ROOTFS/etc/network"
pkexec mkdir -p "$ROOTFS/etc/initramfs-tools"

# Configurar red básica
cat <<EOF | pkexec tee "$ROOTFS/etc/network/interfaces"
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Establecer contraseñas
echo "Configurando contraseñas..."
# Usamos un hash pre-generado para 'pulsar' para evitar fallos de PAM en chroot
echo "root:pulsar" | pkexec /usr/sbin/chroot "$ROOTFS" chpasswd || echo "Fallo chpasswd root, continuando..."

# Crear usuario 'jaime' si no existe
if ! pkexec /usr/sbin/chroot "$ROOTFS" id -u jaime >/dev/null 2>&1; then
    echo "Creando usuario 'jaime'..."
    pkexec /usr/sbin/chroot "$ROOTFS" useradd -m -s /bin/bash -G sudo jaime
fi
echo "jaime:pulsar" | pkexec /usr/sbin/chroot "$ROOTFS" chpasswd || echo "Fallo chpasswd jaime, continuando..."

# Crear usuario 'live' si no existe
if ! pkexec /usr/sbin/chroot "$ROOTFS" id -u live >/dev/null 2>&1; then
    echo "Creando usuario 'live'..."
    pkexec /usr/sbin/chroot "$ROOTFS" useradd -m -s /bin/bash -G sudo live
fi
echo "live:live" | pkexec /usr/sbin/chroot "$ROOTFS" chpasswd || echo "Fallo chpasswd live, continuando..."

# Configurar sudo sin contraseña para jaime y live
echo "Configurando sudo sin contraseña..."
echo "jaime ALL=(ALL) NOPASSWD:ALL" | pkexec tee "$ROOTFS/etc/sudoers.d/jaime"
echo "live ALL=(ALL) NOPASSWD:ALL" | pkexec tee "$ROOTFS/etc/sudoers.d/live"
pkexec chmod 0440 "$ROOTFS/etc/sudoers.d/jaime"
pkexec chmod 0440 "$ROOTFS/etc/sudoers.d/live"

# Configurar Polkit para pkexec sin contraseña (passthrough) para el grupo sudo
echo "Configurando reglas de Polkit para pkexec instantáneo..."
pkexec mkdir -p "$ROOTFS/etc/polkit-1/rules.d"
cat <<EOF | pkexec tee "$ROOTFS/etc/polkit-1/rules.d/90-pulsaros-nopasswd.rules"
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
EOF

# Modificar PAM para permitir passwords simples (opcional pero ayuda en desarrollo)
pkexec sed -i 's/nullok_secure/nullok/' "$ROOTFS/etc/pam.d/common-auth" || true

# Habilitar login en consola serie (QUITADO para evitar bucle)
echo "Deshabilitando getty en ttyS0 para evitar conflicto con GDM3..."
pkexec /usr/sbin/chroot "$ROOTFS" systemctl disable getty@ttyS0.service || true
pkexec /usr/sbin/chroot "$ROOTFS" systemctl mask getty@ttyS0.service || true

# Configurar Autologin Gráfico en GDM3
echo "Configurando autologin gráfico para live..."
pkexec mkdir -p "$ROOTFS/etc/gdm3"
cat <<EOF | pkexec tee "$ROOTFS/etc/gdm3/daemon.conf"
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=live
EOF


# Asegurar que el initramfs tenga soporte para 9pfs (necesario para arrancar desde carpeta)
echo "Añadiendo módulos 9p al initramfs..."
echo "9p
9pnet
9pnet_virtio" | pkexec tee -a "$ROOTFS/etc/initramfs-tools/modules"

# Regenerar initramfs para aplicar los cambios de módulos
pkexec /usr/sbin/chroot "$ROOTFS" /usr/sbin/update-initramfs -u

# --- Preparar entorno para instalaciones (Mounts) ---
echo "Montando sistemas de archivos virtuales..."
pkexec mount -t proc proc "$ROOTFS/proc" || true
pkexec mount -t sysfs sys "$ROOTFS/sys" || true
pkexec mount --bind /dev "$ROOTFS/dev" || true
pkexec mount --bind /dev/pts "$ROOTFS/dev/pts" || true

# Solución temporal para DNS (especialmente con VPN/WARP)
if [ -f "$ROOTFS/etc/resolv.conf" ]; then
    pkexec cp "$ROOTFS/etc/resolv.conf" "$ROOTFS/etc/resolv.conf.bak"
fi
echo "nameserver 8.8.8.8" | pkexec tee "$ROOTFS/etc/resolv.conf" > /dev/null

# --- Instalación de Software Adicional ---
echo "--- Instalando Software Adicional (Flatpak, AppInstall) ---"

# 1. Configurar Flathub
echo "Configurando Flathub..."
pkexec /usr/sbin/chroot "$ROOTFS" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# 2. Instalar Brave Browser
echo "Instalando Brave Browser..."
pkexec /usr/sbin/chroot "$ROOTFS" curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
pkexec /usr/sbin/chroot "$ROOTFS" curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
pkexec /usr/sbin/chroot "$ROOTFS" apt update
pkexec /usr/sbin/chroot "$ROOTFS" apt install -y brave-browser

# 3. Instalar Apps desde Flathub (OnlyOffice y LocalSend)
echo "Instalando OnlyOffice y LocalSend (esto puede tardar)..."
pkexec /usr/sbin/chroot "$ROOTFS" flatpak install --system -y flathub org.onlyoffice.desktopeditors
pkexec /usr/sbin/chroot "$ROOTFS" flatpak install --system -y flathub org.localsend.localsend_app

# 4. Descargar e Instalar AppInstall (DEB)
echo "Instalando AppInstall (Latest)..."
APPINSTALL_URL=$(curl -s https://api.github.com/repos/InledGroup/appinstall/releases/latest | jq -r '.assets[] | select(.name | endswith(".deb")) | .browser_download_url' | head -n 1)
pkexec wget -q -O "$ROOTFS/tmp/appinstall.deb" "$APPINSTALL_URL"
pkexec /usr/sbin/chroot "$ROOTFS" apt install -y /tmp/appinstall.deb
pkexec rm -f "$ROOTFS/tmp/appinstall.deb"

# 5. Descargar e Instalar Spotlight-GTK (DEB)
echo "Instalando Spotlight-GTK (Latest)..."
SPOTLIGHT_URL=$(curl -s https://api.github.com/repos/InledGroup/spotlight-gtk/releases/latest | jq -r '.assets[] | select(.name | endswith(".deb")) | .browser_download_url' | head -n 1)
pkexec wget -q -O "$ROOTFS/tmp/spotlight.deb" "$SPOTLIGHT_URL"
pkexec /usr/sbin/chroot "$ROOTFS" apt install -y /tmp/spotlight.deb
pkexec rm -f "$ROOTFS/tmp/spotlight.deb"

# 6. Descargar e Instalar MacBoat (DEB)
echo "Instalando MacBoat (Latest)..."
MACBOAT_URL=$(curl -s https://api.github.com/repos/InledGroup/macboat/releases/latest | jq -r '.assets[] | select(.name | endswith(".deb")) | .browser_download_url' | head -n 1)
pkexec wget -q -O "$ROOTFS/tmp/macboat.deb" "$MACBOAT_URL"
pkexec /usr/sbin/chroot "$ROOTFS" apt install -y /tmp/macboat.deb
pkexec rm -f "$ROOTFS/tmp/macboat.deb"

# 7. Descargar e Instalar WinBoat (DEB)
echo "Instalando WinBoat (Latest)..."
WINBOAT_URL=$(curl -s https://api.github.com/repos/TibixDev/winboat/releases/latest | jq -r '.assets[] | select(.name | endswith(".deb")) | .browser_download_url' | head -n 1)
pkexec wget -q -O "$ROOTFS/tmp/winboat.deb" "$WINBOAT_URL"
pkexec /usr/sbin/chroot "$ROOTFS" apt install -y /tmp/winboat.deb
pkexec rm -f "$ROOTFS/tmp/winboat.deb"

# 8. Asegurar grupo docker existe
echo "Asegurando grupo docker..."
pkexec /usr/sbin/chroot "$ROOTFS" groupadd -f docker

# 9. Establecer Brave como navegador predeterminado y renombrar Firefox a Safari
echo "Configurando navegadores..."
# Registrar Brave como alternativa (a veces el paquete no lo hace automáticamente en chroot)
pkexec /usr/sbin/chroot "$ROOTFS" update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/brave-browser 100
pkexec /usr/sbin/chroot "$ROOTFS" update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/bin/brave-browser 100
pkexec /usr/sbin/chroot "$ROOTFS" update-alternatives --set x-www-browser /usr/bin/brave-browser
pkexec /usr/sbin/chroot "$ROOTFS" update-alternatives --set gnome-www-browser /usr/bin/brave-browser

# Cambiar icono de Firefox a Safari
if [ -f "$ROOTFS/usr/share/applications/firefox-esr.desktop" ]; then
    pkexec sed -i 's/^Icon=.*/Icon=safari/' "$ROOTFS/usr/share/applications/firefox-esr.desktop"
fi

# Cambiar icono de Spotlight a "Aplicaciones Menu" (view-app-grid)
if [ -f "$ROOTFS/usr/share/applications/spotlight.desktop" ]; then
    pkexec sed -i 's/^Icon=.*/Icon=view-app-grid/' "$ROOTFS/usr/share/applications/spotlight.desktop"
fi

# --- Configuración de Idiomas (Locales) ---
echo "Configurando idiomas (Locales)..."
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "echo 'es_ES.UTF-8 UTF-8' >> /etc/locale.gen"
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen"
pkexec /usr/sbin/chroot "$ROOTFS" locale-gen
echo "LANG=es_ES.UTF-8" | pkexec tee "$ROOTFS/etc/default/locale"

# --- Renombrar Aplicaciones (Estilo macOS) ---
echo "Renombrando aplicaciones para mayor claridad..."

rename_app() {
    local desktop_file="$1"
    local new_name_en="$2"
    local new_name_es="$3"
    
    local path="$ROOTFS/usr/share/applications/$desktop_file"
    if [ -f "$path" ]; then
        pkexec sed -i "s/^Name=.*/Name=$new_name_en/" "$path"
        # Añadir traducción al español si no existe, o actualizarla
        if grep -q "^Name\[es\]=" "$path"; then
            pkexec sed -i "s/^Name\[es\]=.*/Name\[es\]=$new_name_es/" "$path"
        else
            echo "Name[es]=$new_name_es" | pkexec tee -a "$path" > /dev/null
        fi
    fi
}

# Lista de aplicaciones a renombrar
rename_app "firefox-esr.desktop" "Safari" "Safari"
rename_app "io.bassi.Amberol.desktop" "Music" "Música"
rename_app "org.gnome.Geary.desktop" "Mail" "Correo"
rename_app "com.github.xournalpp.xournalpp.desktop" "Whiteboard" "Pizarra"
rename_app "org.gnome.Loupe.desktop" "Photos" "Fotos"
rename_app "org.gnome.Calculator.desktop" "Calculator" "Calculadora"
rename_app "org.gnome.Calendar.desktop" "Calendar" "Calendario"
rename_app "org.gnome.Weather.desktop" "Weather" "Tiempo"
rename_app "org.gnome.clocks.desktop" "Clock" "Reloj"
rename_app "org.gnome.Music.desktop" "Music (Legacy)" "Música (Antigua)"
rename_app "org.gnome.font-viewer.desktop" "Fonts" "Tipografías"
rename_app "org.gnome.DiskUtility.desktop" "Disks" "Discos"
rename_app "gnome-system-monitor.desktop" "Activity Monitor" "Monitor de Actividad"
rename_app "org.gnome.Logs.desktop" "Logs" "Registros"
rename_app "org.gnome.Nautilus.desktop" "Files" "Archivos"

# --- Finalización ---
echo "Personalización completada."
