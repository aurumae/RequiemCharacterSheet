plugins {
    id("com.android.library")
    kotlin("plugin.compose")
}

android {
    namespace = "ie.chronicles.ui"
    compileSdk = 36
    defaultConfig { minSdk = 36 }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    api(project(":core"))
    implementation("androidx.core:core:1.16.0")
    implementation("androidx.activity:activity-compose:1.11.0")
    api("androidx.lifecycle:lifecycle-viewmodel-savedstate:2.9.4")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.4")
    api(platform("androidx.compose:compose-bom:2025.10.01"))
    api("androidx.compose.material3:material3")
}
