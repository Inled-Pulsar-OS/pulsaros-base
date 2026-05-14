# Scripts de Construcción 📜

Lógica procedimental de la orquestación. Dividida en etapas para facilitar la auditoría y el debugging.

- `01-bootstrap.sh`: Invoca a `mmdebstrap` para crear el rootfs.
- `02-customize.sh`: Gestiona la instalación de paquetes y ejecución de hooks.
- `03-overlay.sh`: Aplica las capas de archivos de `overlay/`.
- `04-image.sh`: Crea la ISO o imagen final.
