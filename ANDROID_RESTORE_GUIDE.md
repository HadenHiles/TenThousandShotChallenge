# Android Configuration Restoration Guide

## Files to Backup Before Deleting

### 1. Key Files (Copy These)
```bash
cp android/key.properties ~/android_backup_key.properties
cp android/app/google-services.json ~/android_backup_google-services.json
```

---

## Step-by-Step Restoration

### 1. Delete and Regenerate Android Folder
```bash
rm -rf android
flutter create --platforms=android .
```

### 2. Restore Key Files
```bash
cp ~/android_backup_key.properties android/key.properties
cp ~/android_backup_google-services.json android/app/google-services.json
```

### 3. Update `android/gradle.properties`
Replace the contents with:
```properties
org.gradle.jvmargs=-Xmx4G
org.gradle.java.home=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
android.useAndroidX=true
android.enableJetifier=true
android.defaults.buildfeatures.buildconfig=true
android.nonTransitiveRClass=false
android.nonFinalResIds=false
```

### 4. Update `android/settings.gradle`
After the `plugins {` block, add the Google Services plugin:
```gradle
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version '8.10.1' apply false
    id "org.jetbrains.kotlin.android" version "2.0.0" apply false
    id "com.google.gms.google-services" version "4.4.2" apply false  // ADD THIS LINE
}
```

### 5. Update `android/app/build.gradle`

#### a) Add Google Services plugin at the top (after other plugins):
```gradle
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
    id 'com.google.gms.google-services'  // ADD THIS LINE
}
```

#### b) Add keystore properties loading (after localProperties section):
```gradle
// Define the properties for android keystore app signing file
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

#### c) Update android block:
```gradle
android {
    namespace "com.howtohockey.tenthousandshotchallenge"
    compileSdk flutter.compileSdkVersion
    ndkVersion "27.0.12077973"

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
        coreLibraryDesugaringEnabled true  // ADD THIS
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.howtohockey.tenthousandshotchallenge"
        minSdk 24  // UPDATE THIS (default is usually 21)
        targetSdk 35  // UPDATE THIS
        multiDexEnabled true  // ADD THIS
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    // ADD THIS ENTIRE BLOCK:
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release  // UPDATE THIS LINE
        }
    }
}
```

#### d) Replace dependencies block:
```gradle
dependencies {
    // Import the Firebase BoM
    implementation platform('com.google.firebase:firebase-bom:33.0.0')
    implementation('com.google.firebase:firebase-auth') {
        exclude module: "play-services-safetynet"
    }

    // Add the dependency for the Firebase SDK for Google Analytics
    // When using the BoM, don't specify versions in Firebase dependencies
    implementation('com.google.firebase:firebase-analytics')
    implementation('com.google.firebase:firebase-messaging')

    implementation('androidx.window:window:1.2.0')
    implementation('androidx.window:window-java:1.2.0')
    coreLibraryDesugaring('com.android.tools:desugar_jdk_libs:2.1.4')
}
```

### 6. Update `android/app/src/main/AndroidManifest.xml`

Replace the entire `<manifest>` tag contents with:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.FLASHLIGHT" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>
    <uses-permission android:name="android.permission.ACCESS_ADSERVICES_AD_ID" tools:node="remove"/>
    <uses-permission android:name="com.android.vending.BILLING" />
    
    <application
        android:name="${applicationName}"
        android:label="10,000 Shots"
        android:icon="@mipmap/launcher_icon"
        android:allowBackup="false"
        android:usesCleartextTraffic="true">
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/launcher_icon"/>
        <activity
            android:name=".MainActivity"
            android:launchMode="singleTop"
            android:exported="true"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme"
            />
            <meta-data
                android:name="io.flutter.embedding.android.SplashScreenDrawable"
                android:resource="@drawable/launch_background"
            />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>

            <intent-filter>
                <action android:name="FLUTTER_NOTIFICATION_CLICK" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL" />
            <data android:scheme="tel" />
        </intent>
        <intent>
            <action android:name="android.intent.action.SEND" />
            <data android:mimeType="*/*" />
        </intent>
    </queries>
</manifest>
```

### 7. Final Steps
```bash
flutter clean
flutter pub get
cd android && ./gradlew clean
cd .. && flutter build apk --debug
```

---

## Key Configurations Summary

**Package Name:** `com.howtohockey.tenthousandshotchallenge`  
**App Label:** `10,000 Shots`  
**Min SDK:** 24  
**Target SDK:** 35  
**Keystore Location:** `/Users/hadenhiles/Development/keys/10k-upload-keystore.jks`  
**Key Alias:** `upload`

## Special Features
- Firebase (Auth, Analytics, Messaging)
- In-App Billing
- Camera & Flashlight
- MultiDex enabled
- Core library desugaring
- Release signing configured
- Custom launcher icon
