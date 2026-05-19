#!/bin/bash
set -e

# Obtener la ruta absoluta del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ROOTFS="$(realpath -m "$PROJECT_ROOT/build/rootfs")"
PULSAR_LOGO="$PROJECT_ROOT/build/assets/pulsar-logo.png"
TRANSPARENT_LOGO="$PROJECT_ROOT/build/assets/transparent.png"

# Asegurar que el logo transparente existe
if [ ! -f "$TRANSPARENT_LOGO" ]; then
    python3 -c "from PIL import Image; img = Image.new('RGBA', (1, 1), (0, 0, 0, 0)); img.save('$TRANSPARENT_LOGO')" || \
    convert -size 1x1 xc:transparent "$TRANSPARENT_LOGO"
fi

echo "--- EXTERMINIO TOTAL DE LOGOS DE DEBIAN Y CONFIGURACIÓN PULSAR OS 13 ---"

# 1. Identidad del Sistema (About GNOME)
echo "Configurando Identidad: Pulsar OS 13"
pkexec tee "$ROOTFS/etc/os-release" "$ROOTFS/usr/lib/os-release" <<EOF > /dev/null
PRETTY_NAME="Pulsar OS 13"
NAME="Pulsar OS"
VERSION_ID="13"
VERSION="13"
ID=pulsaros
ID_LIKE=debian
HOME_URL="https://inled.es"
SUPPORT_URL="https://inled.es"
BUG_REPORT_URL="https://inled.es"
ANSI_COLOR="0;31"
LOGO="pulsar-logo"
EOF

# 2. Reemplazo de Logos en GDM y About (Usar Logo de Pulsar)
echo "Aplicando Logo de Pulsar a GDM y GNOME..."
VENDOR_LOGOS_DIR="/usr/share/images/vendor-logos"
DEBIAN_LOGOS_DIR="/usr/share/desktop-base/debian-logos"

# Machacar logos de vendor y logos de desktop-base
for dir in "$VENDOR_LOGOS_DIR" "$DEBIAN_LOGOS_DIR"; do
    if [ -d "$ROOTFS$dir" ]; then
        find "$ROOTFS$dir" -type f \( -name "*.png" -o -name "*.svg" \) 2>/dev/null | while read -r path; do
            pkexec rm -f "$path"
            pkexec cp "$PULSAR_LOGO" "$path"
        done
    fi
done

# 3. Plymouth Splash (MODO SIN LOGOS)
echo "Limpiando logos de Plymouth (Modo Sin Logos)..."
# Reemplazamos el logo por defecto de Debian por uno transparente
pkexec rm -f "$ROOTFS/usr/share/plymouth/debian-logo.png"
pkexec cp "$TRANSPARENT_LOGO" "$ROOTFS/usr/share/plymouth/debian-logo.png"

# Buscar cualquier otro logo en temas de Plymouth y hacerlo transparente
find "$ROOTFS/usr/share/plymouth/themes" -type f \( -name "debian-logo.png" -o -name "logo.png" -o -name "debian.png" \) 2>/dev/null | while read -r path; do
    pkexec rm -f "$path"
    pkexec cp "$TRANSPARENT_LOGO" "$path"
done

# 4. Iconos de distribuidor (Usar Logo de Pulsar)
echo "Configurando iconos de distribuidor con Logo de Pulsar..."
find "$ROOTFS/usr/share/icons" -type f \( -name "distributor-logo*" -o -name "debian-logo*" -o -name "*emblem-debian*" \) 2>/dev/null | while read -r path; do
    pkexec rm -f "$path"
    pkexec cp "$PULSAR_LOGO" "$path"
done

# 5. Forzar regeneración de Initramfs
echo "Regenerando initramfs (Inyectando cambios visuales)..."
pkexec mount -t proc proc "$ROOTFS/proc" || true
pkexec mount -t sysfs sys "$ROOTFS/sys" || true
pkexec mount --bind /dev "$ROOTFS/dev" || true
pkexec mount --bind /dev/pts "$ROOTFS/dev/pts" || true

pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "
    if command -v update-initramfs >/dev/null; then
        update-initramfs -u -k all
    fi
"

# Limpieza de montajes
pkexec umount -l "$ROOTFS/proc" || true
pkexec umount -l "$ROOTFS/sys" || true
pkexec umount -l "$ROOTFS/dev/pts" || true
pkexec umount -l "$ROOTFS/dev" || true

echo "✅ Exterminio completado. Pulsar OS 13 está listo."
