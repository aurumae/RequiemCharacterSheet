package ie.chronicles.core

enum class TraitCategory(val title: String, val unskilledPenalty: Int) {
    Mental("Mental", -3), Physical("Physical", -1), Social("Social", -1)
}

data class TraitDefinition(val id: String, val name: String, val category: TraitCategory)

// Stable IDs and order match the shared modern Chronicles skill list.
val attributeDefinitions = listOf(
    "intelligence", "wits", "resolve", "strength", "dexterity", "stamina",
    "presence", "manipulation", "composure",
).mapIndexed { index, id -> TraitDefinition(id, id.replaceFirstChar { it.uppercaseChar() }, TraitCategory.entries[index / 3]) }

val modernSkillDefinitions = listOf(
    "academics", "computer", "crafts", "investigation", "medicine", "occult", "politics", "science",
    "athletics", "brawl", "drive", "firearms", "larceny", "stealth", "survival", "weaponry",
    "animal-ken", "empathy", "expression", "intimidation", "persuasion", "socialize", "streetwise", "subterfuge",
).mapIndexed { index, id -> TraitDefinition(id, id.split('-').joinToString(" ") { it.replaceFirstChar { c -> c.uppercaseChar() } },
    TraitCategory.entries[index / 8]) }
