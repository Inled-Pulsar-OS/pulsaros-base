#!/bin/bash
# Script de emergencia para liberar montajes bloqueados
ROOTFS="$(realpath -m build/rootfs)"

echo "🧹 Limpiando montajes residuales en $ROOTFS..."

# Función para desmontar de forma segura y recursiva
cleanup_mounts() {
    local target=$1
    # Orden inverso para desmontar primero lo más profundo
    for mnt in $(mount | grep "$target" | awk '{print $3}' | sort -r); do
        echo "Desmontando $mnt..."
        pkexec umount -l "$mnt" || true
    done
}

cleanup_mounts "$ROOTFS"

echo "✅ Limpieza completada. Ya puedes borrar la carpeta 'build' o reintentar el build."
