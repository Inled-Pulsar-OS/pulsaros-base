#!/bin/bash
set -e

echo "🛠️ Instalando dependencias de desarrollo para PulsarOS..."

# 1. Actualizar repositorios
sudo apt update

# 2. Herramientas básicas de construcción y sistema
echo "Instalando herramientas básicas..."
sudo apt install -y \
    git \
    wget \
    curl \
    unzip \
    build-essential \
    pkg-config \
    mmdebstrap \
    qemu-system-x86 \
    qemu-system-arm \
    qemu-system-gui \
    qemu-utils \
    ovmf \
    qemu-efi-aarch64 \
    policykit-1 \
    jq

# 3. Dependencias para Temas GNOME (Sassc, Glib, etc.)
echo "Instalando dependencias de temas..."
sudo apt install -y \
    sassc \
    libglib2.0-dev-bin \
    libxml2-utils \
    imagemagick

# 4. Dependencias para Fildem HUD y Python
echo "Instalando dependencias de Fildem HUD..."
sudo apt install -y \
    python3-gi \
    python3-dbus \
    python3-setuptools \
    python3-pip \
    python3-xlib \
    bamfdaemon \
    libbamf3-dev \
    libkeybinder-3.0-dev \
    appmenu-gtk3-module \
    libcanberra-gtk3-module

# 5. Dependencias para Calamares (en caso de querer compilar o probar localmente)
echo "Instalando herramientas de Calamares..."
sudo apt install -y \
    calamares \
    calamares-settings-debian

# 6. Dependencias para aceleración gráfica en QEMU
echo "Instalando dependencias de aceleración QEMU..."
sudo apt install -y \
    libgl1-mesa-dri \
    libvirglrenderer1 \
    libegl-mesa0 \
    libgbm1 \
    mesa-utils

echo "✅ Todas las dependencias de desarrollo han sido instaladas."
echo "Puedes empezar a construir la distro con: ./build.sh"
