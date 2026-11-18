plugins {
    `java-library`
    kotlin("jvm")
    kotlin("plugin.serialization")
}
java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}
kotlin.compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
dependencies {
    api(project(":core"))
    api("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    testImplementation("junit:junit:4.13.2")
}

// Read the submitted catalogs and fixtures in place. This is not contract enrollment.
val catalogs = fileTree("../../ForsakenCharacterSheet/Catalogs") { include("*.json") }
val sharedCore = file("../../RequiemCharacterSheet/Catalogs/cofd-core.json")
tasks.processResources {
    from(catalogs) { into("forsaken-catalogs") }
    from(sharedCore) { into("forsaken-catalogs") }
    doLast {
        destinationDir.resolve("forsaken-catalogs/index.txt").writeText(
            (catalogs.files + sharedCore).map { it.name }.sorted().joinToString("\n"))
    }
}
sourceSets.test { resources.srcDir("../../ForsakenCharacterSheetTests/Fixtures") }
tasks.test {
    systemProperty("forsakenCatalogDir", file("../../ForsakenCharacterSheet/Catalogs").absolutePath)
    systemProperty("headingsDir", file("../../shared/forsaken-headings").absolutePath)
    systemProperty("swiftModel", file("../../ForsakenCharacterSheet/Models/ForsakenCharacter.swift").absolutePath)
}
