#!/bin/bash
set -e

# Obtener la ruta absoluta del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ROOTFS="$(realpath -m "$PROJECT_ROOT/build/rootfs")"

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

# 1. Preparar directorios de branding y módulos
BRANDING_DIR="$ROOTFS/usr/share/calamares/branding/pulsaros"
pkexec mkdir -p "$BRANDING_DIR"
pkexec mkdir -p "$ROOTFS/etc/calamares/modules"

# 2. Copiar Branding desde la carpeta calamares/ (Assets de pearOS que Jaime ha modificado)
CALAMARES_SRC_DIR="$PROJECT_ROOT/calamares/etc/calamares/branding/pearOS"
echo "Copiando branding desde: $CALAMARES_SRC_DIR"

if [ -d "$CALAMARES_SRC_DIR" ]; then
    # Usamos . para copiar el contenido del directorio
    pkexec cp -r "$CALAMARES_SRC_DIR/." "$BRANDING_DIR/"
    
    # Ajustar branding.desc para PulsarOS manteniendo los estilos de Jaime
    # IMPORTANTE: componentName DEBE ser 'pulsaros' porque es el nombre de la carpeta
    pkexec sed -i 's/^componentName:.*/componentName:  pulsaros/' "$BRANDING_DIR/branding.desc"
    
    # Reemplazos generales de texto
    pkexec sed -i 's/pearOS NiceC0re/PulsarOS/g' "$BRANDING_DIR/branding.desc"
    pkexec sed -i 's/pearOS/PulsarOS/g' "$BRANDING_DIR/branding.desc"
    pkexec sed -i 's/version:             26.03/version:             1.0/g' "$BRANDING_DIR/branding.desc"
    pkexec sed -i 's/shortVersion:        26.3/shortVersion:        1.0/g' "$BRANDING_DIR/branding.desc"
else
    echo "⚠️ Advertencia: No se encontró la carpeta de branding en $CALAMARES_SRC_DIR"
    # Fallback minimal si no existe
    cat <<EOF | pkexec tee "$BRANDING_DIR/branding.desc" > /dev/null
---
componentName:  pulsaros
welcomeStyleCalamares:   false
welcomeExpandingLogo:   true
strings:
    productName:         PulsarOS
    shortProductName:    PulsarOS
    productVersion:      1.0
images:
    productLogo:         "logo.png"
    productIcon:         "logo.png"
    productWelcome:      "welcome.png"
style:
   sidebarBackground:    "#1f1f1f"
   sidebarText:          "#e0e0e0"
   sidebarTextCurrent:       "#1f1f1f"
   sidebarBackgroundCurrent: "#0a84ff"
slideshow:               "show.qml"
slideshowAPI: 2
EOF
fi

# 3. Configurar módulos adicionales (removeuser y welcome)
echo "Configurando módulos de limpieza y requisitos..."

# Configurar welcome.conf para desactivar requisitos de hardware (permite instalar en VMs pequeñas)
cat <<EOF | pkexec tee "$ROOTFS/etc/calamares/modules/welcome.conf" > /dev/null
---
showSupportUrl:         false
showKnownIssuesUrl:     false
showReleaseNotesUrl:    false
showRunCalamaresUrl:    false

requirements:
    requiredStorage:    5.0
    requiredRam:        1.0
    internetCheckUrl:   http://google.com
    check:
        - storage
        - ram
        - power
        - internet
        - root
    required:
        # - storage
        # - ram
        - root

geoip:
    style:    "none"
EOF
cat <<EOF | pkexec tee "$ROOTFS/etc/calamares/modules/removeuser-live.conf" > /dev/null
---
username: live
EOF

cat <<EOF | pkexec tee "$ROOTFS/etc/calamares/modules/removeuser-jaime.conf" > /dev/null
---
username: jaime
EOF

# También copiamos users.conf si existe para mantener grupos y autologin deseado
USERS_CONF_SRC="$PROJECT_ROOT/calamares/etc/calamares/modules/users.conf"
if [ -f "$USERS_CONF_SRC" ]; then
    pkexec cp "$USERS_CONF_SRC" "$ROOTFS/etc/calamares/modules/users.conf"
    # Ajustar hostname por defecto y asegurar bash como shell
    pkexec sed -i 's/template: "pearOS-machine"/template: "pulsaros-machine"/g' "$ROOTFS/etc/calamares/modules/users.conf"
    pkexec sed -i 's/shell: \/bin\/zsh/shell: \/bin\/bash/g' "$ROOTFS/etc/calamares/modules/users.conf"
    # Añadir grupo docker a los grupos por defecto si no está
    pkexec sed -i 's/defaultGroups:/defaultGroups:\n    - docker/' "$ROOTFS/etc/calamares/modules/users.conf"
fi

# 4. Configurar settings.conf de Calamares
echo "Generando settings.conf..."
cat <<EOF | pkexec tee "$ROOTFS/etc/calamares/settings.conf" > /dev/null
---
modules-search: [ local, /usr/lib/x86_64-linux-gnu/calamares/modules, /usr/share/calamares/modules ]

instances:
- id:       debian
  module:   packages
  config:   packages.conf
- id:       live
  module:   removeuser
  config:   removeuser-live.conf
- id:       jaime
  module:   removeuser
  config:   removeuser-jaime.conf

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
  - removeuser@live
  - removeuser@jaime
  - bootloader
  - umount
- show:
  - finished

branding: pulsaros
prompt-install: true
dont-chroot: false
EOF

# 5. Configurar Auto-arranque en el entorno Live para el usuario live
AUTOSTART_DIR="$ROOTFS/home/live/.config/autostart"
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

# Asegurar permisos (el ID del primer usuario suele ser 1000, live será el segundo probablemente)
# Pero como los creamos en orden jaime (1000) y live (1001), ajustamos.
pkexec /usr/sbin/chroot "$ROOTFS" chown -R jaime:jaime /home/jaime
pkexec /usr/sbin/chroot "$ROOTFS" chown -R live:live /home/live

# 6. Polkit rule (Ya integrada globalmente en 02-customize.sh, pero mantenemos una específica para calamares si se prefiere)
# En este caso, la regla global ya permite pkexec sin contraseña para sudoers, y calamares usa sudo -E.


# --- Finalización ---
echo "✅ Calamares configurado y listo para el entorno Live."
