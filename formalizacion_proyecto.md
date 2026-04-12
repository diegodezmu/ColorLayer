# Formalización Técnica del Repositorio `ColorLayer`

## 1. Objetivo

Este documento describe el estado actual observable del repositorio `ColorLayer` a partir del código fuente, la configuración del proyecto y la suite de tests disponible. Su propósito es dejar una base técnica fiel al diseño vigente de la app.

El criterio de verdad de este documento es la implementación actual del repositorio. Cuando un punto depende de una inferencia, se formula como tal.

## 2. Resumen ejecutivo

`ColorLayer` es una utilidad de menubar para macOS, sin icono de Dock, construida con `SwiftUI` y `AppKit`. La app aplica ajustes de color mediante dos mecanismos coordinados:

- un overlay transparente para `dimming` y tinte de color
- una gamma ramp del display para `brightness`, `contrast`, `gamma` y `temperature`

Ambos mecanismos se sincronizan desde `AppState`, que actúa como fuente única de estado observable para UI, persistencia y aplicación del efecto.

La app persiste:

- presets en `Application Support/ColorLayer/presets.json`
- sesión en `UserDefaults`
- flag de crash recovery en `UserDefaults`

## 3. Stack tecnológico

### 3.1 Lenguaje y plataforma

- Lenguaje principal: `Swift`
- `swift-tools-version`: `6.0`
- Deployment target: `macOS 13.0`
- Bundle ID: `com.diegofernandezmunoz.ColorLayer`
- Tipo de app: `LSUIElement = true`

### 3.2 Frameworks observados

- `SwiftUI`
- `AppKit`
- `Combine`
- `Foundation`
- `CoreGraphics`
- `QuartzCore`
- `Dispatch`
- `OSLog`
- `Testing`

No se detectan dependencias de terceros.

### 3.3 Sistemas de build

El repositorio mantiene dos superficies distintas:

1. `ColorLayer.xcodeproj`
   Define la app macOS completa, incluyendo UI, overlay, recursos y `Info.plist`.
2. `Package.swift`
   Expone una librería parcial para la lógica testeable y la suite de `swift test`.

El target SwiftPM excluye explícitamente:

- `ColorLayerApp.swift`
- `Overlay/`
- `UI/`
- `Resources/`
- `Assets.xcassets`

Por tanto, `swift test` valida la parte de dominio, persistencia y control de gamma, pero no la app completa tal como se ejecuta desde Xcode.

La divergencia es intencionada y responde a una necesidad operativa del desarrollo: poder compilar y testear la lógica del proyecto en entornos con solo Command Line Tools y sin Xcode completo.

## 4. Arquitectura general

### 4.1 Vista de alto nivel

```text
ColorLayerApp
  -> AppDelegate
    -> AppState.shared
    -> OverlayWindowController
      -> OverlayView
      -> DisplayTransferController
    -> PresetEditorWindowController

AppState
  -> PresetStore
  -> MenuBarPanelView
  -> PresetEditorView
  -> OverlayWindowController (vía Combine)
```

### 4.2 Punto de entrada y ciclo de vida

`ColorLayerApp` monta un `MenuBarExtra` con estilo `.window` y conecta `AppDelegate` mediante `@NSApplicationDelegateAdaptor`.

`AppDelegate`:

- ejecuta recuperación de display por cierre sucio antes de crear la infraestructura visual
- restaura ColorSync al arrancar
- crea `OverlayWindowController`
- crea `PresetEditorWindowController` bajo demanda
- restaura el estado del sistema al salir
- intercepta `SIGTERM` y `SIGINT` para intentar restaurar antes de terminar

### 4.3 Estado central

`AppState` es un singleton `@MainActor` basado en `ObservableObject` + `@Published`.

Responsabilidades observables:

- mantener la librería de presets
- mantener `activePresetID`
- mantener `isBypassed`
- mantener `liveParameters`
- separar edición temporal de persistencia
- derivar estado de UI
- persistir sesión y presets vía `PresetStore`
- centralizar logging y decisiones de coordinación

### 4.4 Pipeline de efecto visual

La app usa dos pipelines porque la naturaleza de los ajustes es distinta.

#### Overlay

`OverlayWindowController` crea una `NSWindow` borderless, transparente, fullscreen, por encima del resto (`.screenSaver`), ignorando ratón y sin convertirse en key window.

Dentro de esa ventana, `OverlayView` dibuja dos `CALayer`:

- `dimmingLayer`: una capa negra con opacidad variable
- `colorOverlayLayer`: una capa con color HSB y opacidad variable

Este pipeline es aditivo: pinta por encima de la salida final, pero no reinterpreta los píxeles ajenos.

#### Gamma ramp

`DisplayTransferController` captura la tabla de transferencia base del display principal y genera una tabla derivada con `DisplayTransferTableBuilder`. La aplicación se realiza mediante:

- `CGGetDisplayTransferByTable`
- `CGSetDisplayTransferByTable`
- `CGDisplayRestoreColorSyncSettings`

Este pipeline cubre:

- `brightness`
- `contrast`
- `gamma`
- `temperature`

Opera a nivel del display principal y altera cómo el sistema traduce valores RGB antes de enviarlos al panel.

#### Coordinación

`OverlayWindowController` observa `appState.$liveParameters` y `appState.$isBypassed` con `Combine`. En cada cambio:

1. actualiza `OverlayView`
2. sincroniza `DisplayTransferController`
3. muestra u oculta la ventana overlay

El bypass afecta simultáneamente a ambos mecanismos.

### 4.5 Motivo de la separación overlay + gamma ramp

La arquitectura actual responde a un límite práctico observado en macOS: un intento anterior de aplicar todos los efectos mediante `CIFilter` sobre una ventana overlay transparente no producía un filtrado efectivo del escritorio completo en Apple Silicon. El filtro solo procesaba los píxeles de la propia ventana.

La solución implementada separa el pipeline según el tipo de efecto:

- overlay para dimming y color superpuesto
- gamma ramp para ajustes multiplicativos del display

### 4.6 Logging y recuperación

El proyecto usa `Logger` con subsystem `com.diegofernandezmunoz.ColorLayer` y categorías para `lifecycle`, `display`, `persistence` y `overlay`.

Además, existe un mecanismo de crash recovery basado en la clave `colorlayer.effectActive` en `UserDefaults`. Si la app detecta en el siguiente arranque que el efecto quedó marcado como activo, fuerza una restauración de ColorSync antes de continuar.

## 5. Estructura del repositorio

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

## 6. Componentes principales

### `ColorLayer/ColorLayerApp.swift`

- declara `@main`
- crea el `MenuBarExtra`
- expone `AppState.shared`
- inyecta una acción de apertura del editor desde `AppDelegate`

### `ColorLayer/AppState.swift`

- núcleo del estado observable
- gestiona selección, creación, duplicado, renombrado, borrado y reordenación de presets
- desacopla edición temporal (`liveParameters`) del preset persistido

### `ColorLayer/DisplayTransferController.swift`

- define la abstracción de hardware (`DisplayTransferHardware`)
- captura la tabla base del display
- construye tablas derivadas
- restaura el estado previo al desactivar el efecto o al cambiar el display principal

### `ColorLayer/Overlay/OverlayWindowController.swift`

- observa `AppState`
- sincroniza overlay + gamma ramp
- reacciona a `NSApplication.didChangeScreenParametersNotification`

### `ColorLayer/Persistence/PresetStore.swift`

- crea el directorio de `Application Support`
- guarda presets en JSON
- guarda sesión en `UserDefaults`
- repara la librería con `FactoryPresets.repairedLibrary(from:)`

### `ColorLayer/Models/FactoryPresets.swift`

- define presets semilla
- garantiza la presencia del preset bloqueado `Neutro`
- obliga a que el preset bloqueado quede al final

## 7. Modelos y contratos

### `FilterParameters`

Campos observables:

- `dimming`
- `brightness`
- `contrast`
- `gamma`
- `saturation`
- `temperature`
- `overlayHue`
- `overlaySaturation`
- `overlayBrightness`
- `overlayOpacity`

Es la unidad de configuración visual tanto para presets persistidos como para edición en vivo.

### `Preset`

Expone:

- `id`
- `name`
- `createdAt`
- `parameters`
- `isLocked`

### `SessionSnapshot`

Expone:

- `activePresetID`
- `isBypassed`

### `PresetStoring`

Desacopla `AppState` de la persistencia concreta mediante:

- `loadPresets()`
- `savePresets(_:)`
- `loadSession()`
- `saveSession(activePresetID:isBypassed:)`

## 8. Persistencia

### Presets

- Ruta: `Application Support/ColorLayer/presets.json`
- Formato: JSON con fechas `ISO8601`
- Comportamiento:
  - si no existe el archivo, se siembran presets iniciales
  - si el JSON está corrupto, se resemilla silenciosamente
  - si faltan o sobran elementos estructurales, se repara la librería

### Sesión

Claves observadas en `UserDefaults`:

- `colorlayer.activePresetID`
- `colorlayer.isBypassed`
- `colorlayer.effectActive`

## 9. Limitaciones y fronteras actuales

- El sistema opera sobre el display principal, no sobre una estrategia multi-display independiente.
- `saturation` existe en `FilterParameters` y en los presets, pero no forma parte del pipeline activo visible en la implementación actual.
- La cobertura automática se concentra en lógica no-UI; no hay tests directos para `MenuBarExtra`, ventanas AppKit ni overlay visual en ejecución real.
- `swift test` no valida recursos ni el target app de Xcode.
- La concentración de responsabilidades en `AppState` es deuda técnica conocida y aceptada.

La ausencia de `saturation` en el pipeline es coherente con la arquitectura actual: una saturación real requiere mezcla entre canales, algo que no puede resolverse correctamente solo con curvas RGB independientes.

## 10. Verificación observada

Se ejecutó:

```bash
swift test
```

Resultado observado:

- build correcta
- `21` tests ejecutados
- suite completada sin fallos

Cobertura observable:

- `AppStateTests`
- `DisplayTransferControllerTests`
- `PresetStoreTests`

## 11. Conclusión

`ColorLayer` es una app macOS pequeña pero técnicamente híbrida: combina shell de app con `SwiftUI` y `AppKit`, un overlay visual de pantalla completa y una gamma ramp del display coordinada desde un estado central. La implementación actual no persigue un pipeline único para todos los efectos, sino una separación explícita entre efectos aditivos y multiplicativos.

Ese diseño es el rasgo arquitectónico principal del repositorio actual y la base correcta para documentar, mantener y evolucionar el proyecto.
