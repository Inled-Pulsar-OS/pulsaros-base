DEBIAN_VERSION="trixie" # Debian 13
# Detectar arquitectura del host por defecto si no está definida
HOST_ARCH=$(uname -m)
if [ "$HOST_ARCH" == "x86_64" ]; then
    DEFAULT_ARCH="amd64"
elif [ "$HOST_ARCH" == "aarch64" ] || [ "$HOST_ARCH" == "arm64" ]; then
    DEFAULT_ARCH="arm64"
else
    DEFAULT_ARCH="amd64"
fi

ARCH=${ARCH:-$DEFAULT_ARCH}
MIRROR="http://deb.debian.org/debian"
