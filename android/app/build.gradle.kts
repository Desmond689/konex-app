<<<<<<< HEAD
import java.util.Properties
import java.io.FileInputStream

=======
>>>>>>> origin/main
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

<<<<<<< HEAD
// Release signing comes from key.properties, which is never committed —
// see .gitignore. Locally, create it yourself next to this file:
//   storeFile=/absolute/path/to/konex-upload-keystore.jks
//   storePassword=...
//   keyAlias=konex-upload
//   keyPassword=...
// In CI, the workflow writes this file from repo secrets before the build.
val keystorePropertiesFile = rootProject.file("app/key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.konex.app"
=======
android {
    namespace = "com.example.konex"
>>>>>>> origin/main

    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    defaultConfig {
<<<<<<< HEAD
        applicationId = "com.konex.app"
=======
        applicationId = "com.example.konex"
>>>>>>> origin/main

        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Only build native libs for real-device architectures.
        // x86/x86_64 are emulator-only and roughly double the memory/time
        // spent in mergeReleaseNativeLibs + stripReleaseDebugSymbols, which
        // is native tooling outside the JVM heap — this is what was
        // silently OOM-killing the CI runner, not the Gradle/Kotlin heap.
        ndk {
            abiFilters += setOf("armeabi-v7a", "arm64-v8a")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

<<<<<<< HEAD
    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug signing only when key.properties isn't
            // present (e.g. a local `flutter build apk` without it set up),
            // so the build never silently ships a debug-signed release once
            // real signing is configured.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
=======
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
>>>>>>> origin/main
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        )
    }
}

flutter {
    source = "../.."
}