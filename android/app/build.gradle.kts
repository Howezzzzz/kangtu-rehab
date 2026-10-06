import java.util.Properties
import java.io.FileInputStream
import java.util.Base64
import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// CI signing: secrets arrive as env (KEYSTORE_BASE64 / KEYSTORE_PASSWORD / KEY_PASSWORD / KEY_ALIAS),
// falling back to a local key.properties (gitignored) for dev machines, then debug signing.
val envKeystoreBase64 = System.getenv("KEYSTORE_BASE64")
val useEnvKeystore = !envKeystoreBase64.isNullOrEmpty()
val signingKeystoreFile = if (useEnvKeystore) {
    val f = File(rootProject.projectDir, "build/keystore/upload-keystore.jks")
    f.parentFile.mkdirs()
    f.writeBytes(Base64.getDecoder().decode(envKeystoreBase64))
    f
} else {
    null
}

android {
    namespace = "com.gymmane.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.gymmane.app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    if (useEnvKeystore || keystorePropertiesFile.exists()) {
        signingConfigs {
            create("release") {
                if (useEnvKeystore) {
                    storeFile = signingKeystoreFile
                    storePassword = System.getenv("KEYSTORE_PASSWORD")!!
                    keyAlias = System.getenv("KEY_ALIAS")!!
                    keyPassword = System.getenv("KEY_PASSWORD")!!
                } else {
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                    storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                    storePassword = keystoreProperties["storePassword"] as String
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (useEnvKeystore || keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode = abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride = variant.versionCode * 10 + abiVersionCode
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
