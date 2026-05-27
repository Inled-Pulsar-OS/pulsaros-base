#!/bin/bash
set -e

# Obtener la ruta absoluta del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ROOTFS="$(realpath -m "$PROJECT_ROOT/build/rootfs")"
THEME_DIR="$PROJECT_ROOT/tahoe-sddmtheme"

echo "🎨 Configurando SDDM y Tema Tahoe..."

# 0. Eliminar GDM3 para evitar conflictos
echo "Eliminando GDM3 si existe..."
pkexec /usr/sbin/chroot "$ROOTFS" apt-get purge -y gdm3 || true
pkexec /usr/sbin/chroot "$ROOTFS" apt-get autoremove -y || true

# 1. Instalar el tema SDDM
echo "Instalando tema Tahoe en el rootfs..."
pkexec mkdir -p "$ROOTFS/usr/share/sddm/themes/tahoe-sddm"
pkexec cp -r "$THEME_DIR"/* "$ROOTFS/usr/share/sddm/themes/tahoe-sddm/"

# PARCHE: Corregir importación de Breeze en Qt6
echo "Parcheando Main.qml para compatibilidad con Qt6/Breeze..."
pkexec sed -i 's/import org.kde.breeze.components/import org.kde.breeze/g' "$ROOTFS/usr/share/sddm/themes/tahoe-sddm/Main.qml"

# 2. Configurar SDDM para usar el tema
echo "Configurando SDDM..."
pkexec mkdir -p "$ROOTFS/etc/sddm.conf.d"
cat <<EOF | pkexec tee "$ROOTFS/etc/sddm.conf.d/theme.conf"
[Theme]
Current=tahoe-sddm
EOF

# 3. Asegurar que SDDM esté habilitado
# (Aunque al ser el único DM instalado debería ser el predeterminado)
echo "Habilitando servicio SDDM..."
pkexec /usr/sbin/chroot "$ROOTFS" systemctl enable sddm.service || true

# 4. Instalar fuentes necesarias para el tema si las hay
if [ -d "$THEME_DIR/fonts" ]; then
    echo "Instalando fuentes del tema..."
    pkexec mkdir -p "$ROOTFS/usr/share/fonts/truetype/tahoe-sddm"
    pkexec cp "$THEME_DIR/fonts"/*.otf "$ROOTFS/usr/share/fonts/truetype/tahoe-sddm/" 2>/dev/null || true
    pkexec cp "$THEME_DIR/fonts"/*.ttf "$ROOTFS/usr/share/fonts/truetype/tahoe-sddm/" 2>/dev/null || true
    pkexec /usr/sbin/chroot "$ROOTFS" fc-cache -f
fi

echo "✅ SDDM configurado con el tema Tahoe."
