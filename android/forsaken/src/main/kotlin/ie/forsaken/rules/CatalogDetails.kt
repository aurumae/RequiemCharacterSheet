package ie.forsaken.rules

import ie.chronicles.core.*
import kotlinx.serialization.json.*

data class DetailText(val title: String, val text: String)

/** Catalog prose and facts only. Numeric effects/prerequisites are not evaluated by the preview. */
fun catalogDetails(entry: ForsakenEntry, catalog: ForsakenCatalog): List<DetailText> = buildList {
    fun line(label: String, text: String?) { if (!text.isNullOrBlank()) add(DetailText(label, text)) }
    line("", entry.summary)
    line("Source", catalog.citation(entry))
    if (catalog.books[entry.source.book]?.official == false) line("", "Unofficial content")
    val labels = mapOf("kind" to "Kind", "moon" to "Moon", "renown" to "Renown", "category" to "Category",
        "rating" to "Rating", "dots" to "Dots", "cost" to "Cost", "action" to "Action", "dicePool" to "Dice pool",
        "duration" to "Duration", "targetSuccesses" to "Target successes", "interval" to "Roll interval", "symbols" to "Symbols",
        "spirit" to "Spirit", "activation" to "Activation", "effect" to "Effect", "requirements" to "Requirements",
        "totem" to "Totem", "blessing" to "Blessing", "aspiration" to "Aspiration", "ban" to "Ban", "tools" to "Tools",
        "resolution" to "Resolution", "beat" to "Beat", "possibleSources" to "Possible sources",
        "cause" to "Cause", "ending" to "Ending", "passive" to "Passive", "common" to "Common", "specific" to "Specific",
        "firstTongueName" to "First Tongue")
    labels.forEach { (key, label) -> line(label, entry.text(key)) }
    if (entry.flag("persistent")) line("", "Persistent Condition")
    if (entry.flag("repeatable")) line("", "May be taken more than once")
    line("Ratings", entry.strings("ratings").joinToString(", "))
    line("Skills", entry.strings("skills").joinToString(", ", transform = ::traitName))
    line("Secondary Renown", entry.strings("secondaryRenown").joinToString(", ", transform = ::traitName))
    line("Forms", entry.strings("effectForms").joinToString(", ", transform = ::traitName))
    for ((key, kind) in mapOf("auspice" to CatalogKind.auspices, "moonGift" to CatalogKind.gifts, "replaces" to CatalogKind.gifts)) {
        val label = mapOf("auspice" to "Auspice", "moonGift" to "Moon Gift", "replaces" to "Replaces").getValue(key)
        entry.text(key)?.let { id -> line(label, catalog.entry(kind, id)?.name ?: id) }
    }
    for ((key, kind) in mapOf("giftAffinities" to CatalogKind.gifts, "auspices" to CatalogKind.auspices, "tribes" to CatalogKind.tribes,
        "merits" to CatalogKind.merits, "rites" to CatalogKind.rites, "fetishes" to CatalogKind.fetishes)) {
        val label = if (key == "giftAffinities") "Gift affinities" else traitName(key)
        line(label, entry.strings(key).joinToString(", ") { catalog.entry(kind, it)?.name ?: it })
    }
    for (key in listOf("oath", "benefit", "huntersAspect")) {
        val value = entry.fields[key]
        if (value is JsonPrimitive) line(traitName(key), value.contentOrNull)
        if (value is JsonObject) {
            val title = value["name"]?.jsonPrimitive?.content ?: traitName(key)
            val condition = value["condition"]?.jsonPrimitive?.content?.let { catalog.entry(CatalogKind.conditions, it)?.name ?: it }
            line(title, value["summary"]?.jsonPrimitive?.content ?: condition)
        }
    }
    entry.array("huntersAspects").forEach {
        val values = it.jsonObject
        line("Hunter's Aspect", values.getValue("name").jsonPrimitive.content + " · " + values.getValue("condition").jsonPrimitive.content.let { id ->
            catalog.entry(CatalogKind.conditions, id)?.name ?: id })
    }
    entry.objectValue("qualifier")?.let { qualifier ->
        line("Choice", qualifier["prompt"]?.jsonPrimitive?.content)
        line("Options", (qualifier["options"] as? JsonArray)?.joinToString(", ") { it.jsonPrimitive.content })
    }
    entry.array("prerequisites").forEach { element ->
        val req = element.jsonObject
        fun text(key: String) = (req[key] as? JsonPrimitive)?.contentOrNull
        val kind = text("kind").orEmpty()
        val id = text("id")
        val name = when (kind) {
            "merit" -> catalog.entry(CatalogKind.merits, id)?.name ?: id
            "tribe", "notTribe" -> catalog.entry(CatalogKind.tribes, id)?.name ?: id
            "attribute", "skill", "renown" -> id?.let(::traitName)
            "harmony" -> "Harmony"
            "primalUrge" -> "Primal Urge"
            else -> null
        }
        line("Prerequisite", listOfNotNull(name, text("minimum"), text("text")).joinToString(" "))
    }
    entry.array("styleManeuvers").forEach { element ->
        val values = element.jsonObject
        line(values["name"]?.jsonPrimitive?.content ?: "Maneuver", values["summary"]?.jsonPrimitive?.content)
    }
    entry.noteOptions.forEach { option ->
        line(listOfNotNull(option.group, option.name).joinToString(" · "), option.summary)
        option.source?.takeIf { it != entry.source }?.let { line("Source", it.citation(catalog.books)) }
    }
    entry.array("facets").forEach { element ->
        val facet = ForsakenEntry(element.jsonObject)
        line(facet.name, catalogDetails(facet, catalog).joinToString("\n\n") { if (it.title.isEmpty()) it.text else "${it.title}\n${it.text}" })
    }
}
