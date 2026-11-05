plugins {
    kotlin("jvm")
    kotlin("plugin.serialization")
}
java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}
kotlin.compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    testImplementation("junit:junit:4.13.2")
}

// Classpath resources cannot be enumerated reliably inside a jar. Index the same files
// that Xcode bundles so adding another book needs no Kotlin source edit.
val catalogFiles = fileTree("../../RequiemCharacterSheet/Catalogs") { include("*.json") }
tasks.processResources {
    from(catalogFiles) { into("catalogs") }
    doLast {
        destinationDir.resolve("catalogs/index.txt").writeText(
            catalogFiles.files.map { it.name }.sorted().joinToString("\n")
        )
    }
}
sourceSets.test {
    resources.srcDir("../../shared/fixtures")
}

tasks.test {
    providers.gradleProperty("exchangeDir").orNull?.let { directory ->
        // The side effects are the exchange files consumed by Swift in this invocation.
        systemProperty("exchangeDir", directory)
        outputs.upToDateWhen { false }
        outputs.doNotCacheIf("uses an external exchange directory") { true }
    }
}
