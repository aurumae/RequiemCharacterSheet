plugins {
    id("com.android.application")
    kotlin("plugin.compose")
}

android {
    namespace = "ie.requiem.sheet"
    compileSdk = 36
    defaultConfig {
        applicationId = "ie.requiem.sheet"
        minSdk = 36
        targetSdk = 36
        versionCode = 2
        versionName = "0.2.0-alpha.2"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    buildFeatures { compose = true }
    sourceSets["test"].resources.srcDir("../../shared/fixtures")
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(project(":rules"))
    implementation(platform("androidx.compose:compose-bom:2025.10.01"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-savedstate:2.9.4")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.4")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation(platform("androidx.compose:compose-bom:2025.10.01"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
}
