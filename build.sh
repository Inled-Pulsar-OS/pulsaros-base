#!/bin/bash
set -e

# Asegurar que el directorio build existe
mkdir -p build

echo "🚀 Iniciando construcción de PulsarOS..."

# 1. Bootstrap
bash scripts/01-bootstrap.sh

# 2. Customización
bash scripts/02-customize.sh

echo "✅ Proceso finalizado."
echo "Para probar la distro, ejecuta: ./scripts/run-qemu.sh"
