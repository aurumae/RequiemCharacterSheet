pluginManagement {
    repositories {
        google()
        gradlePluginPortal()
        mavenCentral()
    }
}
dependencyResolutionManagement {
    repositories { google(); mavenCentral() }
}
rootProject.name = "RequiemCharacterSheet"
include(":core", ":requiem", ":forsaken", ":sheet-ui", ":app", ":forsakenApp")
