# ColorLayer 1.0.0

ColorLayer es una utilidad de menubar para macOS que aplica ajustes de color sobre la pantalla mediante un overlay transparente y una gamma ramp del display. Está pensada como app residente, sin icono de Dock, con foco en presets persistentes y restauración segura del estado del display.

La versión 1.0.0 entrega la primera release pública del proyecto con la arquitectura dual ya consolidada: overlay para efectos aditivos y tablas de transferencia para ajustes multiplicativos.

## Features principales

- Dimming mediante overlay semitransparente
- Tinte de color mediante overlay configurable
- Ajustes de `brightness`, `contrast`, `gamma` y `temperature` vía `CGSetDisplayTransferByTable`
- Gestión de presets: crear, editar, duplicar, borrar y reordenar
- Persistencia local de presets y sesión
- Restauración automática del display al salir y recuperación tras cierre sucio
- Logging estructurado con `os.Logger`

## Requisitos del sistema

- macOS 13.0 o superior
- Apple Silicon o Intel

## Instalación

1. Descarga el `.dmg` de la release.
2. Abre la imagen.
3. Arrastra `ColorLayer.app` a `/Applications`.
4. Ejecuta la app.

Nota: la app manipula tablas de color del display y no está sandboxed. macOS puede solicitar confirmación la primera vez.

## Más detalles

Consulta [CHANGELOG.md](../CHANGELOG.md) para el detalle de cambios.
