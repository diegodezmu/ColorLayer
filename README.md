# ColorLayer

ColorLayer es una app de menubar para macOS que aplica ajustes de color sobre la pantalla sin icono de Dock (`LSUIElement`). El proyecto está construido con Swift 6, SwiftUI + AppKit y no usa dependencias externas.

## Resumen

- Tipo de app: utilidad residente de menubar.
- Plataforma objetivo: macOS 13+.
- Bundle ID: `com.diegofernandezmunoz.ColorLayer`.
- Estado global: `AppState.shared`, anotado con `@MainActor`.
- Persistencia:
  - presets en `Application Support/ColorLayer/presets.json`
  - sesión en `UserDefaults`

## Arquitectura

ColorLayer separa los efectos en dos mecanismos coordinados porque no todos se pueden resolver con la misma técnica en macOS.

### 1. Overlay

`OverlayWindowController` crea una `NSWindow` transparente, fullscreen, sin foco ni interacción de ratón. Dentro monta `OverlayView`, que dibuja dos `CALayer`:

- una capa negra para `dimming`
- una capa de color para el tinte (`overlayHue`, `overlaySaturation`, `overlayBrightness`, `overlayOpacity`)

Este pipeline es aditivo: pinta por encima del contenido del sistema, pero no procesa los píxeles de otras apps.

### 2. Gamma ramp

`DisplayTransferController` captura la tabla base del display principal y aplica una nueva tabla con `CGSetDisplayTransferByTable`. Ese pipeline cubre:

- `brightness`
- `contrast`
- `gamma`
- `temperature`

Este pipeline es multiplicativo: modifica cómo el sistema traduce los valores RGB antes de enviarlos al panel.

### 3. Coordinación

`AppState` publica `liveParameters` e `isBypassed`. `OverlayWindowController` observa ambos valores y, en cada cambio:

1. actualiza el overlay visual
2. sincroniza la gamma ramp del display principal
3. muestra u oculta la ventana overlay según el bypass

Al desactivar el efecto, ambos mecanismos se restauran juntos.

## Por qué no se usa Core Image como pipeline principal

La arquitectura original intentó resolver todos los ajustes mediante `CIFilter` aplicado a un `CALayer` transparente. En macOS con Apple Silicon ese enfoque no produjo el efecto esperado: los filtros solo procesaban los píxeles de la propia ventana overlay, no la imagen final compuesta del escritorio.

Por eso la implementación actual separa:

- overlay para dimming y color
- gamma ramp para brillo, contraste, gamma y temperatura

## Limitaciones actuales

- La app opera sobre el display principal (`NSScreen.main` y `CGMainDisplayID()`), no sobre una malla multi-display independiente.
- `saturation` sigue existiendo en el modelo y en presets, pero no forma parte del pipeline activo de v1. Implementarlo con curvas por canal no es correcto porque requiere mezcla entre canales.
- `swift test` solo valida la parte incluida en `Package.swift`; la app completa se ejecuta desde el proyecto Xcode.

## Estructura del repositorio

```text
ColorLayer/
├── AppState.swift
├── ColorLayerApp.swift
├── DisplayTransferController.swift
├── Models/
│   ├── FactoryPresets.swift
│   ├── FilterParameters.swift
│   └── Preset.swift
├── Overlay/
│   ├── OverlayView.swift
│   └── OverlayWindowController.swift
├── Persistence/
│   └── PresetStore.swift
├── Resources/
│   └── Info.plist
└── UI/
    ├── MenuBarPanel/
    │   └── MenuBarPanelView.swift
    └── PresetEditor/
        ├── FilterParametersView.swift
        ├── PresetEditorView.swift
        ├── PresetEditorWindowController.swift
        └── PresetListView.swift

ColorLayerTests/
├── AppStateTests.swift
├── DisplayTransferControllerTests.swift
└── PresetStoreTests.swift
```

## Componentes principales

### `ColorLayerApp` y `AppDelegate`

- Arrancan la app de menubar.
- Crean el `OverlayWindowController`.
- Abren la ventana del editor bajo demanda.
- Restauran ColorSync al arrancar y al terminar.
- Interceptan `SIGTERM` y `SIGINT` para restaurar el estado del sistema antes de salir.

### `AppState`

- Mantiene presets, preset activo, bypass y parámetros en vivo.
- Separa edición temporal (`liveParameters`) de persistencia del preset activo.
- Expone reglas de UI como `hasUnsavedChanges`, `canDeleteActivePreset` o `menuBarSymbolName`.

### `PresetStore`

- Guarda presets como JSON.
- Guarda `activePresetID` e `isBypassed` en `UserDefaults`.
- Repara la librería cargada para garantizar unicidad y mantener el preset bloqueado `Neutro`.

### `FactoryPresets`

- Semilla inicial de presets.
- Define el preset especial `Neutro`.
- Fuerza que el preset bloqueado quede siempre al final.

## Desarrollo

### Abrir y ejecutar

La app completa se ejecuta desde `ColorLayer.xcodeproj` con el esquema `ColorLayer`.

### Tests

La suite unitaria se ejecuta con:

```bash
swift test
```

Los tests cubren:

- `AppState`
- `PresetStore`
- `DisplayTransferController`

## Notas de persistencia

- Primer arranque: si no existe `presets.json`, se generan los presets semilla.
- Compatibilidad: `FilterParameters` mantiene decodificación tolerante para `overlayBrightness`.
- Cierre seguro: al terminar la app se intenta restaurar la tabla base del display y, si hace falta, se delega en `CGDisplayRestoreColorSyncSettings()`.
