package ie.chronicles.core

import java.text.Normalizer
import java.util.Locale

/** Caller supplies game entries in precedence order. First ID and first folded name win. */
class CatalogIndex<T>(entries: List<T>, private val id: (T) -> String, private val name: (T) -> String) {
    val byId: Map<String, T> = linkedMapOf<String, T>().apply { entries.forEach { putIfAbsent(id(it), it) } }
    private val byName = linkedMapOf<String, T>().apply { byId.values.forEach { putIfAbsent(matchKey(name(it)), it) } }
    fun source(text: String): TraitSource = byName[matchKey(text)]?.let { TraitSource(catalog = id(it)) } ?: TraitSource(custom = text)
    fun name(source: TraitSource): String = source.custom ?: byId[source.catalog]?.let(name) ?: source.catalog.orEmpty()
    companion object {
        private val combiningMarks = Regex("\\p{M}+")
        private fun matchKey(name: String): String = Normalizer.normalize(name.lowercase(Locale.ROOT), Normalizer.Form.NFD)
            .replace(combiningMarks, "").replace('’', '\'').removePrefix("the ")
    }
}

/** Stable row namespaces also allow an entry in a featured section and its book. */
data class CatalogSection<T>(val id: String, val book: String?, val title: String, val entries: List<T>)
fun <T> bookSections(books: Map<String, String>, rows: List<T>, bookId: (T) -> String, group: (T) -> String): List<CatalogSection<T>> =
    books.flatMap { (id, name) ->
        rows.filter { bookId(it) == id }.groupBy(group).entries.mapIndexed { index, (title, entries) ->
            CatalogSection("$id/$title", if (index == 0) name else null, title, entries)
        }
    }
