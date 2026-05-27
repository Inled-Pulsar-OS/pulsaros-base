#!/bin/bash
set -e
ROOTFS="$(realpath -m build/rootfs)"

echo "🛠️ Aplicando correcciones finales de Calamares, Extensiones y GTK4..."

# 1. Asegurar Calamares y su Lanzador
echo "Configurando Calamares..."
pkexec /usr/sbin/chroot "$ROOTFS" apt-get install -y --no-install-recommends calamares calamares-settings-debian
pkexec mkdir -p "$ROOTFS/usr/share/calamares/branding/pulsaros"
pkexec cp -r "/home/jaime/Documentos/pulsaros-base/calamares/etc/calamares/branding/pearOS/." "$ROOTFS/usr/share/calamares/branding/pulsaros/"
pkexec sed -i 's/pearOS/PulsarOS/g' "$ROOTFS/usr/share/calamares/branding/pulsaros/branding.desc"

# 2. Fix Extensiones (Override Total)
echo "Forzando esquemas de extensiones..."
pkexec /usr/sbin/chroot "$ROOTFS" glib-compile-schemas /usr/share/glib-2.0/schemas/

# 3. Fix Libadwaita (GTK4)
echo "Aplicando estilo GTK4 a todos los perfiles..."
for TARGET in "/etc/skel" "/home/jaime" "/home/live" "/root"; do
    pkexec mkdir -p "$ROOTFS$TARGET/.config/gtk-4.0"
    pkexec cp -rf "$ROOTFS/usr/share/themes/MacTahoe-Dark/gtk-4.0/"* "$ROOTFS$TARGET/.config/gtk-4.0/" 2>/dev/null || true
done

# 4. Transición SDDM Suave (Sin pantalla negra)
echo "Optimizando transición SDDM..."
pkexec mkdir -p "$ROOTFS/etc/sddm.conf.d"
cat <<EOF | pkexec tee "$ROOTFS/etc/sddm.conf.d/transition.conf"
[General]
# Prevenir que el terminal borre la pantalla al arrancar SDDM
InputMethod=
EOF

# 5. Fix Permisos Home
pkexec /usr/sbin/chroot "$ROOTFS" chown -R jaime:jaime /home/jaime 2>/dev/null || true
pkexec /usr/sbin/chroot "$ROOTFS" chown -R live:live /home/live 2>/dev/null || true

echo "✅ Correcciones aplicadas."
