# Keep TFLite GPU delegate classes
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.gpu.**
# shared_preferences_android 2.5+ calls its Java side through JNI, which R8
# cannot see; without this the release build strips getAll() and the app
# hangs on the splash screen.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
# The JNI bridge also looks up Kotlin stdlib and coroutine classes by name.
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
