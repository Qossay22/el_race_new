# TensorFlow Lite ProGuard Rules
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.nnapi.** { *; }
-keep class org.tensorflow.lite.support.** { *; }

# Keep TensorFlow Lite classes
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# Keep GPU delegate
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# Keep TensorFlow Lite GPU delegate classes
-keep class org.tensorflow.lite.gpu.GpuDelegate { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }

# Keep TensorFlow Lite interpreter
-keep class org.tensorflow.lite.Interpreter { *; }
-keep class org.tensorflow.lite.Interpreter$Options { *; }

# Keep TensorFlow Lite model classes
-keep class org.tensorflow.lite.Model { *; }

# Keep TensorFlow Lite tensor classes
-keep class org.tensorflow.lite.Tensor { *; }

# Keep TensorFlow Lite delegate classes
-keep class org.tensorflow.lite.Delegate { *; }

# Keep TensorFlow Lite error reporter
-keep class org.tensorflow.lite.ErrorReporter { *; }

# Keep TensorFlow Lite memory allocation
-keep class org.tensorflow.lite.MemoryAllocation { *; }

# Keep TensorFlow Lite support library classes
-keep class org.tensorflow.lite.support.common.** { *; }
-keep class org.tensorflow.lite.support.image.** { *; }
-keep class org.tensorflow.lite.support.tensorbuffer.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep JNI methods
-keepclasseswithmembernames class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep Flutter specific classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep your app's main classes
-keep class com.el_race.app.** { *; }

# Keep ML Kit classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Keep camera plugin classes
-keep class io.flutter.plugins.camera.** { *; }

# Keep image processing classes
-keep class com.google.android.gms.vision.face.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep shared preferences
-keep class androidx.preference.** { *; }

# Keep permission handler
-keep class com.baseflow.permissionhandler.** { *; }

# Keep internet connection checker
-keep class com.baseflow.internetconnectionchecker.** { *; }

# Keep UUID
-keep class com.uuid.** { *; }

# Keep image processing
-keep class com.google.android.gms.vision.** { *; }

# Keep vector math
-keep class org.joml.** { *; }

# Keep image package
-keep class com.google.android.gms.vision.** { *; }

# Keep all classes with @Keep annotation
-keep class * {
    @androidx.annotation.Keep *;
}

# Keep all classes in your package
-keep class com.el_race.app.MainActivity { *; }
-keep class com.el_race.app.MainApplication { *; }

# Keep all native methods
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Keep all classes that might be used by reflection
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions

# Keep all classes in the default package
-keep class * {
    @androidx.annotation.Keep *;
}

# Keep all classes that might be used by the Flutter engine
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.view.** { *; }

# Keep all classes that might be used by plugins
-keep class io.flutter.plugins.** { *; }

# Keep all classes that might be used by the app
-keep class com.el_race.app.** { *; } 