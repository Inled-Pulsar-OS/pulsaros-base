#!/bin/bash
set -e
ROOTFS="$(realpath -m build/rootfs)"

if [ ! -d "$ROOTFS/etc" ]; then
    echo "Error: El rootfs no parece estar completo en $ROOTFS"
    exit 1
fi

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
# El hash de 'pulsar' es $6$rounds=4096$salt$Z.X.Z. (ejemplo simplificado, mejor usar chpasswd con --root si disponible)
echo "root:pulsar" | pkexec /usr/sbin/chroot "$ROOTFS" chpasswd || echo "Fallo chpasswd root, continuando..."

# Crear usuario 'jaime' si no existe
if ! pkexec /usr/sbin/chroot "$ROOTFS" id -u jaime >/dev/null 2>&1; then
    echo "Creando usuario 'jaime'..."
    pkexec /usr/sbin/chroot "$ROOTFS" useradd -m -s /bin/bash -G sudo jaime
fi
echo "jaime:pulsar" | pkexec /usr/sbin/chroot "$ROOTFS" chpasswd || echo "Fallo chpasswd jaime, continuando..."

# Configurar sudo
echo "jaime ALL=(ALL) NOPASSWD:ALL" | pkexec tee "$ROOTFS/etc/sudoers.d/jaime"
pkexec chmod 0440 "$ROOTFS/etc/sudoers.d/jaime"

# Modificar PAM para permitir passwords simples (opcional pero ayuda en desarrollo)
pkexec sed -i 's/nullok_secure/nullok/' "$ROOTFS/etc/pam.d/common-auth" || true

# Habilitar login en consola serie (QUITADO para evitar bucle)
echo "Deshabilitando getty en ttyS0 para evitar conflicto con GDM3..."
pkexec /usr/sbin/chroot "$ROOTFS" systemctl disable getty@ttyS0.service || true
pkexec /usr/sbin/chroot "$ROOTFS" systemctl mask getty@ttyS0.service || true

# Configurar Autologin Gráfico en GDM3
echo "Configurando autologin gráfico para jaime..."
pkexec mkdir -p "$ROOTFS/etc/gdm3"
cat <<EOF | pkexec tee "$ROOTFS/etc/gdm3/daemon.conf"
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=jaime
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

# --- Instalación de Software Adicional ---
echo "--- Instalando Software Adicional (Flatpak, AppInstall) ---"

# 1. Configurar Flathub
echo "Configurando Flathub..."
pkexec /usr/sbin/chroot "$ROOTFS" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# 2. Instalar Apps desde Flathub (OnlyOffice y LocalSend)
echo "Instalando OnlyOffice y LocalSend (esto puede tardar)..."
pkexec /usr/sbin/chroot "$ROOTFS" flatpak install --system -y flathub org.onlyoffice.desktopeditors
pkexec /usr/sbin/chroot "$ROOTFS" flatpak install --system -y flathub org.localsend.localsend_app

# 3. Descargar e Instalar AppInstall (DEB)
echo "Instalando AppInstall..."
APPINSTALL_URL="https://github.com/InledGroup/appinstall/releases/download/v11.0/appinstall_11.0_all.deb"
pkexec wget -q -O "$ROOTFS/tmp/appinstall.deb" "$APPINSTALL_URL"
pkexec /usr/sbin/chroot "$ROOTFS" apt install -y /tmp/appinstall.deb
pkexec rm -f "$ROOTFS/tmp/appinstall.deb"

# 4. Establecer Firefox como navegador predeterminado
echo "Estableciendo Firefox como predeterminado..."
pkexec /usr/sbin/chroot "$ROOTFS" update-alternatives --set x-www-browser /usr/bin/firefox-esr

# --- Desmontar sistemas de archivos virtuales ---
echo "Desmontando sistemas de archivos virtuales..."
pkexec umount -l "$ROOTFS/proc" || true
pkexec umount -l "$ROOTFS/sys" || true
pkexec umount -l "$ROOTFS/dev/pts" || true
pkexec umount -l "$ROOTFS/dev" || true

echo "Personalización completada."
