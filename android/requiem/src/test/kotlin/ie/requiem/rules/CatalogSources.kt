package ie.requiem.rules

import java.io.File
import kotlinx.serialization.json.*

/** Read the authoritative files independently of the generated classpath resource index. */
internal fun sourceCatalogs(): List<JsonObject> = File(requireNotNull(System.getProperty("catalogSourceDir")))
    .listFiles()!!.filter { it.extension == "json" }
    .sortedWith(compareBy<File> { it.name != "vtr2e-core.json" }.thenBy { it.name })
    .map { Json.parseToJsonElement(it.readText()).jsonObject }
    .filter { it["format"]?.jsonPrimitive?.content == "requiem-catalog" && it.getValue("version").jsonPrimitive.int <= 1 }

internal fun sourceEntries(kind: CatalogKind): Map<String, JsonObject> = linkedMapOf<String, JsonObject>().apply {
    sourceCatalogs().forEach { book -> book[kind.name]?.jsonArray.orEmpty().forEach { raw ->
        val entry = raw.jsonObject
        putIfAbsent(entry.getValue("id").jsonPrimitive.content, entry)
    } }
}
