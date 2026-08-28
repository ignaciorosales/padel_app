# 🚀 Guía Completa: Publicar Puntazo en Google Play Store

## 📋 **CHECKLIST PRE-PUBLICACIÓN**

### ✅ **1. Preparar la App**

#### A. Actualizar `pubspec.yaml`
```yaml
name: Puntazo
description: "Marcador electrónico profesional para pádel con remoto BLE"
version: 1.0.0+1  # formato: versionName+versionCode

# Cambiar esto:
publish_to: 'none'  # ← ELIMINAR ESTA LÍNEA para permitir publicación
```

#### B. Configurar Versiones
- **versionName** (1.0.0): Lo que ve el usuario
- **versionCode** (+1): Número interno incremental (cada update debe ser mayor)

**Ejemplo de evolución:**
```yaml
version: 1.0.0+1   # Primera versión
version: 1.0.1+2   # Bugfix
version: 1.1.0+3   # Nueva funcionalidad
version: 2.0.0+4   # Cambio mayor
```

---

### ✅ **2. Configurar Android (CRÍTICO)**

#### A. Editar `android/app/build.gradle.kts`
```kotlin
android {
    namespace = "com.yourcompany.puntazo"  // ← CAMBIAR: debe ser único
    compileSdk = 35  // O la última versión
    
    defaultConfig {
        applicationId = "com.yourcompany.puntazo"  // ← MISMO namespace
        minSdk = 21  // Android 5.0 (compatible con la mayoría)
        targetSdk = 35  // Última versión requerida por Google Play
        versionCode = 1
        versionName = "1.0.0"
        
        // ▲ IMPORTANTE: Para Android TV
        multiDexEnabled = true
    }
    
    signingConfigs {
        // ▼ AÑADIR configuración de firma (ver sección 3)
        create("release") {
            storeFile = file("../keystore/release-keystore.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = "puntazo-release"
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true  // ← Optimizar tamaño
            isShrinkResources = true  // ← Eliminar recursos no usados
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

#### B. Editar `android/app/src/main/AndroidManifest.xml`
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- ▼ PERMISOS NECESARIOS -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" 
                     android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- ▼ CARACTERÍSTICAS DEL HARDWARE -->
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
    
    <!-- ▼ ANDROID TV (si aplica) -->
    <uses-feature android:name="android.software.leanback" android:required="false" />
    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />

    <application
        android:label="Puntazo"
        android:icon="@mipmap/ic_launcher"
        android:banner="@drawable/banner"  <!-- ▼ Para Android TV -->
        android:usesCleartextTraffic="false">  <!-- ▼ Seguridad -->
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:screenOrientation="landscape"  <!-- ▼ Horizontal forzado -->
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <!-- ▼ INTENT FILTERS -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
                <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>  <!-- Para TV -->
            </intent-filter>
        </activity>
    </application>
</manifest>
```

---

### ✅ **3. Crear Keystore de Firma (GUARDAR EN LUGAR SEGURO)**

#### A. Generar Keystore
```powershell
# En PowerShell (ejecutar desde android/app/)
mkdir keystore
cd keystore

keytool -genkey -v -keystore release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias puntazo-release
```

**Te preguntará:**
- Password del keystore (ANOTARLO - NO SE PUEDE RECUPERAR)
- Password del alias (ANOTARLO)
- Nombre, organización, ciudad, país

#### B. Variables de Entorno (NO COMMITEAR)
Crear `android/key.properties`:
```properties
storePassword=TU_PASSWORD_KEYSTORE
keyPassword=TU_PASSWORD_KEY
keyAlias=puntazo-release
storeFile=../keystore/release-keystore.jks
```

**⚠️ IMPORTANTE:** Agregar a `.gitignore`:
```gitignore
# Secrets
android/keystore/
android/key.properties
*.jks
```

#### C. Guardar Backup del Keystore
1. Copiar `release-keystore.jks` a lugar seguro (USB, cloud cifrado)
2. Guardar passwords en gestor de contraseñas
3. **SI PIERDES EL KEYSTORE, NO PODRÁS ACTUALIZAR LA APP EN PLAY STORE**

---

### ✅ **4. Build Release**

```powershell
# Limpiar builds anteriores
flutter clean
flutter pub get

# Build APK (para pruebas)
flutter build apk --release

# Build AAB (para Google Play - REQUERIDO)
flutter build appbundle --release

# Los archivos estarán en:
# - build/app/outputs/flutter-apk/app-release.apk
# - build/app/outputs/bundle/release/app-release.aab
```

**Verificar Build:**
```powershell
# Instalar APK para probar
adb install build/app/outputs/flutter-apk/app-release.apk

# Ver logs
adb logcat | Select-String "flutter"
```

---

### ✅ **5. Assets de la Play Store**

#### A. Ícono de la App (REQUERIDO)
- **512x512 px** PNG (32-bit con alpha)
- Fondo opaco o transparente
- Sin bordes redondeados (Google los agrega)

#### B. Capturas de Pantalla (MÍNIMO 2)
**Smartphone:**
- Mínimo: 320px
- Máximo: 3840px
- Ratio: 16:9 o 9:16

**Tablet (10" - opcional):**
- Mínimo: 1024x768
- Máximo: 7680x4320

**Android TV (opcional pero recomendado):**
- Exactamente: 1920x1080 px
- 3-8 capturas

#### C. Gráfico de Funcionalidad (Feature Graphic - REQUERIDO)
- **1024x500 px** exacto
- JPG o PNG 24-bit
- Sin transparencia
- Texto legible

#### D. Banner TV (Si soportas Android TV)
- **1280x720 px** exacto
- PNG con transparencia
- Solo logo/nombre (sin texto pequeño)

---

### ✅ **6. Crear Cuenta de Google Play Console**

1. Ir a [play.google.com/console](https://play.google.com/console)
2. Pagar registro único: **$25 USD** (de por vida)
3. Completar información de desarrollador:
   - Nombre
   - Email de contacto
   - Dirección
   - Teléfono

---

### ✅ **7. Crear Nueva Aplicación**

#### A. Información Básica
- **Nombre:** Puntazo
- **Idioma predeterminado:** Español (España)
- **Tipo:** App
- **Categoría:** Deportes
- **Gratis/Pago:** Gratis (o precio)

#### B. Descripción de la Tienda
**Descripción Corta (80 caracteres max):**
```
Marcador electrónico para pádel con control remoto Bluetooth
```

**Descripción Completa (4000 caracteres max):**
```markdown
⚡ MARCADOR PROFESIONAL PARA PÁDEL

Puntazo es el marcador electrónico más avanzado para partidos de pádel, diseñado especialmente para Android TV y tablets.

🎯 CARACTERÍSTICAS PRINCIPALES:
• Control remoto Bluetooth con ESP32-C3
• Marcador en pantalla grande con fuente digital
• Soporte completo para reglas oficiales
• Punto de oro configurable (40-40 decisivo)
• Super Tie-Break en tercer set
• Historial de sets y estadísticas
• Undo/Redo inteligente
• Sin publicidad, sin suscripciones

🔧 CONFIGURACIÓN FLEXIBLE:
• Tie-break a 7 o 10 puntos
• Tercer set: Normal, Super TB o Ventaja
• Punto de oro en 40-40
• Tie-break a 6-6 o sin límite

📱 REQUISITOS:
• Android 5.0 o superior
• Bluetooth LE
• Pantalla horizontal (recomendado: TV o tablet)
• Opcional: Mando BLE compatible

🏆 IDEAL PARA:
• Clubes de pádel
• Torneos amateurs
• Partidos caseros
• Entrenadores
• Streaming en vivo

💡 DISEÑADO PARA RENDIMIENTO:
• Latencia ultra-baja (<50ms)
• Optimizado para Android TV
• Sin consumo de datos
• Funciona offline

📊 TELEMETRÍA EN TIEMPO REAL:
• Monitor de latencias BLE
• Estadísticas de rendimiento
• Modo debugging para desarrolladores

🎨 INTERFAZ PROFESIONAL:
• Gradientes personalizables
• Fuente digital de alta visibilidad
• Indicadores de saque
• Colores de equipo configurables

---

Desarrollado por jugadores de pádel, para jugadores de pádel. 🎾

¿Problemas o sugerencias? Contáctanos en: tu@email.com
```

#### C. Detalles Adicionales
- **Email de contacto:** (visible públicamente)
- **Sitio web:** (opcional)
- **Política de privacidad:** (REQUERIDA si solicitas permisos)

---

### ✅ **8. Política de Privacidad (REQUERIDO)**

Crear archivo `PRIVACY_POLICY.md` y subirlo a GitHub Pages o tu web:

```markdown
# Política de Privacidad - Puntazo

**Última actualización:** [FECHA]

## 1. Información que Recopilamos
Puntazo NO recopila, almacena ni transmite ninguna información personal del usuario.

## 2. Permisos Utilizados
- **Bluetooth:** Para conectar con mandos remotos BLE (ESP32-C3)
- **Ubicación:** Android requiere este permiso para escaneo BLE. NO rastreamos ubicación.
- **Wake Lock:** Mantener pantalla activa durante partidos

## 3. Almacenamiento Local
Los siguientes datos se guardan SOLO en tu dispositivo:
- Configuración de la app (reglas, colores)
- Dispositivos BLE emparejados
- Historial de partidos (opcional)

## 4. Compartir Datos
Puntazo NO comparte datos con terceros. Todo permanece en tu dispositivo.

## 5. Seguridad
No se transmite información por Internet. La app funciona completamente offline.

## 6. Cambios a esta Política
Cualquier cambio será notificado mediante actualizaciones de la app.

## 7. Contacto
Email: tu@email.com
```

**URL ejemplo:** `https://tuusuario.github.io/puntazo/privacy`

---

### ✅ **9. Clasificación de Contenido**

Google Play Console te hará un cuestionario. Para Puntazo:
- **Violencia:** Ninguna
- **Contenido sexual:** Ninguno
- **Lenguaje:** Ninguno
- **Drogas:** Ninguno
- **Gambling:** No
- **Edad recomendada:** PEGI 3 / Everyone

---

### ✅ **10. Subir AAB**

1. Google Play Console → **Producción** (o Testing)
2. **Crear nueva versión**
3. Subir `app-release.aab`
4. **Notas de la versión** (qué hay de nuevo):
```
v1.0.0 - Lanzamiento Inicial
• Marcador electrónico para pádel
• Control remoto Bluetooth
• Soporte reglas oficiales
• Super Tie-Break configurable
• Interfaz optimizada para TV
```

---

### ✅ **11. Testing Interno/Cerrado (RECOMENDADO)**

Antes de publicar:
1. Crear **pista de pruebas cerrada**
2. Invitar a 5-20 testers (emails)
3. Probar 1-2 semanas
4. Corregir bugs
5. Luego publicar en Producción

---

### ✅ **12. Revisión de Google (2-7 días)**

Google revisará:
- Funcionalidad básica
- Permisos justificados
- Política de privacidad
- Assets completos
- Cumplimiento de políticas

**Causas comunes de rechazo:**
- Permisos innecesarios
- Crashes al iniciar
- Assets faltantes
- Política de privacidad incorrecta

---

### ✅ **13. Actualizaciones Futuras**

```powershell
# 1. Incrementar versión en pubspec.yaml
version: 1.0.1+2  # +2 es MAYOR que +1

# 2. Rebuild
flutter build appbundle --release

# 3. Subir nuevo AAB a Play Console
# 4. Escribir notas de versión
# 5. Enviar a revisión
```

---

## 🎯 **CHECKLIST FINAL PRE-PUBLICACIÓN**

- [ ] `pubspec.yaml` versión actualizada
- [ ] Keystore creado y RESPALDADO
- [ ] Build release exitoso (AAB)
- [ ] Probado en dispositivo real
- [ ] Ícono 512x512 px
- [ ] 2+ capturas de pantalla
- [ ] Feature graphic 1024x500 px
- [ ] Descripción completa
- [ ] Política de privacidad publicada
- [ ] Cuenta Google Play creada ($25 pagados)
- [ ] Clasificación de contenido completada
- [ ] Testing interno realizado
- [ ] Email de contacto configurado

---

## 📊 **MONITOREO POST-LANZAMIENTO**

### Android Vitals (Play Console)
- **Crashes:** <2% usuarios
- **ANRs:** <0.5% usuarios
- **Wake locks:** <10% batería
- **Instalaciones:** tracking de crecimiento

### Responder Reviews
- Responder críticas constructivas
- Agradecer reviews positivas
- Corregir bugs reportados

---

## 🔧 **TROUBLESHOOTING**

### "Keystore not found"
```powershell
# Verificar ruta en build.gradle.kts
ls android/keystore/release-keystore.jks
```

### "Signature verification failed"
```powershell
# Verificar passwords en key.properties
# Regenerar keystore si es necesario (PERDERÁS actualizaciones)
```

### "Build failed: minSdkVersion"
```kotlin
// android/app/build.gradle.kts
defaultConfig {
    minSdk = 21  // Mínimo Android 5.0
}
```

### "Assets not found in release"
```yaml
# pubspec.yaml - verificar:
flutter:
  assets:
    - assets/images/
    - assets/fonts/
```

---

## 📞 **RECURSOS ÚTILES**

- **Google Play Console:** https://play.google.com/console
- **Políticas de Google Play:** https://play.google.com/about/developer-content-policy/
- **Flutter Deployment:** https://docs.flutter.dev/deployment/android
- **Android Developer Guide:** https://developer.android.com/distribute

---

## 🚀 **¡ÉXITO!**

Una vez aprobada, tu app estará disponible en Google Play Store en **~48 horas**.

Comparte el link: `https://play.google.com/store/apps/details?id=com.yourcompany.puntazo`
