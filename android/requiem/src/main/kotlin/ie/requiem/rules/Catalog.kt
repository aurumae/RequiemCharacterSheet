package ie.requiem.rules

import ie.chronicles.core.CatalogIndex
import kotlinx.serialization.json.*

enum class CatalogKind {
    disciplines, merits, banes, clans, bloodlines, covenants, rituals, devotions, mysteries, scales, archetypes, conditions, elderBanes
}

/** Indexes the original book JSON, keeping the full rule and presentation data on each entry. */
class Catalog(files: Map<String, String>) {
    private val indexes: Map<CatalogKind, CatalogIndex<JsonObject>>

    private val bookNames = mutableMapOf<String, String>()
    val books: Map<String, String> get() = bookNames

    init {
        val rows = CatalogKind.entries.associateWith { mutableListOf<JsonObject>() }
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
                    rows.getValue(kind).add(entry)
                }
            }
        }
        indexes = rows.mapValues { (_, entries) -> CatalogIndex(entries, { it.getValue("id").jsonPrimitive.content }, { it.getValue("name").jsonPrimitive.content }) }
    }

    fun entries(kind: CatalogKind): Map<String, JsonObject> = indexes.getValue(kind).byId

    fun names(kind: CatalogKind): List<String> = entries(kind).values.map { it.getValue("name").jsonPrimitive.content }

    fun name(kind: CatalogKind, source: TraitSource): String = indexes.getValue(kind).name(source)
    fun source(kind: CatalogKind, name: String): TraitSource = indexes.getValue(kind).source(name)

    companion object {
        private fun resource(name: String): String =
            requireNotNull(Catalog::class.java.getResourceAsStream("/catalogs/$name")) { "Missing catalog resource: $name" }
                .bufferedReader(Charsets.UTF_8).use { it.readText() }

        fun bundled(): Catalog = Catalog(resource("index.txt").lines().filter { it.isNotEmpty() }.associateWith(::resource))
    }
}
