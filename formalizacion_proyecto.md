# Formalización Técnica del Repositorio `ColorLayer`

## 1. Objetivo y alcance del documento

Este documento formaliza el estado actual observable del repositorio `ColorLayer` a partir de evidencia presente en el propio código, configuración, estructura de proyecto y pruebas automatizadas disponibles.

Su objetivo es servir como base descriptiva para una auditoría posterior. No evalúa calidad de implementación, no propone refactors y no emite recomendaciones de solución. Cuando una afirmación no puede confirmarse solo con el repositorio, se indica explícitamente como inferencia o limitación de observación.

### Metodología utilizada

- Inspección de estructura de carpetas y archivos fuente.
- Revisión de `Package.swift`.
- Revisión de `ColorLayer.xcodeproj/project.pbxproj` y del esquema compartido.
- Revisión de `Info.plist` y recursos incluidos.
- Revisión del código Swift de aplicación, dominio, persistencia, overlay y tests.
- Ejecución de `swift test` en el estado actual del repositorio.

### Criterio de verdad utilizado

La fuente principal de verdad para este documento es la implementación actual del repositorio. Este análisis no se apoya en un PRD independiente como base estructural ni como descripción fiable del sistema implementado.

## 2. Resumen ejecutivo del estado observable

`ColorLayer` es una aplicación macOS de tipo menubar, sin presencia en Dock, construida con una combinación de `SwiftUI` y `AppKit`. Su comportamiento observable se organiza alrededor de un estado compartido (`AppState`), una persistencia local de presets y sesión (`PresetStore`), una ventana overlay de pantalla completa (`OverlayWindowController` + `OverlayView`) y un controlador adicional de ajuste de tablas de transferencia de color del display (`DisplayTransferController`).

La interfaz visible se compone de dos superficies principales:

- Un panel de menubar para activar/desactivar el efecto y seleccionar presets.
- Una ventana independiente para edición de presets.

La persistencia de presets se realiza en JSON dentro de `Application Support`, mientras que el estado de sesión se guarda en `UserDefaults`.

Desde el punto de vista de build, el repositorio mantiene dos representaciones parciales del sistema:

- Un proyecto Xcode que define la aplicación completa.
- Un paquete SwiftPM que expone una librería parcial y ejecuta los tests automatizados disponibles.

## 3. Stack tecnológico completo

### 3.1 Lenguaje, toolchain y plataforma

- Lenguaje principal implementado: `Swift`.
- `swift-tools-version` declarado en `Package.swift`: `6.0`.
- `SWIFT_VERSION` configurado en Xcode para proyecto y targets: `6.0`.
- Toolchain local observada durante el análisis: `Apple Swift version 6.1.2`.
- Plataforma objetivo declarada:
  - SwiftPM: `macOS 13.0`.
  - Xcode target: `MACOSX_DEPLOYMENT_TARGET = 13.0`.
- Arquitectura observada en ejecución de tests: `arm64e-apple-macos14.0`.

### 3.2 Frameworks y módulos Apple detectados

Frameworks importados explícitamente en el código:

- `SwiftUI`
- `AppKit`
- `Combine`
- `Foundation`
- `CoreGraphics`
- `CoreImage`
- `QuartzCore`
- `Dispatch`
- `Testing`

Uso observable por área:

- `SwiftUI`: panel de menubar, editor de presets, composición de vistas.
- `AppKit`: ciclo de vida de app, ventanas, integración con `NSWindowController`, `NSApplicationDelegate`.
- `Combine`: observación reactiva del estado publicado por `AppState`.
- `Foundation`: modelos, codificación/decodificación, persistencia de archivos, fechas, `UserDefaults`.
- `CoreGraphics`: lectura y escritura de tablas de transferencia de color del display.
- `QuartzCore`: capas (`CALayer`) usadas por la vista overlay.
- `Dispatch`: manejo de señales del sistema.
- `Testing`: tests unitarios basados en el framework moderno de Apple, no en `XCTest`.

### 3.3 Sistema de build real

#### Proyecto Xcode

Existe un proyecto Xcode en `ColorLayer.xcodeproj` con:

- Target de aplicación: `ColorLayer.app`
- Target de tests: `ColorLayerTests.xctest`
- Esquema compartido: `ColorLayer.xcscheme`
- `compatibilityVersion`: `Xcode 15.0`
- `CreatedOnToolsVersion`: `16.0`
- `LastUpgradeVersion` del esquema: `1640`

Configuración relevante observable:

- `PRODUCT_BUNDLE_IDENTIFIER = com.diegofernandezmunoz.ColorLayer`
- `MARKETING_VERSION = 1.0`
- `CURRENT_PROJECT_VERSION = 1`
- `LSUIElement = true` en `Info.plist`, lo que configura la app como agente de UI sin icono normal de Dock
- `INFOPLIST_FILE = ColorLayer/Resources/Info.plist`

#### Swift Package Manager

Existe un `Package.swift` que define:

- Un producto de tipo librería: `ColorLayer`
- Un target regular `ColorLayer`
- Un target de tests `ColorLayerTests`

El target SwiftPM **no representa la app completa**, ya que excluye explícitamente:

- `Assets.xcassets`
- `ColorLayerApp.swift`
- `Overlay`
- `Resources`
- `UI`

Sí incluye:

- `AppState.swift`
- `DisplayTransferController.swift`
- `Models`
- `Persistence`

Esto convierte al paquete en una representación parcial del dominio y de parte de la lógica de infraestructura, no del producto completo tal y como se ejecuta desde Xcode.

### 3.4 Persistencia y almacenamiento

- Presets: archivo JSON en `Application Support/ColorLayer/presets.json`
- Sesión: `UserDefaults`
- Claves de sesión observadas:
  - `colorlayer.activePresetID`
  - `colorlayer.isBypassed`

### 3.5 Dependencias externas

- Dependencias de terceros detectadas: ninguna.
- Paquetes externos declarados en `Package.swift`: ninguno.
- Dependencias de paquete en el proyecto Xcode: ninguna.

## 4. Arquitectura general del proyecto

### 4.1 Vista de alto nivel

La arquitectura observable está organizada en cinco capas funcionales:

1. Capa de arranque y ciclo de vida de app.
2. Capa de estado global.
3. Capa de persistencia local.
4. Capa de interfaz y ventanas.
5. Capa de aplicación del efecto visual/colorimétrico.

### 4.2 Flujo principal observable

```text
ColorLayerApp (@main, SwiftUI)
  -> AppDelegate
    -> AppState.shared
    -> OverlayWindowController
      -> OverlayView
      -> DisplayTransferController
    -> PresetEditorWindowController (bajo demanda)

AppState
  -> PresetStore
  -> UI de menubar
  -> UI del editor
  -> OverlayWindowController (vía observación Combine)
```

### 4.3 Capa de arranque y ciclo de vida

`ColorLayerApp` declara la app SwiftUI y monta un `MenuBarExtra` con estilo `.window`. El ciclo de vida operativo se delega en `AppDelegate` mediante `@NSApplicationDelegateAdaptor`.

`AppDelegate`:

- Inicializa la infraestructura principal en `applicationDidFinishLaunching`.
- Restaura ajustes de ColorSync del sistema al arrancar.
- Crea `OverlayWindowController`.
- Gestiona la apertura de la ventana del editor.
- Restaura el estado visual del sistema al terminar la app.
- Instala un manejador explícito de señales `SIGTERM` y `SIGINT`.

### 4.4 Capa de estado

`AppState` es un objeto único, compartido y observable, anotado con `@MainActor` y basado en `ObservableObject` + `@Published`.

Responsabilidades observables:

- Mantener la librería de presets en memoria.
- Mantener el preset activo.
- Mantener el flag de bypass.
- Mantener `liveParameters`, separados de los parámetros persistidos del preset activo.
- Derivar estados de UI (`hasUnsavedChanges`, `menuBarSymbolName`, permisos de borrado/duplicado).
- Orquestar creación, duplicación, borrado, renombrado, reordenación y guardado de presets.
- Persistir presets y estado de sesión vía `PresetStore`.

### 4.5 Capa de persistencia

`PresetStore` implementa el protocolo `PresetStoring` y centraliza:

- Creación del directorio de almacenamiento.
- Lectura y escritura de `presets.json`.
- Lectura y escritura del estado de sesión en `UserDefaults`.
- Codificación/decodificación JSON con fechas `ISO8601`.
- Reparación de datos al cargar mediante `FactoryPresets.repairedLibrary`.

### 4.6 Capa de interfaz

La UI observable se divide en:

- Panel de menubar: `MenuBarPanelView`
- Ventana de edición: `PresetEditorWindowController`
- Vista raíz del editor: `PresetEditorView`
- Lista de presets: `PresetListView`
- Vista de parámetros: `FilterParametersView`

La UI consume y modifica `AppState` directamente mediante `@ObservedObject`.

### 4.7 Capa de overlay y aplicación del efecto

El efecto visual observable se implementa con dos mecanismos coexistentes:

1. `OverlayView`
   - Aplica dos capas sobre una `NSView`:
     - una capa de dimming negra
     - una capa de color overlay
   - Está montada dentro de una ventana fullscreen transparente.

2. `DisplayTransferController`
   - Lee la tabla base de transferencia del display principal.
   - Calcula una nueva tabla según brillo, contraste, gamma y temperatura.
   - La aplica mediante APIs `CGGetDisplayTransferByTable` y `CGSetDisplayTransferByTable`.
   - Puede restaurar el estado base del display.

`OverlayWindowController` conecta ambos mecanismos:

- observa `liveParameters` e `isBypassed` con `Combine`
- actualiza la vista overlay
- sincroniza el controlador de transferencia de display
- muestra u oculta la ventana overlay
- reacciona a cambios de configuración de pantallas

### 4.8 Límite entre lo implementado y lo declarativo

La manipulación de color efectiva del sistema se concentra en `DisplayTransferController`, mientras que el overlay visual se resuelve mediante capas AppKit/Core Animation.

## 5. Árbol de módulos y componentes con su función

### 5.1 Árbol relevante del repositorio

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
├── Assets.xcassets/
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

Package.swift
ColorLayer.xcodeproj/
```

### 5.2 Módulo de arranque y shell de aplicación

#### `ColorLayer/ColorLayerApp.swift`

Responsabilidad:

- Declarar el punto de entrada `@main`.
- Crear el `MenuBarExtra`.
- Integrar `AppDelegate`.
- Exponer `AppState.shared` a la UI de menubar.

Relaciones principales:

- consume `AppState`
- monta `MenuBarPanelView`
- delega operaciones de sistema y ventanas a `AppDelegate`

#### `AppDelegate` dentro de `ColorLayerApp.swift`

Responsabilidad:

- Inicializar overlay y editor.
- Manejar restauración del sistema en arranque y cierre.
- Gestionar señales del sistema.

Relaciones principales:

- crea `OverlayWindowController`
- crea `PresetEditorWindowController` bajo demanda
- usa `AppState.shared`

### 5.3 Módulo de estado

#### `ColorLayer/AppState.swift`

Responsabilidad:

- Fuente central de estado observable.
- Gestión de sesión y presets en memoria.
- Coordinación de acciones de negocio sobre presets.

Relaciones principales:

- depende de `PresetStoring`
- usa `Preset`, `FilterParameters`, `FactoryPresets`, `SessionSnapshot`
- es consumido por todas las vistas SwiftUI y por el overlay

### 5.4 Módulo de ajuste de transferencia de display

#### `ColorLayer/DisplayTransferController.swift`

Responsabilidad:

- Definir tipos y protocolos para interactuar con tablas de gamma/transferencia de color del display.
- Construir tablas derivadas desde parámetros del preset.
- Aplicar y restaurar tablas del display principal.

Subcomponentes observables:

- `DisplayTransferTable`
- `DisplayTransferHardware`
- `CoreGraphicsDisplayTransferHardware`
- `DisplayTransferTableBuilder`
- `DisplayTransferController`

Relaciones principales:

- usa `FilterParameters`
- es usado por `OverlayWindowController`

### 5.5 Módulo de modelos

#### `ColorLayer/Models/FilterParameters.swift`

Responsabilidad:

- Definir la estructura de parámetros visuales editables y persistibles.
- Gestionar compatibilidad de decodificación para `overlayBrightness`.

Relaciones principales:

- embebido en `Preset`
- usado por `AppState`, `OverlayView`, `DisplayTransferController`, tests y editor

#### `ColorLayer/Models/Preset.swift`

Responsabilidad:

- Definir la entidad persistible y seleccionable de preset.

Relaciones principales:

- usado por `AppState`, `PresetStore`, UI y tests

#### `ColorLayer/Models/FactoryPresets.swift`

Responsabilidad:

- Declarar presets semilla.
- Declarar el preset neutro bloqueado.
- Reparar bibliotecas cargadas para asegurar unicidad de IDs, neutral fijo y normalización de `isLocked`.

Relaciones principales:

- usado por `AppState` y `PresetStore`
- cubierto por tests de comportamiento indirecto

### 5.6 Módulo de persistencia

#### `ColorLayer/Persistence/PresetStore.swift`

Responsabilidad:

- Persistencia de presets.
- Persistencia de sesión.
- Normalización de biblioteca leída.
- Inicialización del almacenamiento en primera ejecución.

Relaciones principales:

- implementa `PresetStoring`
- consumido por `AppState`
- cubierto por `PresetStoreTests`

### 5.7 Módulo de overlay

#### `ColorLayer/Overlay/OverlayView.swift`

Responsabilidad:

- Dibujar la parte puramente visual del overlay mediante dos `CALayer`.
- Aplicar `dimming` y color overlay.

Relaciones principales:

- usado por `OverlayWindowController`
- consume `FilterParameters`

#### `ColorLayer/Overlay/OverlayWindowController.swift`

Responsabilidad:

- Crear y configurar la ventana overlay.
- Observar cambios de `AppState`.
- Sincronizar overlay visual y transferencia de display.
- Responder a cambios de pantalla.

Relaciones principales:

- depende de `AppState`
- usa `OverlayView`
- usa `DisplayTransferController`

### 5.8 Módulo de UI de menubar

#### `ColorLayer/UI/MenuBarPanel/MenuBarPanelView.swift`

Responsabilidad:

- Renderizar el panel desplegable del menubar.
- Permitir encender/apagar el efecto vía bypass.
- Permitir seleccionar presets.
- Abrir la ventana del editor.

Relaciones principales:

- consume `AppState`
- llama a `AppDelegate.shared?.showPresetEditor()`

### 5.9 Módulo de editor de presets

#### `ColorLayer/UI/PresetEditor/PresetEditorWindowController.swift`

Responsabilidad:

- Crear la ventana del editor.
- Montar `PresetEditorView`.
- Interceptar cierre para ocultar la ventana y descartar cambios no guardados.

#### `ColorLayer/UI/PresetEditor/PresetEditorView.swift`

Responsabilidad:

- Componer la estructura general del editor en dos columnas.

#### `ColorLayer/UI/PresetEditor/PresetListView.swift`

Responsabilidad:

- Listar presets.
- Crear, renombrar, duplicar, borrar y reordenar presets editables.
- Mantener el preset neutro bloqueado al final de la lista.

#### `ColorLayer/UI/PresetEditor/FilterParametersView.swift`

Responsabilidad:

- Mostrar y editar parámetros del preset activo.
- Exponer acciones de guardar y descartar.
- Convertir color de `ColorPicker` a hue/saturation/brightness para el overlay.

### 5.10 Módulo de recursos y configuración

#### `ColorLayer/Resources/Info.plist`

Responsabilidad:

- Configuración base del bundle de aplicación.
- Declarar `LSUIElement = true`, confirmando que la app se comporta como utility de menubar.

#### `ColorLayer/Assets.xcassets`

Responsabilidad:

- Catálogo de assets del target de app.
- Se observa `AccentColor` definido.

### 5.11 Módulo de tests

#### `ColorLayerTests/AppStateTests.swift`

Cobertura observable:

- selección inválida
- creación de presets
- duplicación
- neutral bloqueado
- guardado/descartado
- reordenación y borrado
- símbolo de menubar

#### `ColorLayerTests/DisplayTransferControllerTests.swift`

Cobertura observable:

- invariantes del builder de tablas
- neutralidad
- brillo, contraste, gamma y temperatura
- captura/restauración de tabla base
- reconfiguración de display

#### `ColorLayerTests/PresetStoreTests.swift`

Cobertura observable:

- primera ejecución
- reseed ante JSON corrupto
- compatibilidad con JSON legacy sin `overlayBrightness`
- round-trip de sesión

## 6. Interfaces y tipos clave observados

### `FilterParameters`

Tipo estructural `Codable, Equatable` que expone:

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

Rol:

- Es la unidad central de configuración visual.
- Se usa tanto como estado en vivo (`liveParameters`) como dentro de cada `Preset`.

### `Preset`

Tipo `Codable, Equatable, Identifiable` que expone:

- `id`
- `name`
- `createdAt`
- `parameters`
- `isLocked`

Rol:

- Representa una configuración persistible y seleccionable por el usuario.

### `SessionSnapshot`

Tipo `Equatable` que expone:

- `activePresetID`
- `isBypassed`

Rol:

- Representa el estado mínimo de sesión persistido en `UserDefaults`.

### `PresetStoring`

Protocolo que expone:

- `loadPresets()`
- `savePresets(_:)`
- `loadSession()`
- `saveSession(activePresetID:isBypassed:)`

Rol:

- Desacopla `AppState` de la implementación concreta de persistencia.

### `DisplayTransferHardware`

Protocolo que expone:

- restauración de ColorSync
- consulta de display principal
- consulta de capacidad de tabla gamma
- lectura de tabla actual
- escritura de tabla

Rol:

- Abstrae la interacción de bajo nivel con CoreGraphics para permitir tests mediante fake hardware.

### `DisplayTransferTable`

Tipo `Equatable` con tres canales:

- `red`
- `green`
- `blue`

Rol:

- Encapsula la tabla de transferencia del display y la noción de baseline lineal o capturada.

## 7. Decisiones técnicas detectables

### 7.1 Patrones y enfoques de diseño observables

- **Singleton de estado compartido**: `AppState.shared`.
- **Estado observable basado en publicación reactiva**: `ObservableObject` + `@Published`.
- **Inyección de dependencias por protocolo**:
  - `PresetStoring`
  - `DisplayTransferHardware`
- **Normalización defensiva de datos al cargar**:
  - `FactoryPresets.repairedLibrary(from:)`
- **Separación parcial entre lógica testeable y shell de aplicación**:
  - SwiftPM contiene dominio/persistencia/controlador de display
  - Xcode contiene además UI, recursos y ciclo de vida completo
- **Bridge SwiftUI + AppKit**:
  - `@NSApplicationDelegateAdaptor`
  - `NSWindowController`
  - `NSHostingController`
- **Observación reactiva del estado hacia infraestructura visual**:
  - `OverlayWindowController` escucha cambios con `Combine`
- **Uso de fakes para pruebas unitarias**:
  - `FakeDisplayTransferHardware`
  - `InMemoryPresetStore`

### 7.2 Librerías elegidas y propósito observable

- `SwiftUI`: panel de menubar y vistas del editor.
- `AppKit`: lifecycle, ventanas dedicadas y utilidades de escritorio.
- `Combine`: propagación de cambios de estado hacia overlay.
- `CoreGraphics`: aplicación de ajustes de color a nivel de display.
- `CoreImage`: pipeline declarado pero no integrado activamente.
- `QuartzCore`: implementación visual del overlay por capas.
- `Testing`: suite unitaria.

### 7.3 Decisiones funcionales inferibles desde el código

- La aplicación está pensada para operar como utilidad residente de menubar.
- El preset neutro es un elemento especial, bloqueado y reinyectado por normalización.
- El estado de edición en vivo se separa del estado persistido del preset.
- La app intenta restaurar el estado visual del sistema al salir y al recibir señales de terminación.

Estas decisiones son inferencias razonables porque están respaldadas por el comportamiento del código, aunque no exista en el repositorio una especificación ejecutable única que las describa formalmente.

## 8. Deuda técnica evidente y objetivable

Esta sección describe deuda técnica observable, sin entrar todavía en juicio de severidad ni en propuestas de solución.

### 8.1 Divergencia entre `Package.swift` y el producto real

El paquete SwiftPM solo incluye una parte del sistema y excluye explícitamente la UI, recursos, overlay y punto de entrada de aplicación. Esto produce una representación incompleta del producto frente al target real de Xcode.

### 8.2 Cobertura de tests concentrada en lógica no-UI

Los tests disponibles cubren:

- `AppState`
- `PresetStore`
- `DisplayTransferController`

No se detecta cobertura automatizada para:

- `ColorLayerApp`
- `AppDelegate`
- `OverlayWindowController`
- `OverlayView`
- `MenuBarPanelView`
- `PresetEditorWindowController`
- vistas SwiftUI del editor

### 8.4 Coexistencia de dos vías de efecto visual

El sistema actual combina:

- overlay por capas (`OverlayView`)
- ajuste de transferencia del display (`DisplayTransferController`)

No se observa una única estrategia consolidada o una capa explícita que documente la frontera entre ambas responsabilidades.

### 8.5 Dependencia de UI hacia `AppDelegate.shared`

`MenuBarPanelView` invoca la apertura del editor a través de `AppDelegate.shared`, acoplando una vista SwiftUI con un singleton concreto de infraestructura.

### 8.6 Concentración de responsabilidades en `AppState`

`AppState` agrupa:

- estado observable
- reglas de selección
- acciones de edición de presets
- persistencia de sesión
- persistencia de biblioteca

La mezcla es observable aunque funcione correctamente; aquí se registra únicamente como concentración de responsabilidades.

## 9. Inconsistencias y anomalías detectadas

### 9.1 `Package.swift` no representa la app completa

El paquete excluye `UI`, `Overlay`, `Resources` y `ColorLayerApp.swift`. Por tanto, `swift test` valida una librería parcial, no el producto macOS completo definido por el proyecto Xcode.

### 9.2 Narrativa tecnológica dual sobre color

La implementación real que sí está conectada al flujo principal usa APIs `CGDisplayTransfer*` para aplicar parte de los ajustes, en coordinación con un overlay visual por capas para la atenuación y el tinte.

### 9.5 Diferencia entre “lo compilable por SwiftPM” y “lo ejecutable por Xcode”

El repositorio mantiene dos superficies de verdad parciales:

- SwiftPM para librería y tests
- Xcode para la app completa

Esto no es necesariamente incorrecto, pero sí constituye una anomalía documental y estructural relevante para auditoría porque el alcance de cada sistema de build no coincide.

## 10. Estado de pruebas y verificaciones observadas

### 10.1 Verificación ejecutada

Se ejecutó:

```bash
swift test
```

Resultado observable:

- La suite pasó correctamente.
- Total de tests observados: `21`.

### 10.2 Qué valida realmente `swift test`

Valida la porción del sistema contenida en el target SwiftPM:

- modelos
- `AppState`
- `PresetStore`
- `DisplayTransferController`

No valida de forma directa:

- el target app de Xcode
- recursos del bundle
- `Info.plist`
- `MenuBarExtra`
- ventanas AppKit
- overlay real en ejecución

### 10.3 Limitación de entorno observada

Durante este análisis no fue posible ejecutar `xcodebuild -version` porque el entorno local activo apuntaba a `CommandLineTools` en lugar de a una instalación activa de Xcode completa. Esta limitación se registra como condición del entorno de análisis, no como una propiedad del repositorio.

## 11. Artefactos de configuración y build relevantes

### Artefactos principales observados

- `Package.swift`
- `ColorLayer.xcodeproj/project.pbxproj`
- `ColorLayer.xcodeproj/xcshareddata/xcschemes/ColorLayer.xcscheme`
- `ColorLayer/Resources/Info.plist`
- `ColorLayer/Assets.xcassets/Contents.json`
- `ColorLayer/Assets.xcassets/AccentColor.colorset/Contents.json`

### Datos configurados observables

- Producto app: `ColorLayer.app`
- Producto tests: `ColorLayerTests.xctest`
- Bundle ID app: `com.diegofernandezmunoz.ColorLayer`
- Bundle ID tests: `com.diegofernandezmunoz.ColorLayerTests`
- Marketing version: `1.0`
- Current project version: `1`
- Deployment target: `13.0`
- `LSUIElement = true`
- `ENABLE_USER_SCRIPT_SANDBOXING = NO` a nivel de proyecto Xcode
- `SWIFT_STRICT_CONCURRENCY = complete` a nivel de proyecto Xcode

## 12. Mapa funcional consolidado

### Lo implementado de forma verificable

- App macOS de menubar sin Dock normal.
- Selección y edición de presets.
- Persistencia local de presets y estado de sesión.
- Overlay visual por capas.
- Ajuste de color a nivel de tabla de transferencia del display.
- Restauración del sistema al terminar.
- Suite unitaria sobre la parte no-UI del sistema.

### Lo declarado pero no verificable como flujo activo desde el código observado

- Uso efectivo de `CoreImage` como pipeline operativo principal.

### Lo no confirmable solo con este repositorio

- Comportamiento visual exacto del producto ejecutado bajo Xcode en un entorno macOS real con pantalla física.
- Correspondencia entre intención de producto y realidad implementada más allá de lo observable en código y configuración.

## 13. Cierre

El repositorio `ColorLayer` describe un producto macOS pequeño pero estructuralmente híbrido: parte del sistema está modelada como librería SwiftPM testeable, mientras que la app real depende del proyecto Xcode y de componentes de UI/AppKit excluidos del paquete. La arquitectura observable gira en torno a un estado global único, persistencia local sencilla, una interfaz de menubar, un editor de presets y una combinación de overlay visual con manipulación de transferencia de color del display.

Este documento debe considerarse una base descriptiva de inventario técnico fiel al estado actual observado, no una validación funcional completa del producto final ni una evaluación de calidad.
