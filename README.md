# Leerraum

App personal de productividad y bienestar construida con SwiftUI + SwiftData para iPhone, con widget de resumen y recordatorios locales.

## Contenido

- [Vision general](#vision-general)
- [Funcionalidades](#funcionalidades)
- [Stack tecnico](#stack-tecnico)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Requisitos](#requisitos)
- [Instalacion y ejecucion](#instalacion-y-ejecucion)
- [Instalacion en iPhone fisico](#instalacion-en-iphone-fisico)
- [Notificaciones](#notificaciones)
- [Widget](#widget)
- [Persistencia de datos](#persistencia-de-datos)
- [Observabilidad](#observabilidad)
- [Flujo recomendado de desarrollo](#flujo-recomendado-de-desarrollo)

## Vision general

Leerraum centraliza en una sola app:

- finanzas personales
- rutinas de gym y registro de sets
- registro de comidas
- frases y recordatorios motivacionales
- medidas corporales
- recomendaciones (series, peliculas, musica, etc.)
- ideas para la app y metas de vida

La app esta pensada para uso local y rapido, priorizando una UI nativa en SwiftUI y almacenamiento con SwiftData.

## Funcionalidades

### Finanzas

- Registro de movimientos: ingreso, gasto y transferencia.
- Cuentas (efectivo, banco, tarjeta).
- Presupuestos por categoria.
- Transacciones fijas mensuales.
- Metas de ahorro.
- Reportes semanales, mensuales y anuales.
- Soporte de moneda MXN/USD (normalizacion a MXN para metricas).

### Gym

- Rutinas con ejercicios, series, repeticiones y peso.
- Registro de sets realizados e historial.
- Temporizador de descanso con notificacion local.

### Comidas

- Registro por tipo de comida (desayuno, comida, cena, snack).
- Calorias, proteina y notas.

### Frases

- Mensajes motivacionales con autor.
- Activacion/desactivacion de frases.
- Recordatorios aleatorios diarios.
- Deep link interno desde la notificacion hacia la frase.

### Mas

- Medidas corporales (peso, cintura, grasa corporal, etc.).
- Recomendaciones por tipo (serie, pelicula, libro, podcast, etc.).
- Ideas de app con estatus.
- Metas de vida con prioridad, area y progreso.
- Ajustes de apariencia (tema sistema/claro/oscuro).

## Stack tecnico

- `SwiftUI` para interfaz.
- `SwiftData` para persistencia local.
- `WidgetKit` para el widget `LeerraumWidget`.
- `UserNotifications` para recordatorios locales.
- `OSLog` + `OSSignposter` para trazas y metricas.

## Estructura del proyecto

```text
Leerraum/
├── Leerraum/                       # Target principal de la app
│   ├── LeerraumApp.swift           # Punto de entrada + configuracion de notificaciones
│   ├── RootTabView.swift           # Navegacion principal por tabs
│   ├── ContentView.swift           # Dashboard de finanzas
│   ├── Transaction.swift           # Modelos SwiftData y enums del dominio
│   ├── GymView.swift               # Modulo gym
│   ├── FoodLogView.swift           # Modulo comidas
│   ├── QuotesView.swift            # Modulo frases
│   ├── RecommendationsView.swift   # Recomendaciones
│   ├── BodyMeasurementsView.swift  # Medidas corporales
│   ├── AppIdeasView.swift          # Ideas de app
│   ├── LifeGoalsView.swift         # Metas de vida
│   ├── FinanceDashboardViewModel.swift
│   └── Observability.swift
├── LeerraumWidget/                 # Extension WidgetKit
│   ├── LeerraumWidgetBundle.swift
│   └── LeerraumSummaryWidget.swift
└── Leerraum.xcodeproj
```

## Requisitos

- macOS con Xcode instalado.
- Cuenta de Apple Developer iniciada en Xcode para firmar en dispositivo fisico.
- iPhone con Modo desarrollador habilitado si vas a instalar directo.

Notas actuales del proyecto:

- Bundle app: `brangarciaramos.Leerraum`
- Bundle widget: `brangarciaramos.Leerraum.widget`

## Instalacion y ejecucion

### Opcion 1: Xcode (recomendada)

1. Abre `Leerraum.xcodeproj`.
2. Selecciona el esquema `Leerraum`.
3. Elige un simulador o tu iPhone.
4. Presiona Run (`Cmd + R`).

### Opcion 2: Terminal

Compilar para simulador:

```bash
xcodebuild -project "Leerraum.xcodeproj" \
  -scheme "Leerraum" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  build
```

## Instalacion en iPhone fisico

1. Conecta el iPhone por cable o red local.
2. Verifica dispositivos:

```bash
xcrun xctrace list devices
```

3. Compila para el UDID de tu iPhone (con provisioning automatico):

```bash
xcodebuild -project "Leerraum.xcodeproj" \
  -scheme "Leerraum" \
  -configuration Debug \
  -destination "id=<TU_UDID>" \
  -allowProvisioningUpdates \
  -derivedDataPath .build \
  build
```

4. Instala app:

```bash
xcrun devicectl device install app \
  --device "<TU_UDID>" \
  ".build/Build/Products/Debug-iphoneos/Leerraum.app"
```

5. Lanza app:

```bash
xcrun devicectl device process launch \
  --device "<TU_UDID>" \
  brangarciaramos.Leerraum
```

Si iOS bloquea la app:

- Activa `Modo desarrollador` en el iPhone.
- Confia en el certificado desde `Ajustes > General > VPN y gestion de dispositivos`.

## Notificaciones

La app programa recordatorios locales para:

- fin de descanso en gym
- cierre mensual de finanzas
- frases aleatorias activas

Archivo principal de esta logica: `Leerraum/LeerraumApp.swift` (`AppNotificationService`).

## Widget

`LeerraumWidget` incluye un widget de resumen con tips rotativos y accesos visuales a secciones principales.

Archivo principal: `LeerraumWidget/LeerraumSummaryWidget.swift`.

## Persistencia de datos

Los modelos viven en `Leerraum/Transaction.swift` y se registran en el `modelContainer` de `LeerraumApp`.

Principales entidades:

- `Transaction`, `FixedTransaction`, `Account`, `CategoryBudget`, `SavingsGoal`
- `GymRoutine`, `GymExercise`, `GymSetRecord`
- `FoodEntry`
- `QuoteMessage`
- `BodyMeasurementEntry`
- `RecommendationEntry`
- `AppIdeaNote`
- `LifeGoal`

## Observabilidad

El proyecto usa `OSLog` y `OSSignposter` para seguimiento de eventos de:

- navegacion
- notificaciones
- finanzas
- gym
- comida
- medidas corporales
- recomendaciones

Definicion central: `Leerraum/Observability.swift`.

## Flujo recomendado de desarrollo

1. Trabaja en una rama por feature.
2. Ejecuta la app en simulador y en iPhone fisico para validar UI + notificaciones.
3. Revisa que no se suban artefactos locales (`.build`, `DerivedData`, `xcuserdata`).
4. Haz commits pequenos y descriptivos.

