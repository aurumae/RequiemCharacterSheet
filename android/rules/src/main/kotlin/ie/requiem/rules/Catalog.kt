package ie.requiem.rules

import java.text.Normalizer
import java.util.Locale
import kotlinx.serialization.json.*

enum class CatalogKind {
    disciplines, merits, banes, clans, bloodlines, covenants, rituals, devotions, mysteries, scales, archetypes
}

/** Indexes the original book JSON, keeping the full rule and presentation data on each entry. */
class Catalog(files: Map<String, String>) {
    private val byId = CatalogKind.entries.associateWith { linkedMapOf<String, JsonObject>() }
    private val byName = CatalogKind.entries.associateWith { mutableMapOf<String, String>() }

    private val bookNames = mutableMapOf<String, String>()
    val books: Map<String, String> get() = bookNames

    init {
        val order = compareBy<String> { it != "vtr2e-core.json" }.thenBy { it }
        for ((_, contents) in files.toSortedMap(order)) {
            val file = Json.parseToJsonElement(contents).jsonObject
            if (file["format"]?.jsonPrimitive?.content != "requiem-catalog" ||
                file.getValue("version").jsonPrimitive.int > 1) continue
            val book = file.getValue("book").jsonObject
            bookNames.putIfAbsent(book.getValue("id").jsonPrimitive.content, book.getValue("name").jsonPrimitive.content)
            for (kind in CatalogKind.entries) {
                for (element in file[kind.name]?.jsonArray.orEmpty()) {
                    val entry = element.jsonObject
                    val id = entry.getValue("id").jsonPrimitive.content
                    if (byId.getValue(kind).putIfAbsent(id, entry) == null) {
                        val name = entry.getValue("name").jsonPrimitive.content
                        byName.getValue(kind).putIfAbsent(matchKey(name), id)
                    }
                }
            }
        }
    }

    fun entries(kind: CatalogKind): Map<String, JsonObject> = byId.getValue(kind)

    fun names(kind: CatalogKind): List<String> = entries(kind).values.map { it.getValue("name").jsonPrimitive.content }

    fun name(kind: CatalogKind, source: TraitSource): String = source.custom
        ?: entries(kind)[source.catalog]?.get("name")?.jsonPrimitive?.content
        ?: source.catalog.orEmpty()

    fun source(kind: CatalogKind, name: String): TraitSource {
        val id = byName.getValue(kind)[matchKey(name)]
        return if (id != null) TraitSource(catalog = id) else TraitSource(custom = name)
    }

    private fun matchKey(name: String): String =
        Normalizer.normalize(name.lowercase(Locale.ROOT), Normalizer.Form.NFD)
            .replace(combiningMarks, "").replace('’', '\'').removePrefix("the ")

    companion object {
        private val combiningMarks = Regex("\\p{M}+")
        private fun resource(name: String): String =
            requireNotNull(Catalog::class.java.getResourceAsStream("/catalogs/$name")) { "Missing catalog resource: $name" }
                .bufferedReader(Charsets.UTF_8).use { it.readText() }

        fun bundled(): Catalog = Catalog(resource("index.txt").lines().filter { it.isNotEmpty() }.associateWith(::resource))
    }
}
