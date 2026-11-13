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
    val clanEntry = catalog.entry(CatalogKind.clans, clan)
    val entries = catalog.bookEntries(kind)
    val hasOwnGroup = kind == CatalogKind.bloodlines && clanEntry != null && entries.any {
        val parents = it.raw.strings("parentClans")
        parents.isEmpty() || clanEntry.id in parents
    }
    val options = entries.map { entry ->
        val parents = entry.raw.strings("parentClans")
        val matches = clanEntry == null || parents.isEmpty() || clanEntry.id in parents
        val group = if (!hasOwnGroup) "" else if (matches) "${clanEntry!!.name} Bloodlines" else "Other Bloodlines"
        val requiredCovenant = entry.raw.str("requiredCovenant")
        val details = buildList {
            entry.raw.str("singleWillpower")?.let { add("Single Willpower: $it") }
            entry.raw.str("allWillpower")?.let { add("All Willpower: $it") }
            if (kind == CatalogKind.bloodlines) add("Parent clan: " + if (parents.isEmpty()) "Any clan" else parents.joinToString { catalog.name(CatalogKind.clans, TraitSource(catalog = it)) })
            requiredCovenant?.let { add("Required covenant: " + catalog.name(CatalogKind.covenants, TraitSource(catalog = it))) }
            entry.raw.strings("favoredAttributes").takeIf { it.isNotEmpty() }?.let { add("Favoured Attributes: " + it.joinToString(transform = ::traitName)) }
            entry.raw.strings("disciplines").takeIf { it.isNotEmpty() }?.let { ids ->
                add("Disciplines: " + ids.joinToString { catalog.name(CatalogKind.disciplines, TraitSource(catalog = it)) })
            }
            entry.raw.obj("bane")?.let { add("Bane: ${it.str("name").orEmpty()} — ${it.str("summary").orEmpty()}") }
        }
        val warnings = buildList {
            if (!matches) add("A bloodline of the " + parents.joinToString { catalog.name(CatalogKind.clans, TraitSource(catalog = it)) })
            if (requiredCovenant != null && !belongsToCovenant(requiredCovenant, catalog)) add("Requires " + catalog.name(CatalogKind.covenants, TraitSource(catalog = requiredCovenant)))
        }
        IdentityOption(entry, group, details, warnings.joinToString(". ").ifEmpty { null })
    }
    return options.sortedWith(compareBy<IdentityOption> { it.group == "Other Bloodlines" }.thenBy { it.entry.name })
        .filter { query.isBlank() || (it.entry.name + " " + it.entry.summary + " " + it.entry.bookName + " " + it.details.joinToString(" ")).contains(query.trim(), ignoreCase = true) }
}
