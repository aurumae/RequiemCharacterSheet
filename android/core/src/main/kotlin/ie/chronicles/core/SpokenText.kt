package ie.chronicles.core

private val dotRun = Regex("[•●]+")
fun String.spokenForScreenReader(): String = replace(" → ", " to ")
    .replace(dotRun) { "${it.value.length} ${if (it.value.length == 1) "dot" else "dots"}" }
    .replace("–", " to ")

fun experiencesText(value: Int): String = "$value ${if (value == 1) "Experience" else "Experiences"}"
