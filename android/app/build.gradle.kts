plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.lukematthews.syccourses"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.lukematthews.syccourses"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.1"
        buildConfigField("String", "LICENSING_API_ENDPOINT", "\"https://syc-courses-production.up.railway.app\"")
        buildConfigField("String", "LICENSING_KEY_ID", "\"development-live-2026-08\"")
        buildConfigField("String", "LICENSING_PUBLIC_KEY_BASE64", "\"UydDqfMTRzbR5bjcs2EwuXFrtyxKMRZbQ6N5KFLFP5A=\"")
    }

    buildFeatures { compose = true; buildConfig = true }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.04.01")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.0")
    implementation("androidx.navigation:navigation-compose:2.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")
    implementation("com.google.crypto.tink:tink-android:1.23.0")
    debugImplementation("androidx.compose.ui:ui-tooling")

    testImplementation("junit:junit:4.13.2")
}
