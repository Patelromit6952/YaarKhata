//import java.util.Properties
//import java.io.File
//import java.io.FileInputStream
//
//plugins {
//    id("com.android.application")
//    id("kotlin-android")
//    id("dev.flutter.flutter-gradle-plugin")
//    id("com.google.gms.google-services")
//}
//
//// Load keystore properties
//val keystorePropertiesFile = rootProject.file("key.properties")
//val keystoreProperties = Properties()
//if (keystorePropertiesFile.exists()) {
//    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
//}
//
//android {
//    namespace = "com.example.friendsbook"
//    compileSdk = flutter.compileSdkVersion
//    ndkVersion = "27.0.12077973"
//
//    defaultConfig {
//        applicationId = "com.example.friendsbook"
//        minSdk = 23
//        targetSdk = 34
//        versionCode = flutter.versionCode
//        versionName = "1.1.4"
//        multiDexEnabled = true
//    }
//
//    compileOptions {
//        isCoreLibraryDesugaringEnabled = true
//        sourceCompatibility = JavaVersion.VERSION_11
//        targetCompatibility = JavaVersion.VERSION_11
//    }
//
//    kotlinOptions {
//        jvmTarget = JavaVersion.VERSION_11.toString()
//    }
//
//    signingConfigs {
//        create("release") {
//            keyAlias = keystoreProperties["keyAlias"] as String?
//            keyPassword = keystoreProperties["keyPassword"] as String?
//            storeFile = keystoreProperties["storeFile"]?.let { File(rootProject.projectDir, it.toString()) }
//            storePassword = keystoreProperties["storePassword"] as String?
//        }
//    }
//
//    buildTypes {
//        getByName("release") {
//            signingConfig = signingConfigs.getByName("release")
//            isMinifyEnabled = true
//            isShrinkResources = true
//            proguardFiles(
//                getDefaultProguardFile("proguard-android-optimize.txt"),
//                "proguard-rules.pro"
//            )
//        }
//        getByName("debug") {
//            isMinifyEnabled = false
//            isShrinkResources = false
//        }
//    }
//
//    // ABI splits to reduce APK size
//    splits {
//        abi {
//            isEnable = true
//            reset()
//            include("armeabi-v7a", "arm64-v8a", "x86_64")
//            isUniversalApk = false
//        }
//    }
//}
//
//// APK Renaming Task - Runs after build completion
//tasks.whenTaskAdded {
//    if (name == "assembleRelease" || name == "assembleDebug") {
//        doLast {
//            val appName = "FriendsBook" // Change this to your desired app name
//            val versionName = android.defaultConfig.versionName
//            val buildType = if (name.contains("Release")) "release" else "debug"
//
//            // Find all APK files in the outputs directory
//            val outputDir = file("$buildDir/outputs/apk/$buildType")
//            if (outputDir.exists()) {
//                outputDir.listFiles { file ->
//                    file.name.endsWith(".apk") && !file.name.contains(appName)
//                }?.forEach { apkFile ->
//                    val newName = if (apkFile.name.contains("arm64-v8a")) {
//                        "${appName}_v${versionName}_${buildType}_arm64-v8a.apk"
//                    } else if (apkFile.name.contains("armeabi-v7a")) {
//                        "${appName}_v${versionName}_${buildType}_armeabi-v7a.apk"
//                    } else if (apkFile.name.contains("x86_64")) {
//                        "${appName}_v${versionName}_${buildType}_x86_64.apk"
//                    } else {
//                        "${appName}_v${versionName}_${buildType}.apk"
//                    }
//
//                    val newFile = File(outputDir, newName)
//                    if (apkFile.renameTo(newFile)) {
//                        println("✅ Renamed ${apkFile.name} to $newName")
//                    } else {
//                        println("❌ Failed to rename ${apkFile.name}")
//                    }
//                }
//            }
//        }
//    }
//}
//
//dependencies {
//    // Core
//    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
//    implementation("androidx.core:core-ktx:1.12.0")
//    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
//    implementation("androidx.work:work-runtime-ktx:2.9.0")
//    implementation("androidx.multidex:multidex:2.0.1")
//
//    // Firebase
//    implementation("com.google.firebase:firebase-messaging:23.2.1")
//    implementation("com.google.firebase:firebase-core:21.1.1")
//
//    // Testing
//    testImplementation("junit:junit:4.13.2")
//    androidTestImplementation("androidx.test.ext:junit:1.1.5")
//    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
//}
//
//flutter {
//    source = "../.."
//}


/////////////////////////////////////////////////////////

import java.util.Properties
import java.io.File
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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
        applicationId = "com.example.friendsbook"
        minSdk = 23
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = "1.1.5"
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { File(rootProject.projectDir, it.toString()) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs.forEach { output ->
            val appName = "YaarKhata"
            val version = variant.versionName ?: "1.1.0"
            val buildType = variant.buildType.name

            val outputImpl = output as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            outputImpl.outputFileName = "${appName}-${version}-${buildType}.apk"
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("com.google.firebase:firebase-messaging:23.2.1")
    implementation("com.google.firebase:firebase-core:21.1.1")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.multidex:multidex:2.0.1")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}

flutter {
    source = "../.."
}
