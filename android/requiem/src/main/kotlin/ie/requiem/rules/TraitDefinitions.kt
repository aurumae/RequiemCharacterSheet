package ie.requiem.rules

enum class CharacterDetail(val label: String, val catalogKind: CatalogKind? = null) {
    Name("Name"), Player("Player"), Chronicle("Chronicle"), Mask("Mask", CatalogKind.archetypes),
    Dirge("Dirge", CatalogKind.archetypes), Concept("Concept"), Clan("Clan", CatalogKind.clans),
    Bloodline("Bloodline", CatalogKind.bloodlines), Covenant("Covenant", CatalogKind.covenants);

    fun value(c: CharacterSave, catalog: Catalog): String = when (this) {
        Name -> c.name; Player -> c.player; Chronicle -> c.chronicle; Mask -> c.mask; Dirge -> c.dirge
        Concept -> c.concept; Clan -> catalog.name(CatalogKind.clans, c.clan)
        Bloodline -> catalog.name(CatalogKind.bloodlines, c.bloodline); Covenant -> catalog.name(CatalogKind.covenants, c.covenant)
    }
}
