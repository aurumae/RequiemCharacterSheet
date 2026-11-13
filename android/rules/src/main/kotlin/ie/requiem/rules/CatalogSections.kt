package ie.requiem.rules

/** Stable row namespaces also allow an entry to appear in the in-clan list and its book. */
data class CatalogSection<T>(val id: String, val book: String?, val title: String, val entries: List<T>)

fun <T> Catalog.bookSections(rows: List<T>, entry: (T) -> BookEntry, group: (T) -> String = { "" }): List<CatalogSection<T>> =
    books.flatMap { (id, name) ->
        rows.filter { entry(it).bookId == id }.groupBy(group).entries.mapIndexed { index, (title, entries) ->
            CatalogSection("$id/$title", if (index == 0) name else null, title, entries)
        }
    }

fun CharacterSave.catalogSections(kind: EntryKind, catalog: Catalog, query: String = "", choosingMystery: Boolean = false): List<CatalogSection<CatalogOption>> {
    val rows = catalogOptions(kind, catalog, query, choosingMystery)
    val inClan = if (kind == EntryKind.Discipline) rows.filter { it.entry.id in inClanDisciplines(catalog) } else emptyList()
    return (if (inClan.isEmpty()) emptyList() else listOf(CatalogSection("in-clan", null, "In-clan for ${inClanGroupName(catalog)}", inClan))) +
        catalog.bookSections(rows, { it.entry }, { if (kind in listOf(EntryKind.Discipline, EntryKind.Coil, EntryKind.Bane)) "" else it.group })
}
