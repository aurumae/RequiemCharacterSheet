plugins {
    id("com.android.application")
    kotlin("plugin.compose")
}
android {
    namespace = "ie.forsaken.sheet"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.omccolgan.ForsakenCharacterSheet"
        minSdk = 36
        targetSdk = 36
        versionCode = 4
        versionName = "0.2.0-preview.3"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    buildFeatures { compose = true; buildConfig = true }
    sourceSets["test"].resources.srcDir("../../ForsakenCharacterSheetTests/Fixtures")
    sourceSets["androidTest"].assets.srcDir("../../ForsakenCharacterSheetTests/Fixtures")
    sourceSets["androidTest"].assets.srcDir("../../shared/forsaken-headings")
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

// Signing and Play delivery are phase 5. Release packaging here is an explicit unsigned smoke check.
val unsignedRelease = providers.gradleProperty("forsakenUnsignedRelease").map(String::toBoolean).getOrElse(false)
val verifyReleaseSigning = tasks.register("verifyReleaseSigning") {
    doLast { check(unsignedRelease) { "Forsaken release signing is not configured. CI only may pass -PforsakenUnsignedRelease=true." } }
}
tasks.matching { it.name == "packageRelease" || it.name == "packageReleaseBundle" }.configureEach { dependsOn(verifyReleaseSigning) }

dependencies {
    implementation(project(":forsaken"))
    implementation(project(":sheet-ui"))
    implementation(platform("androidx.compose:compose-bom:2025.10.01"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-savedstate:2.9.4")
    implementation("androidx.core:core:1.16.0")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation(platform("androidx.compose:compose-bom:2025.10.01"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
}

// Only the two OFL fonts are bundled. Flat Earth Scribe is flattened artwork; Trade Winds is not used.
abstract class ForsakenResources : DefaultTask() {
    @get:InputDirectory @get:PathSensitive(PathSensitivity.RELATIVE) abstract val fonts: DirectoryProperty
    @get:InputDirectory @get:PathSensitive(PathSensitivity.RELATIVE) abstract val headings: DirectoryProperty
    @get:InputFiles @get:PathSensitive(PathSensitivity.RELATIVE) abstract val artwork: ConfigurableFileCollection
    @get:OutputDirectory abstract val output: DirectoryProperty
    @TaskAction fun generate() {
        val root = output.get().asFile
        root.deleteRecursively()
        fun copy(source: java.io.File, target: String) {
            val destination = root.resolve(target)
            destination.parentFile.mkdirs()
            source.copyTo(destination)
        }
        mapOf("Comforter-Regular.ttf" to "font/comforter.ttf", "GrechenFuemen-Regular.ttf" to "font/grechen_fuemen.ttf",
            "Comforter-OFL.txt" to "raw/comforter_ofl.txt", "GrechenFuemen-OFL.txt" to "raw/grechen_fuemen_ofl.txt").forEach { (from, to) ->
            copy(fonts.file(from).get().asFile, to)
        }
        headings.get().asFile.walkTopDown().filter { it.extension == "xml" }.forEach { copy(it, "raw/${it.name}") }
        copy(headings.file("headings.json").get().asFile, "raw/headings.json")
        val targets = mapOf("AppIcon.png" to "launcher_icon", "WtF 2nd ED Logo.png" to "forsaken_logo",
            "WtF Skull Watermark.png" to "sheet_watermark", "darkpack_logo1.png" to "dark_pack")
        artwork.files.forEach { copy(it, "drawable-nodpi/${targets.getValue(it.name)}.png") }
    }
}
val sheetResources = tasks.register<ForsakenResources>("sheetResources") {
    fonts.set(layout.projectDirectory.dir("../../ForsakenCharacterSheet/Fonts"))
    headings.set(layout.projectDirectory.dir("../../shared/forsaken-headings"))
    val assets = "../../ForsakenCharacterSheet/Assets.xcassets"
    artwork.from("$assets/AppIcon.appiconset/AppIcon.png", "$assets/WtF 2nd ED Logo.imageset/WtF 2nd ED Logo.png",
        "$assets/WtF Skull Watermark.imageset/WtF Skull Watermark.png", "$assets/darkpack_logo1.imageset/darkpack_logo1.png")
    output.set(layout.buildDirectory.dir("generated/forsakenResources"))
}
androidComponents.onVariants { variant -> variant.sources.res?.addGeneratedSourceDirectory(sheetResources, ForsakenResources::output) }
