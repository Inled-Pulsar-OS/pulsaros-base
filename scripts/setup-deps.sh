#!/bin/bash
echo "Instalando dependencias necesarias para construir PulsarOS..."

pkexec apt-get update
pkexec apt-get install -y \
    mmdebstrap \
    qemu-system-x86 \
    qemu-utils \
    linux-image-amd64 \
    systemd-container \
    binfmt-support \
    qemu-user-static

echo "✅ Dependencias instaladas."
