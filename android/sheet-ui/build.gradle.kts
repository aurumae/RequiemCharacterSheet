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
    api(platform("androidx.compose:compose-bom:2025.10.01"))
    api("androidx.compose.material3:material3")
}
