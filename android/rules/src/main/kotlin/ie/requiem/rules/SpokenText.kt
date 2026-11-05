package ie.requiem.rules

private val dotRun = Regex("[•●]+")
fun String.spokenForScreenReader(): String = replace(" → ", " to ")
    .replace(dotRun) { "${it.value.length} ${if (it.value.length == 1) "dot" else "dots"}" }
    .replace("–", " to ")
