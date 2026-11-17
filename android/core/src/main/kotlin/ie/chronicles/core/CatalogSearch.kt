package ie.chronicles.core

import java.text.Normalizer
import java.util.Locale

/** A catalog picker query, normalized once for filtering and ranking results. */
class CatalogSearch(query: String) {
    private val needle = fold(query.trim())
    val isEmpty: Boolean get() = needle.isEmpty()

    fun matches(text: String): Boolean = isEmpty || fold(text).contains(needle)

    private companion object {
        private val combiningMarks = Regex("""\p{M}+""")

        // These are the quote variants recognized by CatalogCore.swift's matchesSearch.
        private fun fold(text: String): String {
            val quotes = buildString(text.length) {
                for (c in text) append(when (c) {
                    '‘', '’', '‚', '‛', '′', 'ʼ', '`', '´' -> '\''
                    '“', '”', '„', '‟', '″' -> '"'
                    else -> c
                })
            }
            return Normalizer.normalize(quotes.lowercase(Locale.ROOT), Normalizer.Form.NFD)
                .replace(combiningMarks, "")
        }
    }
}
