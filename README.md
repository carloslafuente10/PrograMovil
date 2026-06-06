<div align="center">
  <img src="assets/images/yagu_reportes.PNG"  alt="YAGU logo" width="140"/>

  <h1>🐆 YAGU</h1>
  <p><strong>Aplicación móvil de recetas con asistencia de inteligencia artificial</strong></p>
  <p><em>Descubre, planifica y cocina.</em></p>

  <p>
    <img src="https://img.shields.io/badge/Flutter-3.41.5-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
    <img src="https://img.shields.io/badge/Dart-3.11.3-0175C2?logo=dart&logoColor=white" alt="Dart"/>
    <img src="https://img.shields.io/badge/Firebase-BaaS-FFCA28?logo=firebase&logoColor=black" alt="Firebase"/>
    <img src="https://img.shields.io/badge/Groq-IA%20Assistant-F55036?logoColor=white" alt="Groq"/>
    <img src="https://img.shields.io/badge/Cloudinary-Imágenes-3448C5?logo=cloudinary&logoColor=white" alt="Cloudinary"/>
    <img src="https://img.shields.io/badge/Proyecto%20Académico-UMSS-8B0000" alt="UMSS"/>
  </p>

  <p>
    <a href="#-descripción">Descripción</a> ·
    <a href="#-estado-del-proyecto">Estado</a> ·
    <a href="#-características-principales">Características</a> ·
    <a href="#-arquitectura-y-tecnologías">Arquitectura</a> ·
    <a href="#️-modelo-de-datos">Modelo de datos</a> ·
    <a href="#-instalación-y-configuración">Instalación</a> ·
    <a href="#-estructura-del-proyecto">Estructura</a> ·
    <a href="#-equipo">Equipo</a>
  </p>
</div>

---

## 📖 Descripción

**YAGU** es una aplicación móvil de recetas desarrollada como proyecto académico para la materia de **Programación móvil** en la **Universidad Mayor de San Simón (UMSS)**, Bolivia.

El nombre proviene del *jaguar* (*yaguar* en guaraní), símbolo de precisión, instinto y adaptación — cualidades que definen la filosofía de la app: ayudarte a cocinar con inteligencia, adaptando cada receta a tus necesidades reales.

La app nace de un problema cotidiano: **adaptar recetas a diferentes cantidades de comensales**. YAGU permite descubrir recetas de la cocina boliviana, planificar comidas semanales, crear y compartir recetas propias, y contar con asistencia de IA, todo desde una sola plataforma.

Cuenta además con un **panel de administración completo** para gestión de contenido, revisión de recetas, reportes exportables y auditoría de actividades.

---

## 📊 Estado del proyecto

> **Entrega final:** 05 de junio de 2026 · Gestión 2026

| Módulo | Funcionalidad | Estado |
|---|---|:---:|
| **Autenticación** | Registro e inicio de sesión con Firebase | ✅ |
| | Recuperación de contraseña por OTP con EmailJS | ✅ |
| **Exploración** | Catálogo de recetas con búsqueda por texto | ✅ |
| | Filtros múltiples (categoría + tiempo + calorías) | ✅ |
| | Recetas recomendadas y rápidas en Home | ✅ |
| **Interacción** | Ajuste dinámico de porciones | ✅ |
| | Checklist interactivo de ingredientes | ✅ |
| | Ingrediente primordial (★) | ✅ |
| | Sugerencias de sustitutos | ✅ |
| | Sistema de reseñas y calificación | ✅ |
| **Favoritos** | Marcar, desmarcar y listar favoritos | ✅ |
| **Planificación** | Planificador semanal de comidas | ✅ |
| | Porciones y exportación en planificador | ✅ |
| **Inteligencia Artificial** | Asistente de chat A.L.I.C.I.A. (Groq) | ✅ |
| | Asistente de voz NID (Gemini + TTS) | ✅ |
| **Perfil** | Edición de nombre y foto de perfil | ✅ |
| | Gestión de recetas personales | ✅ |
| **Administración** | Panel de control con dashboard | ✅ |
| | CRUD de recetas, categorías y usuarios | ✅ |
| | Revisión y aprobación de recetas | ✅ |
| | Notificaciones admin → usuario | ✅ |
| **Reportes** | Reportes de actividad de usuarios | ✅ |
| | Exportación a PDF, Excel y CSV | ✅ |
| | Historial de actividades (bitácora) | ✅ |

---

## 🚀 Características principales

### 👤 Para usuarios

| Módulo | Funcionalidades |
|---|---|
| **Acceso** | Registro, inicio de sesión y recuperación de contraseña por OTP. |
| **Exploración** | Catálogo de recetas bolivianas, búsqueda en tiempo real y filtros combinados por categoría, tiempo y calorías. |
| **Vista de receta** | Detalle completo con imagen, ingredientes, pasos, tiempo, calorías y calificación promedio. |
| **Porciones** | Ajuste dinámico (+/-) con recálculo automático de cantidades de ingredientes. |
| **Ingredientes** | Checklist interactivo, marcado de ingredientes primordiales (★) y sugerencias de sustitutos. |
| **Favoritos** | Guardar y gestionar recetas favoritas con sincronización en Firestore. |
| **Planificador** | Organizar comidas (desayuno, almuerzo y cena) por día con porciones personalizadas. |
| **Recetas propias** | Crear, editar y enviar a revisión recetas personales con fotos. |
| **IA — A.L.I.C.I.A.** | Asistente conversacional para sugerencias de recetas e ingredientes alternativos. |
| **IA — NID** | Asistente de voz con reconocimiento de habla y respuesta sintetizada. |
| **Notificaciones** | Alertas sobre el estado de aprobación de tus recetas enviadas. |
| **Reseñas** | Calificación con estrellas y comentarios en recetas del catálogo. |

### 👨‍💼 Para administradores

| Módulo | Funcionalidades |
|---|---|
| **Gestión de contenido** | CRUD completo de recetas y categorías del catálogo. |
| **Moderación** | Revisión, aprobación o rechazo de recetas enviadas por usuarios. |
| **Gestión de usuarios** | Visualización, habilitación e inhabilitación de cuentas. |
| **Reportes** | Generación de reportes de actividad filtrados por estado (activo, inactivo, inhabilitado). |
| **Exportación** | Descarga de reportes en PDF, Excel y CSV. |
| **Notificaciones** | Envío de alertas y mensajes a usuarios del sistema. |
| **Auditoría** | Historial completo de acciones registradas en la bitácora del sistema. |

---

## 🤖 Asistentes de IA

YAGU integra dos asistentes basados en inteligencia artificial con personalidades distintas:

### 🟢 A.L.I.C.I.A. — Asistente conversacional
> *Asistente de Lectura Inteligente de Cocina e Ingredientes Adaptados*

- Powered by **Groq API** (modelo `llama3` o equivalente)
- Responde preguntas sobre recetas, ingredientes y sustituciones
- Interfaz de chat fluida en `sugerencias_chat_screen.dart`
- Manejo de errores de API con mensajes controlados

### 🔵 NID — Asistente de voz
> *Navegador Inteligente por Diálogo*

- Powered by **Groq API** + `speech_to_text` + `flutter_tts`
- Escucha comandos de voz y responde de forma hablada
- Permisos de audio configurados para Android
- Pantalla dedicada `voice_call_screen.dart`

---

## 🏗️ Arquitectura y tecnologías

La aplicación sigue una arquitectura **modular inspirada en MVC**, adaptada al ecosistema Flutter con separación clara entre vistas, estado, servicios y modelos.

```
┌─────────────────────────────────────────────────────────┐
│              App Móvil YAGU (Flutter)                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │ Screens  │→ │Providers │→ │ Services │→ │ Models │  │
│  │ (Views)  │  │ (Estado) │  │  (APIs)  │  │ (Data) │  │
│  └──────────┘  └──────────┘  └──────────┘  └────────┘  │
└───────────────┬──────────────────┬──────────────────────┘
                │                  │
     ┌──────────▼──────┐  ┌────────▼──────────────────┐
     │  Firebase        │  │  APIs Externas             │
     │  · Auth          │  │  · Groq  (chat IA)         │
     │  · Firestore     │  │  · Gemini (voz IA)         │
     │                  │  │  · Cloudinary (imágenes)   │
     └──────────────────┘  │  · EmailJS (OTP)           │
                           └────────────────────────────┘
```

### Capas internas

| Capa | Descripción |
|---|---|
| **Screens / Widgets** | Solo renderizan la UI y capturan acciones del usuario. Sin lógica de negocio. |
| **Providers** | Gestionan el estado reactivo con el paquete `provider`. Notifican a los widgets. |
| **Services** | Encapsulan toda la comunicación con Firebase, Cloudinary y las APIs de IA. |
| **Models** | Definen las entidades del dominio (`Receta`, `Usuario`, `Plan`, etc.) y su mapeo a Firestore. |

### Pila tecnológica

| Categoría | Tecnología | Versión | Propósito |
|---|---|---|---|
| Framework | Flutter / Dart | 3.41.5 / 3.11.3 | Desarrollo multiplataforma |
| Backend (BaaS) | Firebase Auth | ^6.3.0 | Autenticación y gestión de sesión |
| Base de datos | Cloud Firestore | ^6.2.0 | BD NoSQL en tiempo real |
| Imágenes | Cloudinary | — | Almacenamiento y entrega de imágenes |
| IA conversacional | Groq API (HTTP) | — | Asistente A.L.I.C.I.A. |
| IA de voz | Groq API (HTTP) | — | Asistente NID |
| Estado | Provider | ^6.1.5+1 | Gestión de estado reactivo |
| Reportes | pdf / excel / csv | ^3.10.8 / ^2.1.0 / ^5.0.2 | Exportación en múltiples formatos |
| Voz | speech_to_text / flutter_tts | ^7.4.0 / ^4.2.5 | Entrada y salida de voz |
| Entorno | flutter_dotenv | ^5.1.0 | Variables de entorno y claves API |
| Comunicación | http | ^1.6.0 | Peticiones a APIs externas |
| Email | EmailJS | — | Envío de códigos OTP |
| Utilidades | lottie, iconsax, open_file | — | Animaciones, iconografía, apertura de archivos |

> **Nota técnica:** Se migró de **Firebase Storage** a **Cloudinary** debido a problemas de memoria durante el build en equipos con 8 GB de RAM. Se eligió **Groq** por su generoso plan gratuito para desarrolladores.

---

## 🗄️ Modelo de datos

YAGU utiliza **Cloud Firestore** como base de datos principal con la siguiente estructura de colecciones:

| Colección | Descripción |
|---|---|
| `app-usuarios` | Datos de usuarios: nombre, correo, rol, lista de favoritos. |
| `app-recetas-completas` | Catálogo de recetas publicadas y visibles para todos. |
| `recetas-personales` | Recetas creadas por usuarios (borradores y envíos pendientes). |
| `recetas-pendientes` | Recetas enviadas a revisión por el administrador. |
| `ingredientes-maestros` | Catálogo global de ingredientes con sustitutos y equivalencias. |
| `app-planes` | Planificación de comidas por usuario y fecha. |
| `notifications` | Sistema de notificaciones entre administrador y usuarios. |
| `app-historial` | Bitácora de actividades para auditoría del sistema. |
| `app-reportes` | Reportes y sugerencias enviados por usuarios. |

---

## ⚙️ Instalación y configuración

### Requisitos previos

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (versión 3.x)
- Dart SDK 3.x
- Android Studio o VS Code con extensiones Flutter/Dart
- Proyecto configurado en [Firebase Console](https://console.firebase.google.com/)
- Cuenta en [Cloudinary](https://cloudinary.com/)
- Claves de API de [Groq](https://console.groq.com/) 
- Cuenta en [EmailJS](https://www.emailjs.com/) con template de OTP configurado

### Pasos

**1. Clonar el repositorio**
```bash
git clone https://github.com/carloslafuente10/PrograMovil.git
cd PrograMovil
```

**2. Instalar dependencias**
```bash
flutter pub get
```

**3. Configurar Firebase**

Sigue las instrucciones de [FlutterFire CLI](https://firebase.flutter.dev/docs/overview) para agregar los archivos de configuración:
- `android/app/google-services.json` — para Android
- `ios/Runner/GoogleService-Info.plist` — para iOS

En **Firebase Console**:
- Habilita **Autenticación** con proveedor de correo/contraseña
- Configura las **reglas de seguridad de Firestore** para separar acceso por rol

**4. Configurar variables de entorno**

Crea un archivo `.env` en la raíz del proyecto:

```env
GROQ_API_KEY=tu_clave_de_groq
CLOUDINARY_CLOUD_NAME=tu_cloud_name
CLOUDINARY_UPLOAD_PRESET=tu_upload_preset
EMAILJS_SERVICE_ID=tu_service_id
EMAILJS_TEMPLATE_ID=tu_template_id
EMAILJS_PUBLIC_KEY=tu_public_key
```

> ⚠️ **Importante:** El archivo `.env` está en `.gitignore`. Nunca lo subas al repositorio.

**5. Ejecutar la aplicación**
```bash
# Verificar dispositivos conectados
flutter devices

# Ejecutar en modo debug
flutter run

# Compilar APK de release
flutter build apk --release
```

---

## 📁 Estructura del proyecto

```
PrograMovil/
├── lib/
│   ├── main.dart                    # Punto de entrada, inicialización Firebase
│   ├── models/                      # Entidades del dominio
│   │   ├── receta.dart
│   │   ├── usuario.dart
│   │   ├── plan.dart
│   │   └── ingrediente.dart
│   ├── providers/                   # Gestión de estado reactivo
│   │   ├── auth_provider.dart
│   │   ├── recetas_provider.dart
│   │   ├── favoritos_provider.dart
│   │   └── plan_provider.dart
│   ├── services/                    # Comunicación con APIs y Firebase
│   │   ├── firebase_service.dart
│   │   ├── cloudinary_service.dart
│   │   ├── groq_service.dart
│   │   └── emailjs_service.dart
│   └── screens/                     # Pantallas de la aplicación
│       ├── auth/                    # Login, registro, recuperación OTP
│       ├── home/                    # Home, catálogo y búsqueda
│       ├── receta/                  # Detalle, checklist, porciones
│       ├── favoritos/               # Lista de favoritos
│       ├── planificador/            # Planificador semanal
│       ├── perfil/                  # Perfil y recetas personales
│       ├── ia/                      # sugerencias_chat_screen, voice_call_screen
│       ├── admin/                   # Panel de administración
│       └── reportes/                # Reportes y exportaciones
├── assets/
│   ├── images/                      # Logo, ilustraciones y recursos estáticos
│   └── animations/                  # Archivos Lottie
├── android/                         # Configuración Android (permisos de voz, etc.)
├── ios/                             # Configuración iOS
├── .env                             # Variables de entorno (NO subir al repo)
├── pubspec.yaml                     # Dependencias del proyecto
└── README.md
```

---

## 🔐 Roles y permisos

YAGU maneja dos roles diferenciados con acceso a distintas funcionalidades:

| Funcionalidad | Usuario | Administrador |
|---|:---:|:---:|
| Ver catálogo y recetas | ✅ | ✅ |
| Buscar y filtrar recetas | ✅ | ✅ |
| Ajustar porciones | ✅ | ✅ |
| Gestionar favoritos | ✅ | ✅ |
| Crear recetas personales | ✅ | ✅ |
| Enviar recetas a revisión | ✅ | — |
| Usar asistentes IA (A.L.I.C.I.A. y NID) | ✅ | ✅ |
| Planificador de comidas | ✅ | — |
| Aprobar/rechazar recetas | — | ✅ |
| Administrar usuarios | — | ✅ |
| Ver reportes y bitácora | — | ✅ |
| Exportar PDF/Excel/CSV | — | ✅ |
| Enviar notificaciones | — | ✅ |

---

## 🧪 Pruebas

Las pruebas funcionales del proyecto se realizaron siguiendo los criterios de aceptación definidos en el Sprint Backlog de cada iteración. Las pantallas validadas incluyen:

- Flujo completo de autenticación (registro, login y recuperación)
- Ajuste de porciones con verificación de recálculo de ingredientes
- Checklist de ingredientes con validación del umbral del 80%
- Favoritos con sincronización entre Firestore y la lista local
- Exportación de reportes en los tres formatos (PDF, Excel, CSV)
- Asistente A.L.I.C.I.A. con manejo de errores de API
- Asistente NID con permisos de audio en Android

> El proyecto se desarrolló con metodología **Scrum** en 4 sprints. El Product Backlog y Sprint Backlog completos están documentados en el repositorio.

---

## 👥 Equipo de desarrollo

| Integrante | Rol | Contribuciones principales |
|---|---|---|
| **Carlos La Fuente** | Scrum Master · Developer | Integración UI↔backend, panel admin, historial, merge de ramas, branding |
| **Lenny Calle** | Developer · Tester | Favoritos, notificaciones, login visual, estado con Provider, PDFs mejorados |
| **Hans Flores** | Developer | Sustitutos, filtros de catálogo, reportes, exportación PDF/Excel/CSV, planificador |
| **Arnold Sanabria** | Developer · Tester | Autenticación Firebase, Asistentes IA (A.L.I.C.I.A. y NID), OTP, checklist, sustitutos, filtros de catálogo |
| **Nayra Oviedo** | UI/UX · Developer | Home, perfil, detalle de receta, recetas personales, ingredientes, Firestore |

---

## 🎓 Información académica

| Campo | Detalle |
|---|---|
| **Universidad** | Universidad Mayor de San Simón (UMSS) |
| **Carrera** | Ingeniería de Sistemas |
| **Materia** | Programación Móvil |
| **Docente** | Dr. Américo Fiorilo Lozada Ph.D. |
| **Gestión** | 2026 |

---

## 📄 Licencia

Este proyecto fue desarrollado con fines **estrictamente académicos** para la materia de Programación móvil de la UMSS. No está destinado para uso comercial.

---

<div align="center">
  <p>Hecho con 🐆 y ☕ por el equipo Yagú · UMSS 2026</p>
</div>
