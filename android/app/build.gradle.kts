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
        versionCode = 7
        versionName = "0.5.0-alpha.7"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    buildFeatures { compose = true; buildConfig = true }
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
    debugImplementation("androidx.compose.ui:ui-test-manifest")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
}

// Package the same unmodified font files and full notices used by Xcode.
abstract class SheetResourcesTask : DefaultTask() {
    @get:InputDirectory @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val fontDirectory: DirectoryProperty
    @get:OutputDirectory abstract val outputDirectory: DirectoryProperty
    @TaskAction fun generate() {
        val output = outputDirectory.get().asFile
        output.deleteRecursively()
        val files = mapOf("IMFellEnglish-Regular.ttf" to "font/im_fell_english.ttf",
            "Cinzel-Medium.ttf" to "font/cinzel_medium.ttf", "IMFellEnglish-OFL.txt" to "raw/im_fell_english_ofl.txt",
            "Cinzel-OFL.txt" to "raw/cinzel_ofl.txt")
        files.forEach { (source, target) ->
            val destination = output.resolve(target)
            destination.parentFile.mkdirs()
            fontDirectory.file(source).get().asFile.copyTo(destination, overwrite = true)
        }
    }
}
val sheetResources = tasks.register<SheetResourcesTask>("sheetResources") {
    fontDirectory.set(layout.projectDirectory.dir("../../RequiemCharacterSheet/Fonts"))
    outputDirectory.set(layout.buildDirectory.dir("generated/sheetResources"))
}
androidComponents.onVariants { variant ->
    variant.sources.res?.addGeneratedSourceDirectory(sheetResources, SheetResourcesTask::outputDirectory)
}
