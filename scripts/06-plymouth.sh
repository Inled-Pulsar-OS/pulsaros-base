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

echo "--- Instalando Pulsar Plymouth Theme (Local) ---"

# 1. Definir origen y destino
PLYMOUTH_THEME_SRC="$PROJECT_ROOT/pulsar-plymouth-macos"
PLYMOUTH_THEME_DEST="$ROOTFS/usr/share/plymouth/themes/pulsar-plymouth"

if [ ! -d "$PLYMOUTH_THEME_SRC" ]; then
    echo "❌ Error: No se encontró el tema en $PLYMOUTH_THEME_SRC"
    exit 1
fi

# 2. Inyectar el tema en el rootfs
echo "Copiando tema al rootfs..."
pkexec mkdir -p "$PLYMOUTH_THEME_DEST"
pkexec cp -r "$PLYMOUTH_THEME_SRC/." "$PLYMOUTH_THEME_DEST/"

# Eliminar logo de Debian persistente en Plymouth
echo "Eliminando logo de Debian en el Splash..."
pkexec mkdir -p "$ROOTFS/usr/share/plymouth"
# Crear una imagen transparente de 1x1 para sustituir al logo de Debian
pkexec convert -size 1x1 xc:transparent "$ROOTFS/usr/share/plymouth/debian-logo.png" || true
# Algunos temas usan estas rutas, las cubrimos todas
pkexec cp "$ROOTFS/usr/share/plymouth/debian-logo.png" "$ROOTFS/usr/share/plymouth/themes/debian-logo.png" || true
pkexec cp "$ROOTFS/usr/share/plymouth/debian-logo.png" "$ROOTFS/usr/share/plymouth/logo.png" || true
pkexec cp "$ROOTFS/usr/share/plymouth/debian-logo.png" "$ROOTFS/usr/share/pixmaps/debian-logo.png" || true

# Sobrescribir logos de temas instalados por defecto para evitar que se peguen
for theme_logo in $(pkexec find "$ROOTFS/usr/share/plymouth/themes" -name "logo.png"); do
    pkexec cp "$ROOTFS/usr/share/plymouth/debian-logo.png" "$theme_logo"
done

# Asegurar que header-image.png esté en la carpeta images/ (el módulo two-step lo busca allí)
# Aunque ya lo hemos corregido en el repo, esto lo hace robusto
if [ -f "$PLYMOUTH_THEME_DEST/header-image.png" ]; then
    pkexec mv "$PLYMOUTH_THEME_DEST/header-image.png" "$PLYMOUTH_THEME_DEST/images/header-image.png"
fi

# --- Preparar entorno (Mounts) ---
echo "Montando sistemas de archivos virtuales..."
pkexec mount -t proc proc "$ROOTFS/proc" || true
pkexec mount -t sysfs sys "$ROOTFS/sys" || true
pkexec mount --bind /dev "$ROOTFS/dev" || true
pkexec mount --bind /dev/pts "$ROOTFS/dev/pts" || true

# 3. Configurar el tema como predeterminado
echo "Configurando Pulsar Plymouth Theme..."
pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c '
    export PATH=$PATH:/usr/sbin
    # Instalar plymouth y sus plugins necesarios
    apt-get update
    apt-get install -y plymouth plymouth-themes plymouth-label plymouth-x11 || apt-get install -y plymouth
    
    # Configurar Plymouth para que no tenga retardo
    mkdir -p /etc/plymouth
    echo -e "[Daemon]\nTheme=pulsar-plymouth\nShowDelay=0\nDeviceTimeout=8" > /etc/plymouth/plymouthd.conf
    
    # Verificar si el plugin two-step existe (diagnóstico vital)
    if [ ! -f "/usr/lib/x86_64-linux-gnu/plymouth/two-step.so" ] && [ ! -f "/usr/lib/plymouth/two-step.so" ]; then
        echo "⚠️ Advertencia: two-step.so no encontrado. El tema podría no funcionar."
    fi

    # Registrar el tema en update-alternatives
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/pulsar-plymouth/pulsar-plymouth.plymouth 150
    
    # Establecer el tema
    update-alternatives --set default.plymouth /usr/share/plymouth/themes/pulsar-plymouth/pulsar-plymouth.plymouth
    plymouth-set-default-theme -R pulsar-plymouth || plymouth-set-default-theme pulsar-plymouth
    
    # Configurar GRUB para que use splash y sea silencioso
    if [ -f "/etc/default/grub" ]; then
        sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\"/" /etc/default/grub
    fi
    
    # Forzar actualización de initramfs (algunas distros no lo hacen con plymouth-set-default-theme)
    if command -v update-initramfs >/dev/null; then
        update-initramfs -u
    fi
    
    apt-get clean
'

echo "✅ Pulsar Plymouth Theme instalado."
