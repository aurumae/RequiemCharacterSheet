package ie.chronicles.core

import kotlinx.serialization.json.*

data class CatalogBook(val id: String, val name: String, val official: Boolean = true, val url: String? = null) {
    companion object {
        fun read(book: JsonObject) = CatalogBook(book.getValue("id").jsonPrimitive.content,
            book.getValue("name").jsonPrimitive.content, book["official"]?.jsonPrimitive?.booleanOrNull ?: true,
            book["url"]?.jsonPrimitive?.contentOrNull)
    }
}

data class BookSource(val book: String, val page: String?) {
    fun citation(books: Map<String, CatalogBook>): String {
        val reference = books[book]
        return reference?.url ?: ((reference?.name ?: book) + (page?.let { ", p. $it" } ?: ""))
    }
    companion object {
        fun read(source: JsonObject) = BookSource(source.getValue("book").jsonPrimitive.content,
            source["page"]?.jsonPrimitive?.contentOrNull)
    }
}

data class ConditionNoteOption(val id: String, val name: String, val summary: String, val group: String?, val source: BookSource?) {
    companion object {
        fun read(option: JsonObject) = ConditionNoteOption(option.getValue("id").jsonPrimitive.content,
            option.getValue("name").jsonPrimitive.content, option.getValue("summary").jsonPrimitive.content,
            option["group"]?.jsonPrimitive?.contentOrNull, (option["source"] as? JsonObject)?.let(BookSource::read))
    }
}
