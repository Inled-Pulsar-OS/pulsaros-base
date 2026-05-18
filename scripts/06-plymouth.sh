#!/bin/bash
set -e

# Obtener la ruta absoluta del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ROOTFS="$(realpath -m "$PROJECT_ROOT/build/rootfs")"
THEME_REPO="https://github.com/Inled-Pulsar-OS/plymouth-macoslike"
BUILD_DIR="$(realpath -m "$PROJECT_ROOT/build/themes")"

# Función de limpieza para asegurar desmontaje
cleanup() {
    echo "🧹 Finalizando y liberando recursos..."
    pkexec umount -l "$ROOTFS/proc" || true
    pkexec umount -l "$ROOTFS/sys" || true
    pkexec umount -l "$ROOTFS/dev/pts" || true
    pkexec umount -l "$ROOTFS/dev" || true
}
trap cleanup EXIT INT TERM

echo "--- Instalando y Configurando Pulsar Plymouth Theme ---"

# 1. Clonar el tema si no existe
mkdir -p "$BUILD_DIR"
if [ -d "$BUILD_DIR/plymouth-theme" ]; then
    echo "Actualizando repositorio del tema Plymouth..."
    cd "$BUILD_DIR/plymouth-theme" && git pull
    cd "$PROJECT_ROOT"
else
    echo "Clonando repositorio del tema Plymouth..."
    git clone "$THEME_REPO" "$BUILD_DIR/plymouth-theme" --depth=1
fi

# 2. Inyectar el tema en el rootfs
echo "Copiando tema al rootfs..."
PLYMOUTH_THEME_DEST="$ROOTFS/usr/share/plymouth/themes/pulsar-plymouth"
pkexec mkdir -p "$PLYMOUTH_THEME_DEST"
pkexec cp -r "$BUILD_DIR/plymouth-theme/." "$PLYMOUTH_THEME_DEST/"

# --- Preparar entorno (Mounts) ---
echo "Montando sistemas de archivos virtuales..."
pkexec mount -t proc proc "$ROOTFS/proc" || true
pkexec mount -t sysfs sys "$ROOTFS/sys" || true
pkexec mount --bind /dev "$ROOTFS/dev" || true
pkexec mount --bind /dev/pts "$ROOTFS/dev/pts" || true

# 3. Configurar el tema como predeterminado
echo "Configurando Pulsar Plymouth Theme como predeterminado..."
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c '
    export PATH=$PATH:/usr/sbin
    # Instalar plymouth y sus plugins necesarios
    apt-get update
    apt-get install -y plymouth plymouth-themes plymouth-label plymouth-x11 || apt-get install -y plymouth
    
    # Configurar Plymouth para que no tenga retardo
    mkdir -p /etc/plymouth
    echo -e "[Daemon]\nTheme=pulsar-plymouth\nShowDelay=0\nDeviceTimeout=8" > /etc/plymouth/plymouthd.conf
    
    # Verificar si el plugin two-step existe
    if [ ! -f "/usr/lib/x86_64-linux-gnu/plymouth/two-step.so" ] && [ ! -f "/usr/lib/plymouth/two-step.so" ]; then
        echo "⚠️ Advertencia: two-step.so no encontrado. El tema podría no funcionar."
    fi
    
    # Registrar el tema en update-alternatives
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/pulsar-plymouth/pulsar-plymouth.plymouth 150
    
    # Establecer el tema
    plymouth-set-default-theme -R pulsar-plymouth || {
        echo "Aviso: plymouth-set-default-theme falló, configurando manualmente..."
        update-alternatives --set default.plymouth /usr/share/plymouth/themes/pulsar-plymouth/pulsar-plymouth.plymouth
    }

    # Configurar GRUB para que use splash y sea silencioso
    if [ -f "/etc/default/grub" ]; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub
        update-grub || echo "Aviso: update-grub falló (esperado en chroot sin dispositivos reales)"
    fi
    
    # Forzar actualización de initramfs
    if command -v update-initramfs >/dev/null; then
        update-initramfs -u
    fi
    
    apt-get clean
'

echo "✅ Pulsar Plymouth Theme configurado correctamente."
