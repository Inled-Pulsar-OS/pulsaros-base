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

# Habilitar login en consola serie (necesario para QEMU)
pkexec /usr/sbin/chroot "$ROOTFS" systemctl enable getty@ttyS0.service || true

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

echo "Personalización completada."
