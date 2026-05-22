#!/bin/bash
set -e

# Obtener la ruta absoluta del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ROOTFS="$(realpath -m "$PROJECT_ROOT/build/rootfs")"
PULSAR_LOGO="$PROJECT_ROOT/build/assets/pulsar-logo.png"
TRANSPARENT_LOGO="$PROJECT_ROOT/build/assets/transparent.png"

# Asegurar logos
if [ ! -f "$TRANSPARENT_LOGO" ]; then
    python3 -c "from PIL import Image; img = Image.new('RGBA', (1, 1), (0, 0, 0, 0)); img.save('$TRANSPARENT_LOGO')"
fi

echo "--- APLICANDO IDENTIDAD PULSAR OS 13 (Surgical Edition) ---"

# 1. Identidad del Sistema
echo "Configurando os-release..."
pkexec tee "$ROOTFS/etc/os-release" "$ROOTFS/usr/lib/os-release" <<EOF > /dev/null
PRETTY_NAME="Pulsar OS 13"
NAME="Pulsar OS"
VERSION_ID="13"
VERSION="13"
ID=pulsaros
ID_LIKE=debian
HOME_URL="https://inled.es"
LOGO="pulsar-logo"
EOF

# 3. Branding Visible en GNOME (About, GDM, Menús)
echo "Aplicando Branding a GNOME (About y GDM)..."
# Reemplazar vendor-logos y logos de desktop-base por el logo de Pulsar REAL
for dir in "/usr/share/images/vendor-logos" "/usr/share/desktop-base/debian-logos"; do
    if [ -d "$ROOTFS$dir" ]; then
        find "$ROOTFS$dir" -type f \( -name "*.png" -o -name "*.svg" \) 2>/dev/null | while read -r path; do
            pkexec cp "$PULSAR_LOGO" "$path"
        done
    fi
done

# Iconos de distribuidor (About GNOME, GDM)
find "$ROOTFS/usr/share/icons" -type f \( -name "distributor-logo*" -o -name "debian-logo*" -o -name "*emblem-debian*" \) 2>/dev/null | while read -r path; do
    pkexec cp "$PULSAR_LOGO" "$path"
done

# 4. Plymouth (ELIMINAR LOGO DUPLICADO - DEBE SER LO ÚLTIMO)
echo "Eliminando logos extra de Plymouth (Sustitución por Transparente)..."
# Reemplazar el logo de Debian del sistema por uno TRANSPARENTE
# Esto evita que aparezca el logo gigante a la derecha/abajo
for logo_path in "$ROOTFS/usr/share/plymouth/debian-logo.png" "$ROOTFS/usr/share/pixmaps/debian-logo.png"; do
    pkexec rm -f "$logo_path"
    pkexec cp "$TRANSPARENT_LOGO" "$logo_path" || true
done

# Hacer lo mismo con cualquier logo de otros temas que Plymouth pueda cargar como fallback
# Somos agresivos: cualquier cosa que se llame logo o debian_logo en plymouth/themes debe ser transparente
find "$ROOTFS/usr/share/plymouth/themes" -type f \( -name "debian-logo.png" -o -name "logo.png" -o -name "debian.png" -o -name "debian_logo.png" -o -name "debian_logo16.png" \) 2>/dev/null | while read -r path; do
    # NO tocar nuestro tema pulsar-plymouth
    if [[ "$path" != *"pulsar-plymouth"* ]]; then
        pkexec cp "$TRANSPARENT_LOGO" "$path"
    fi
done

# 5. Regenerar Initramfs
echo "Regenerando initramfs para aplicar cambios visuales..."
pkexec mount -t proc proc "$ROOTFS/proc" || true
pkexec mount -t sysfs sys "$ROOTFS/sys" || true
pkexec mount --bind /dev "$ROOTFS/dev" || true
pkexec mount --bind /dev/pts "$ROOTFS/dev/pts" || true

pkexec /usr/sbin/chroot "$ROOTFS" /bin/bash -c "update-initramfs -u -k all"

# Limpieza
pkexec umount -l "$ROOTFS/proc" || true
pkexec umount -l "$ROOTFS/sys" || true
pkexec umount -l "$ROOTFS/dev/pts" || true
pkexec umount -l "$ROOTFS/dev" || true

echo "✅ Pulsar OS 13: Identidad y Splash corregidos."
