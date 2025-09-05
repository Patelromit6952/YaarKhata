plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.friendsbook"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.friendsbook"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    dependencies {
        // Core library desugaring
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

        // Firebase dependencies
        implementation("com.google.firebase:firebase-messaging:23.2.1")
        implementation("com.google.firebase:firebase-core:21.1.1")

        // AndroidX dependencies
        implementation("androidx.core:core-ktx:1.12.0")
        implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
        implementation("androidx.work:work-runtime-ktx:2.9.0")

        // Multidex support
        implementation("androidx.multidex:multidex:2.0.1")

        // Test dependencies
        testImplementation("junit:junit:4.13.2")
        androidTestImplementation("androidx.test.ext:junit:1.1.5")
        androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    }
}

flutter {
    source = "../.."
}
