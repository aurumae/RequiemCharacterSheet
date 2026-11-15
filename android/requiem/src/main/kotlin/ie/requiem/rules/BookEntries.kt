package ie.requiem.rules

import kotlinx.serialization.json.*

internal fun JsonObject.str(key: String): String? = (get(key) as? JsonPrimitive)?.contentOrNull
internal fun JsonObject.int(key: String, default: Int = 0): Int = (get(key) as? JsonPrimitive)?.intOrNull ?: default
internal fun JsonObject.flag(key: String): Boolean = (get(key) as? JsonPrimitive)?.booleanOrNull == true
internal fun JsonObject.obj(key: String): JsonObject? = get(key) as? JsonObject
internal fun JsonObject.array(key: String): List<JsonElement> = (get(key) as? JsonArray).orEmpty()
internal fun JsonObject.objects(key: String): List<JsonObject> = array(key).mapNotNull { it as? JsonObject }
internal fun JsonObject.strings(key: String): List<String> = array(key).mapNotNull { (it as? JsonPrimitive)?.contentOrNull }
internal fun JsonObject.ints(key: String): List<Int> = array(key).mapNotNull { (it as? JsonPrimitive)?.intOrNull }

/** Typed presentation boundary: Compose doesn't need to know the book JSON structure. */
class BookEntry internal constructor(val kind: CatalogKind, internal val raw: JsonObject, private val books: Map<String, String>) {
    val id: String get() = raw.str("id").orEmpty()
    val name: String get() = raw.str("name").orEmpty()
    val summary: String get() = raw.str("summary").orEmpty()
    val category: String get() = raw.str("category") ?: "other"
    val ratings: List<Int> get() = raw.ints("ratings").sorted()
    val repeatable: Boolean get() = raw.flag("repeatable")
    val qualifierPrompt: String? get() = raw.obj("qualifier")?.str("prompt")
    val qualifierOptions: List<String> get() = raw.obj("qualifier")?.strings("options").orEmpty()
    val qualifierFromSpecialties: Boolean get() = raw.obj("qualifier")?.flag("fromSpecialties") == true
    val qualifierFromCovenants: Boolean get() = raw.obj("qualifier")?.flag("fromCovenants") == true
    val coilOnly: Boolean get() = raw.flag("coilOnly")
    val bookId: String get() = raw.obj("source")?.str("book").orEmpty()
    val bookName: String get() = books[bookId] ?: bookId
    val isRitualDiscipline: Boolean get() = raw.str("kind") == "ritual"
    val coilName: String get() = raw.obj("coil")?.str("name") ?: name
    val dots: Int get() = raw.int("dots", 1)
    val discipline: String get() = raw.str("discipline").orEmpty()
    val experienceCost: Int get() = raw.int("experienceCost", 1)
    val citation: String get() {
        val source = raw.obj("source") ?: return ""
        val book = source.str("book").orEmpty()
        return (books[book] ?: book) + (source.str("page")?.let { ", p. $it" } ?: "")
    }
    fun allowedRating(value: Int): Int = if (value <= 0) 0 else ratings.firstOrNull { it >= value } ?: ratings.lastOrNull() ?: value.coerceIn(0, 5)
}

fun Catalog.entry(kind: CatalogKind, id: String?): BookEntry? = entries(kind)[id]?.let { BookEntry(kind, it, books) }
fun Catalog.entry(kind: CatalogKind, source: TraitSource): BookEntry? = entry(kind, source.catalog)
fun Catalog.bookEntries(kind: CatalogKind): List<BookEntry> = entries(kind).values.map { BookEntry(kind, it, books) }

fun Catalog.parseMerit(name: String): Pair<TraitSource, String?> {
    val direct = source(CatalogKind.merits, name)
    if (direct.catalog != null) return direct to null
    if (name.endsWith(')') && '(' in name) {
        val base = source(CatalogKind.merits, name.substringBeforeLast('(').trim())
        val qualifier = name.substringAfterLast('(').dropLast(1).trim()
        if (base.catalog != null && qualifier.isNotEmpty()) return base to qualifier
    }
    return direct to null
}

fun Merit.displayName(catalog: Catalog): String = catalog.name(CatalogKind.merits, source) + (qualifier?.let { " ($it)" } ?: "")
fun Coil.displayName(catalog: Catalog): String = catalog.entry(CatalogKind.mysteries, mystery)?.coilName ?: catalog.name(CatalogKind.mysteries, mystery)
fun Ritual.discipline(catalog: Catalog): TraitSource = catalog.entry(CatalogKind.rituals, source)?.let { TraitSource(catalog = it.discipline) } ?: customDiscipline
fun Ritual.dots(catalog: Catalog): Int = catalog.entry(CatalogKind.rituals, source)?.dots ?: customDots

fun traitName(id: String): String = (attributeDefinitions + skillDefinitions).firstOrNull { it.id == id }?.name ?: id
internal fun dotsText(value: Int): String = "•".repeat(value.coerceIn(0, 10))
fun BookEntry.ratingsDescription(): String = ratings.joinToString(" or ") { "$it ${if (it == 1) "dot" else "dots"}" }

fun BookEntry.ratingsText(): String {
    fun dots(value: Int) = "●".repeat(value.coerceIn(0, 10))
    if (ratings.isEmpty()) return ""
    if (ratings.size == 1) return dots(ratings.first())
    return if (ratings == (ratings.first()..ratings.last()).toList()) "${dots(ratings.first())} to ${dots(ratings.last())}"
    else ratings.joinToString(" or ", transform = ::dots)
}
