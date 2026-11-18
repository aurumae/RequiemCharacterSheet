package ie.forsaken.rules

import ie.chronicles.core.*
import kotlinx.serialization.json.*

enum class CatalogKind(val title: String) {
    auspices("Auspices"), tribes("Tribes"), lodges("Lodges"), archetypes("Blood and Bone"), gifts("Gifts"),
    rites("Rites"), merits("Merits"), conditions("Conditions"), fetishes("Fetishes"),
    kuruthTriggers("Kuruth Triggers"), tilts("Tilts"),
}

/** All fields are retained, including nested effects. Phase 2 presents text, and applies no numeric effects. */
data class ForsakenEntry(val fields: JsonObject) {
    val id = fields.getValue("id").jsonPrimitive.content
    val name = fields.getValue("name").jsonPrimitive.content
    val summary = fields.getValue("summary").jsonPrimitive.content
    val source = BookSource.read(fields.getValue("source").jsonObject)
    fun text(key: String): String? = (fields[key] as? JsonPrimitive)?.contentOrNull
    fun number(key: String): Int? = (fields[key] as? JsonPrimitive)?.intOrNull
    fun flag(key: String): Boolean = (fields[key] as? JsonPrimitive)?.booleanOrNull == true
    fun strings(key: String): List<String> = array(key).mapNotNull { (it as? JsonPrimitive)?.contentOrNull }
    fun array(key: String): List<JsonElement> = (fields[key] as? JsonArray).orEmpty()
    fun objectValue(key: String): JsonObject? = fields[key] as? JsonObject
    val noteOptions get() = array("noteOptions").map { ConditionNoteOption.read(it.jsonObject) }
}
data class CatalogFacet(val gift: ForsakenEntry, val facet: ForsakenEntry)

class ForsakenCatalog private constructor(files: List<CatalogFile>) {
    val sourceFiles = files.map { it.name }
    val books = files.associate { it.book.id to it.book }
    private val indexes = CatalogKind.entries.associateWith { kind ->
        CatalogIndex(files.flatMap { it.entries[kind].orEmpty() }, ForsakenEntry::id, ForsakenEntry::name)
    }
    private val facets: Map<String, CatalogFacet> = buildMap {
        all(CatalogKind.gifts).forEach { gift -> gift.array("facets").forEach {
            val facet = ForsakenEntry(it.jsonObject)
            putIfAbsent(facet.id, CatalogFacet(gift, facet))
        } }
    }
    fun index(kind: CatalogKind) = indexes.getValue(kind)
    fun all(kind: CatalogKind) = index(kind).byId.values.toList()
    fun entry(kind: CatalogKind, id: String?) = index(kind).byId[id]
    fun name(kind: CatalogKind, source: TraitSource) = index(kind).name(source)
    fun facet(id: String?) = facets[id]
    fun visible(kind: CatalogKind, unofficial: Boolean) = all(kind).filter { unofficial || books[it.source.book]?.official != false }
    fun citation(entry: ForsakenEntry) = entry.source.citation(books)

    companion object {
        val bundled: ForsakenCatalog by lazy {
            val loader = ForsakenCatalog::class.java.classLoader
            val names = requireNotNull(loader.getResourceAsStream("forsaken-catalogs/index.txt"))
                .bufferedReader().use { it.readLines().filter(String::isNotBlank) }
            fromFiles(names.associateWith { name ->
                requireNotNull(loader.getResourceAsStream("forsaken-catalogs/$name")) { "Missing catalog $name" }
                    .bufferedReader().use { it.readText() }
            })
        }
        fun fromFiles(sources: Map<String, String>): ForsakenCatalog {
            val core = listOf("wtf2e-core", "cofd-core")
            val files = sources.map { (name, text) ->
                val raw = Json.parseToJsonElement(text).jsonObject
                val format = raw.getValue("format").jsonPrimitive.content
                require(format in setOf("forsaken-catalog", "requiem-catalog")) { "Unsupported catalog $name" }
                require(raw.getValue("version").jsonPrimitive.int == 1) { "Unsupported catalog version in $name" }
                CatalogFile(name, CatalogBook.read(raw.getValue("book").jsonObject), CatalogKind.entries.associateWith { kind ->
                    if (format == "requiem-catalog" && kind !in listOf(CatalogKind.merits, CatalogKind.conditions)) emptyList()
                    else (raw[kind.name] as? JsonArray).orEmpty().map { ForsakenEntry(it.jsonObject) }
                })
            }.sortedWith(compareBy<CatalogFile> { !it.book.official }
                .thenBy { core.indexOf(it.name.removeSuffix(".json")).let { rank -> if (rank < 0) core.size else rank } }
                .thenBy { it.name.removeSuffix(".json") })
            return ForsakenCatalog(files)
        }
    }
}
private data class CatalogFile(val name: String, val book: CatalogBook, val entries: Map<CatalogKind, List<ForsakenEntry>>)
