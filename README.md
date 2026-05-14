# PulsarOS Base
> [!WARNING]
> Este proyecto está en desarrollo. Actualmente no se recomienda su uso.  

Este repositorio es la base para la creación de distribuciones Linux personalizadas basadas en Debian (sid/trixie). Utiliza una arquitectura modular y auditable para permitir la creación de imágenes para múltiples arquitecturas y entornos de escritorio.

## Estructura del Proyecto (Screaming Architecture)

La estructura está diseñada para que el propósito de cada componente sea evidente:

*   **`build.sh`**: Orquestador principal. Es el punto de entrada para construir la distro.
*   **`configs/`**: Definiciones globales (paquetes base, repositorios, variables de entorno).
*   **`profiles/`**: Módulos específicos para cada sabor de la distro (GNOME, KDE, Minimal).
*   **`scripts/`**: Lógica de construcción dividida por etapas (Bootstrap, Customization, Imaging).
*   **`overlay/`**: Árbol de archivos que se inyectará directamente en el sistema de archivos de la distro (configuraciones en `/etc`, temas, etc.).
*   **`docs/`**: Documentación detallada sobre procesos específicos.

## Flujo de Trabajo

1.  **Bootstrap**: Creación del sistema de archivos base usando `mmdebstrap`.
2.  **Customization**: Ejecución de hooks y scripts dentro del `chroot` para instalar software y configurar el sistema.
3.  **Overlay**: Inyección de archivos personalizados desde la carpeta `overlay/`.
4.  **Imaging**: Empaquetado del sistema en una imagen booteable (ISO o imagen de disco).

## Desarrollo Local e Iteración Rápida

Para equipos de 2018 o recursos limitados, recomendamos:
*   Uso de `mmdebstrap` con `--variant=apt` para reducir el tamaño inicial.
*   Uso de caché local para paquetes de Debian.
*   Pruebas mediante QEMU/KVM con aceleración.

---
*Diseñado con ❤️ por Jaime y Gemini CLI.*
