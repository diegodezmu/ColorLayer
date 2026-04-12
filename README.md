# ColorLayer

ColorLayer es una utilidad de menubar para macOS que aplica ajustes de color sobre la pantalla. La app combina un overlay transparente y una gamma ramp del display para ofrecer dimming, tinte y correcciones básicas de señal sin dependencias externas.

![ColorLayer screenshot](docs/screenshot.png)

## Requisitos del sistema

- macOS 13.0 o superior
- Apple Silicon o Intel

## Instalación

1. Descarga el `.dmg` desde GitHub Releases.
2. Abre la imagen y arrastra `ColorLayer.app` a `/Applications`.
3. Inicia la app desde `/Applications`.

Nota: la app manipula tablas de color del display y no está sandboxed. macOS puede pedir autorización o mostrar advertencias la primera vez que se ejecute.

## Build desde código

### App completa

1. Clona este repositorio.
2. Abre `ColorLayer.xcodeproj` en Xcode.
3. Selecciona el target `ColorLayer`.
4. Ejecuta Build & Run.

### Tests de dominio sin Xcode completo

La parte testeable del dominio y la persistencia puede ejecutarse con:

```bash
swift test
```

`Package.swift` existe precisamente para ese caso: compila la lógica de estado, persistencia e invariantes sin depender de la app completa de Xcode.

## Uso

- El panel del menubar permite activar o desactivar el efecto y seleccionar presets.
- El editor de presets permite crear, duplicar, renombrar, borrar, reordenar y ajustar parámetros.
- Al salir, la app intenta restaurar el estado original del display. Si detecta un cierre sucio en el siguiente arranque, fuerza una restauración de ColorSync antes de continuar.

## Estructura del proyecto

```text
ColorLayer/
├── AppState.swift                  Estado global compartido y reglas de negocio
├── ColorLayerApp.swift             Punto de entrada SwiftUI + AppDelegate
├── DisplayTransferController.swift Gamma ramp vía CoreGraphics y crash recovery
├── Models/                         Modelos de presets y parámetros visuales
├── Overlay/                        Overlay transparente y coordinación con gamma ramp
├── Persistence/                    Persistencia JSON + UserDefaults
├── Resources/                      Info.plist del target app
├── Assets.xcassets/                Recursos visuales del bundle
└── UI/                             Menubar panel y editor de presets

ColorLayerTests/
├── AppStateTests.swift             Estado y reglas de selección/edición
├── DisplayTransferControllerTests.swift
│                                   Invariantes de gamma ramp y crash recovery
└── PresetStoreTests.swift          Persistencia y compatibilidad de datos
```

## Arquitectura resumida

- `OverlayWindowController` monta una `NSWindow` transparente con dos `CALayer` para `dimming` y color superpuesto.
- `DisplayTransferController` aplica `brightness`, `contrast`, `gamma` y `temperature` mediante `CGSetDisplayTransferByTable`.
- `AppState.shared` coordina ambas capas y sincroniza el bypass.
- `DisplayEffectRecovery` usa el flag `colorlayer.effectActive` para restaurar el display al siguiente arranque si la app terminó de forma sucia.

La explicación técnica completa está en [ARCHITECTURE.md](ARCHITECTURE.md).

## Stack tecnológico

- Swift 6
- SwiftUI
- AppKit
- Combine
- CoreGraphics
- QuartzCore
- Foundation
- OSLog (`Logger`)
- Apple Testing

## Publicación

- Versión: `1.0.0`
- Distribución prevista: `.dmg` desde GitHub Releases
- Code signing: `diegodezmu`

## Licencia

Este proyecto se distribuye bajo **MIT + Commons Clause**. Consulta [LICENSE](LICENSE).
