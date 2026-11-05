package ie.requiem.rules

enum class TraitCategory(val title: String, val unskilledPenalty: Int) {
    Mental("Mental", -3), Physical("Physical", -1), Social("Social", -1)
}

data class TraitDefinition(val id: String, val name: String, val category: TraitCategory)

// Stable IDs and order match Swift's TraitDefinitions and the vampire-core skill list.
val attributeDefinitions = listOf(
    "intelligence", "wits", "resolve", "strength", "dexterity", "stamina",
    "presence", "manipulation", "composure",
).mapIndexed { index, id -> TraitDefinition(id, id.replaceFirstChar { it.uppercaseChar() }, TraitCategory.entries[index / 3]) }

val skillDefinitions = listOf(
    "academics", "computer", "crafts", "investigation", "medicine", "occult", "politics", "science",
    "athletics", "brawl", "drive", "firearms", "larceny", "stealth", "survival", "weaponry",
    "animal-ken", "empathy", "expression", "intimidation", "persuasion", "socialize", "streetwise", "subterfuge",
).mapIndexed { index, id -> TraitDefinition(id, id.split('-').joinToString(" ") { it.replaceFirstChar { c -> c.uppercaseChar() } },
    TraitCategory.entries[index / 8]) }

enum class CharacterDetail(val label: String, val catalogKind: CatalogKind? = null) {
    Name("Name"), Player("Player"), Chronicle("Chronicle"), Mask("Mask", CatalogKind.archetypes),
    Dirge("Dirge", CatalogKind.archetypes), Concept("Concept"), Clan("Clan", CatalogKind.clans),
    Bloodline("Bloodline"), Covenant("Covenant", CatalogKind.covenants);

    fun value(c: CharacterSave, catalog: Catalog): String = when (this) {
        Name -> c.name; Player -> c.player; Chronicle -> c.chronicle; Mask -> c.mask; Dirge -> c.dirge
        Concept -> c.concept; Clan -> catalog.name(CatalogKind.clans, c.clan)
        Bloodline -> c.bloodline; Covenant -> catalog.name(CatalogKind.covenants, c.covenant)
    }
}
