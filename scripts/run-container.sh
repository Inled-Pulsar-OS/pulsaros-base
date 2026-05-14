#!/bin/bash
# Versión simplificada para evitar errores de permisos en cgroups
ROOTFS="$(realpath -m build/rootfs)"

if [ ! -d "$ROOTFS/etc" ]; then
    echo "Error: No existe el rootfs. Ejecuta ./build.sh primero."
    exit 1
fi

echo "🚀 Entrando a PulsarOS (Modo Directo)..."
# Usamos nspawn sin el flag -b (boot) para entrar directo a una shell funcional
# --as-pid2: Evita errores de PID 1
# --register=no: Evita problemas con systemd-machined
pkexec systemd-nspawn -D "$ROOTFS" --as-pid2 --user=jaime /bin/bash
