#!/bin/bash
set -e
ROOTFS="$(realpath -m build/rootfs)"

# Función de limpieza para asegurar desmontaje
cleanup() {
    echo "🧹 Finalizando y liberando recursos..."
    pkexec umount -l "$ROOTFS/proc" || true
    pkexec umount -l "$ROOTFS/sys" || true
    pkexec umount -l "$ROOTFS/dev/pts" || true
    pkexec umount -l "$ROOTFS/dev" || true
}
trap cleanup EXIT INT TERM

echo "--- Configurando Calamares Personalizado para PulsarOS ---"

# --- Preparar entorno (Mounts) ---
pkexec mount -t proc proc "$ROOTFS/proc" || true
pkexec mount -t sysfs sys "$ROOTFS/sys" || true
pkexec mount --bind /dev "$ROOTFS/dev" || true
pkexec mount --bind /dev/pts "$ROOTFS/dev/pts" || true

# 1. Crear directorios de branding
BRANDING_DIR="$ROOTFS/usr/share/calamares/branding/pulsaros"
pkexec mkdir -p "$BRANDING_DIR"

# 2. Configuración de Branding (branding.desc)
cat <<EOF | pkexec tee "$BRANDING_DIR/branding.desc" > /dev/null
---
componentName:  pulsaros

welcomeStyleCalamares:   false
welcomeExpandingLogo:   true

strings:
    productName:         PulsarOS
    shortProductName:    PulsarOS
    productVersion:      1.0
    shortProductVersion: 1.0
    versionedName:       PulsarOS 1.0 "Nebula"
    shortVersionedName:  PulsarOS 1.0
    bootloaderEntryName: PulsarOS
    productUrl:          https://github.com/InledGroup/pulsaros
    supportUrl:          https://github.com/InledGroup/pulsaros/issues
    knownIssuesUrl:      https://github.com/InledGroup/pulsaros/issues
    releaseNotesUrl:     https://github.com/InledGroup/pulsaros/blob/main/README.md

images:
    productLogo:         "logo.png"
    productIcon:         "logo.png"
    productWelcome:      "welcome.png"

style:
   sidebarBackground:    "#2e3440"
   sidebarText:          "#eceff4"
   sidebarTextSelect:    "#88c0d0"
   sidebarTextHighlight: "#5e81ac"

EOF

# 3. Descargar o generar imágenes de branding
PULSAR_LOGO_URL="https://raw.githubusercontent.com/Inled-Pulsar-OS/pulsar-art/refs/heads/main/pulsar-os-tahoe.png"
echo "Descargando logos para Calamares..."
pkexec wget -q -O "$BRANDING_DIR/logo.png" "$PULSAR_LOGO_URL"
pkexec cp "$BRANDING_DIR/logo.png" "$BRANDING_DIR/welcome.png"

# 4. Configurar settings.conf de Calamares
# Usamos las rutas de módulos de Debian por defecto pero con nuestro branding
pkexec mkdir -p "$ROOTFS/etc/calamares"
cat <<EOF | pkexec tee "$ROOTFS/etc/calamares/settings.conf" > /dev/null
---
modules-search: [ local, /usr/lib/x86_64-linux-gnu/calamares/modules, /usr/share/calamares/modules ]

instances:
- id:       debian
  module:   packages
  config:   packages.conf

sequence:
- show:
  - welcome
  - locale
  - keyboard
  - partition
  - users
  - summary
- exec:
  - partition
  - mount
  - unpackfs
  - machineid
  - fstab
  - locale
  - keyboard
  - localecfg
  - users
  - displaymanager
  - networkcfg
  - hwclock
  - services-systemd
  - packages
  - grubcfg
  - bootloader
  - postcfg
  - umount
- show:
  - finished

branding: pulsaros
prompt-install: true
dont-chroot: false
EOF

# 5. Configurar Auto-arranque en el entorno Live para el usuario jaime
AUTOSTART_DIR="$ROOTFS/home/jaime/.config/autostart"
pkexec mkdir -p "$AUTOSTART_DIR"

# Script wrapper para Wayland
cat <<'EOF' | pkexec tee "$ROOTFS/usr/local/bin/launch-calamares" > /dev/null
#!/bin/bash
# Permitir conexiones X11 locales para root (necesario para GUI en Wayland)
xhost +local:root > /dev/null 2>&1 || true

# Ejecutar calamares con sudo preservando variables (mucho más fiable que pkexec)
sudo -E DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" WAYLAND_DISPLAY="$WAYLAND_DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" calamares "$@"
EOF
pkexec chmod +x "$ROOTFS/usr/local/bin/launch-calamares"

cat <<EOF | pkexec tee "$AUTOSTART_DIR/calamares.desktop" > /dev/null
[Desktop Entry]
Type=Application
Name=Install PulsarOS
GenericName=System Installer
Exec=/usr/local/bin/launch-calamares
Icon=calamares
Terminal=false
Categories=Qt;System;
X-GNOME-Autostart-enabled=true
EOF

# También lo añadimos a /etc/skel para futuros usuarios si fuera necesario
pkexec mkdir -p "$ROOTFS/etc/skel/.config/autostart"
pkexec cp "$AUTOSTART_DIR/calamares.desktop" "$ROOTFS/etc/skel/.config/autostart/"

pkexec chown -R 1000:1000 "$ROOTFS/home/jaime/.config"

# 6. Polkit rule para permitir a jaime ejecutar calamares sin password (específico para el instalador)
echo "Configurando reglas de Polkit para ejecución sin contraseña..."
pkexec mkdir -p "$ROOTFS/etc/polkit-1/rules.d"
cat <<EOF | pkexec tee "$ROOTFS/etc/polkit-1/rules.d/49-nopasswd-calamares.rules" > /dev/null
polkit.addRule(function(action, subject) {
    if (action.id == "com.github.calamares.calamares.pkexec.run") {
        return polkit.Result.YES;
    }
});
EOF

# --- Finalización ---
echo "✅ Calamares configurado y listo para el entorno Live."
