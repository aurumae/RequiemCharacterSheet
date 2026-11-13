import java.io.File
import java.security.KeyStore
import java.security.cert.X509Certificate
import java.security.interfaces.RSAPublicKey
import java.util.Properties

plugins {
    id("com.android.application")
    kotlin("plugin.compose")
}

// Keep the keystore and passwords outside the checkout. Debug builds need neither.
val signingPath = providers.environmentVariable("REQUIEM_SIGNING_PROPERTIES").orNull
val uploadProperties = signingPath?.let { path ->
    val source = file(path)
    require(source.isFile) { "REQUIEM_SIGNING_PROPERTIES must point to a readable properties file." }
    Properties().apply { source.inputStream().use(::load) }.also { values ->
        for (key in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
            require(!values.getProperty(key).isNullOrBlank()) { "Missing $key in the signing properties file." }
        }
        val keystore = File(values.getProperty("storeFile"))
        if (!keystore.isAbsolute) values.setProperty("storeFile", source.absoluteFile.parentFile.resolve(keystore).path)
        require(file(values.getProperty("storeFile")).isFile) { "The configured upload keystore does not exist." }
    }
}
val allowUnsignedRelease = providers.gradleProperty("requiemUnsignedRelease").map(String::toBoolean).getOrElse(false)

android {
    namespace = "ie.requiem.sheet"
    compileSdk = 36
    defaultConfig {
        applicationId = "ie.requiem.sheet"
        minSdk = 36
        targetSdk = 36
        versionCode = 11
        versionName = "1.0.0-beta.3"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    signingConfigs {
        if (uploadProperties != null) create("upload") {
            storeFile = file(uploadProperties.getProperty("storeFile"))
            storePassword = uploadProperties.getProperty("storePassword")
            keyAlias = uploadProperties.getProperty("keyAlias")
            keyPassword = uploadProperties.getProperty("keyPassword")
            storeType = uploadProperties.getProperty("storeType", "JKS")
        }
    }
    buildTypes.named("release") {
        isDebuggable = false
        // Keep the accepted app's behavior; shrinking can be evaluated separately.
        isMinifyEnabled = false
        if (uploadProperties != null) signingConfig = signingConfigs.getByName("upload")
    }
    buildFeatures { compose = true; buildConfig = true }
    sourceSets["test"].resources.srcDir("../../shared/fixtures")
    sourceSets["test"].kotlin.srcDir("../test-support")
    sourceSets["androidTest"].assets.srcDir("../../shared/fixtures")
    testOptions.unitTests.all {
        providers.gradleProperty("exchangeDir").orNull?.let { directory ->
            it.systemProperty("exchangeDir", directory)
            it.outputs.upToDateWhen { false }
            it.outputs.doNotCacheIf("uses an external exchange directory") { true }
        }
        providers.gradleProperty("contractPlan").orNull?.let { path -> it.systemProperty("contractPlan", path) }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

val verifyReleaseSigning = tasks.register("verifyReleaseSigning") {
    group = "verification"
    description = "Require a valid upload key before packaging a release; unsigned builds need an explicit CI flag."
    doLast {
        val values = uploadProperties
        if (values == null) {
            check(allowUnsignedRelease) {
                "Release signing is not configured. Set REQUIEM_SIGNING_PROPERTIES to your private upload.properties file. " +
                    "For an unsigned CI check only, pass -PrequiemUnsignedRelease=true."
            }
        } else {
            val store = KeyStore.getInstance(values.getProperty("storeType", "JKS"))
            File(values.getProperty("storeFile")).inputStream().use {
                store.load(it, values.getProperty("storePassword").toCharArray())
            }
            val alias = values.getProperty("keyAlias")
            check(store.isKeyEntry(alias)) { "The configured alias is not a private-key entry." }
            check(store.getKey(alias, values.getProperty("keyPassword").toCharArray()) != null) { "Cannot unlock the upload key." }
            val certificate = store.getCertificate(alias) as X509Certificate
            certificate.checkValidity()
            val key = certificate.publicKey as? RSAPublicKey
            check(key != null && key.modulus.bitLength() >= 2048) { "Google Play upload keys must use RSA with at least 2048 bits." }
            check(!certificate.subjectX500Principal.name.contains("CN=Android Debug", ignoreCase = true)) {
                "The Android debug certificate cannot sign a Play release. Use a dedicated upload key."
            }
        }
    }
}
tasks.matching { it.name == "packageRelease" || it.name == "packageReleaseBundle" }.configureEach {
    dependsOn(verifyReleaseSigning)
}

dependencies {
    implementation(project(":rules"))
    implementation(platform("androidx.compose:compose-bom:2025.10.01"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-savedstate:2.9.4")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.4")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
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
