package ie.requiem.rules

fun CharacterSave.inClanGroupName(catalog: Catalog): String =
    catalog.entry(CatalogKind.bloodlines, bloodline)?.name ?: catalog.name(CatalogKind.clans, clan)

fun CharacterSave.reasonCantLearn(entry: BookEntry, catalog: Catalog): String? {
    val required = entry.raw.str("bloodline") ?: return null
    if (bloodline.catalog == required) return null
    return "Only the ${catalog.name(CatalogKind.bloodlines, TraitSource(catalog = required))} bloodline can learn ${entry.name}"
}

data class BloodlineBaneInfo(val bloodline: String, val name: String, val summary: String, val citation: String)
fun CharacterSave.bloodlineBane(catalog: Catalog): BloodlineBaneInfo? {
    val entry = catalog.entry(CatalogKind.bloodlines, bloodline) ?: return null
    val bane = entry.raw.obj("bane") ?: return null
    return BloodlineBaneInfo(entry.name, bane.str("name").orEmpty(), bane.str("summary").orEmpty(), entry.citation)
}

data class IdentityOption(val entry: BookEntry, val group: String, val details: List<String>, val warning: String?)
fun CharacterSave.identityOptions(field: CharacterDetail, catalog: Catalog, query: String = ""): List<IdentityOption> {
    val kind = field.catalogKind ?: return emptyList()
    val options = catalog.bookEntries(kind).map { entry ->
        val parents = entry.raw.strings("parentClans")
        val matches = clan.catalog in parents
        val group = if (kind == CatalogKind.bloodlines && matches) "${catalog.name(CatalogKind.clans, clan)} Bloodlines" else field.label + "s"
        val details = buildList {
            if (parents.isNotEmpty()) add("Parent clan: " + parents.joinToString { catalog.name(CatalogKind.clans, TraitSource(catalog = it)) })
            entry.raw.strings("favoredAttributes").takeIf { it.isNotEmpty() }?.let { add("Favoured Attributes: " + it.joinToString(transform = ::traitName)) }
            entry.raw.strings("disciplines").takeIf { it.isNotEmpty() }?.let { ids ->
                add("Disciplines: " + ids.joinToString { catalog.name(CatalogKind.disciplines, TraitSource(catalog = it)) })
            }
            entry.raw.obj("bane")?.let { add("Bane: ${it.str("name").orEmpty()} — ${it.str("summary").orEmpty()}") }
        }
        IdentityOption(entry, group, details, if (parents.isNotEmpty() && !matches)
            "A bloodline of the " + parents.joinToString { catalog.name(CatalogKind.clans, TraitSource(catalog = it)) } else null)
    }
    val own = options.any { it.warning == null && kind == CatalogKind.bloodlines }
    return options.sortedWith(compareBy<IdentityOption> { it.warning != null }.thenBy { it.entry.name })
        .map { if (own && it.warning != null) it.copy(group = "Other Bloodlines") else it }
        .filter { query.isBlank() || (it.entry.name + " " + it.entry.summary).contains(query.trim(), ignoreCase = true) }
}
