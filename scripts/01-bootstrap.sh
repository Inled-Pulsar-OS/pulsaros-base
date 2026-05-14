#!/bin/bash
set -e
source configs/env.sh

# Convertir OUTPUT_DIR a ruta absoluta
OUTPUT_DIR="$(realpath -m build/rootfs)"
PARENT_DIR="$(dirname "$OUTPUT_DIR")"

# Opción para forzar limpieza
if [ "$1" == "--clean" ]; then
    echo "--- Forzando limpieza de construcción previa ---"
    pkexec rm -rf "$PARENT_DIR"
fi

# Comprobar si ya existe para sincronizar paquetes (Construcción Incremental)
if [ -d "$OUTPUT_DIR/etc" ]; then
    echo "--- Rootfs detectado. Sincronizando paquetes (Modo Incremental) ---"
    
    # Limpiamos el listado de paquetes: quitamos comentarios y líneas vacías
    PACKAGE_LIST_SPACE=$(grep -v '^#' configs/base.list | grep -v '^$' | tr '\n' ' ')
    
    echo "Actualizando repositorios e instalando nuevos paquetes..."
    # Montar sistemas de archivos virtuales necesarios para que APT/Systemd no se quejen
    pkexec mount -t proc proc "$OUTPUT_DIR/proc" || true
    pkexec mount -t sysfs sys "$OUTPUT_DIR/sys" || true
    pkexec mount --bind /dev "$OUTPUT_DIR/dev" || true
    pkexec mount --bind /dev/pts "$OUTPUT_DIR/dev/pts" || true

    pkexec /usr/sbin/chroot "$OUTPUT_DIR" apt-get update
    pkexec /usr/sbin/chroot "$OUTPUT_DIR" apt-get install -y $PACKAGE_LIST_SPACE
    
    # Desmontar al terminar
    pkexec umount -l "$OUTPUT_DIR/proc" || true
    pkexec umount -l "$OUTPUT_DIR/sys" || true
    pkexec umount -l "$OUTPUT_DIR/dev/pts" || true
    pkexec umount -l "$OUTPUT_DIR/dev" || true

    echo "Sincronización completada."
    exit 0
fi

mkdir -p "$PARENT_DIR"

echo "--- Verificando rutas para mmdebstrap ---"
echo "OUTPUT_DIR: $OUTPUT_DIR"
pkexec ls -ld "$PARENT_DIR"

echo "--- Iniciando Bootstrap (mmdebstrap) ---"
# Limpiamos el listado de paquetes: quitamos comentarios y líneas vacías
PACKAGE_LIST=$(grep -v '^#' configs/base.list | grep -v '^$' | tr '\n' ',' | sed 's/,$//')

# Usamos mmdebstrap porque es más rápido y genera imágenes más limpias
pkexec /usr/bin/mmdebstrap \
    --architecture=$ARCH \
    --variant=apt \
    --include="$PACKAGE_LIST" \
    $DEBIAN_VERSION \
    "$OUTPUT_DIR" \
    $MIRROR

echo "Bootstrap completado en $OUTPUT_DIR"
