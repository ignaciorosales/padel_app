# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# USB Serial
-keep class com.felhr.usbserial.** { *; }

# Mantener clases de Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Play Core (deferred components)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Evitar errores con reflexión
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
