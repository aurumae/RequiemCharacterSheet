package ie.forsaken.rules

import ie.chronicles.core.*
import kotlinx.serialization.json.*

enum class PreviewRowStyle { Heading, Subheading, Value, Note, Rating, Health, Willpower, Catalog }
data class PreviewRow(
    val section: ForsakenSection, val key: String, val title: String, val value: String = "",
    val style: PreviewRowStyle = PreviewRowStyle.Value, val rating: Int? = null,
    val reference: String? = null, val date: Double? = null,
)

fun ForsakenCatalog.resolve(reference: String): ForsakenEntry? = if (reference.startsWith("facet/")) facet(reference.substringAfter('/'))?.facet
    else CatalogKind.entries.firstOrNull { it.name == reference.substringBefore('/') }?.let { entry(it, reference.substringAfter('/')) }

fun traitName(id: String) = (attributeDefinitions + modernSkillDefinitions).firstOrNull { it.id == id }?.name
    ?: id.replaceFirstChar(Char::uppercaseChar)

/** Present saved values without silently applying grants, clamping purchases or inventing effective totals. */
fun previewRows(c: ForsakenState, catalog: ForsakenCatalog): List<PreviewRow> = buildList {
    for (section in ForsakenSection.available(c, catalog)) {
        var sequence = 0
        fun row(title: String, value: String = "", style: PreviewRowStyle = PreviewRowStyle.Value,
            rating: Int? = null, reference: String? = null, date: Double? = null) {
            add(PreviewRow(section, "${section.name}/${sequence++}", title, value, style, rating, reference, date))
        }
        fun note(text: String) = row(text, style = PreviewRowStyle.Note)
        fun sub(title: String) = row(title, style = PreviewRowStyle.Subheading)
        fun source(title: String, kind: CatalogKind, value: TraitSource) = row(title,
            catalog.name(kind, value).ifEmpty { "Not set" }, reference = value.catalog?.let { "${kind.name}/$it" })
        fun empty() = note("None saved")
        fun fact(entry: ForsakenEntry?, keys: List<String>) = keys.mapNotNull { key -> entry?.text(key)?.takeIf(String::isNotBlank) }.joinToString(" · ")
        row(section.title, style = PreviewRowStyle.Heading)
        when (section) {
            ForsakenSection.Creation -> c.creation?.let { creation ->
                note("Guided creation is in progress. These are the saved choices. Creation editing is not available in this preview.")
                for ((label, priorities) in listOf("Attribute priorities" to creation.attributePriorities, "Skill priorities" to creation.skillPriorities)) {
                    sub(label)
                    for (category in TraitCategory.entries) {
                        val priority = priorities[category.name.lowercase()]
                        row(category.title, listOf("Primary", "Secondary", "Tertiary").getOrNull(priority ?: -1)
                            ?: priority?.toString() ?: "Not chosen")
                    }
                }
                row("Free Skill", creation.freeSkill?.let(::traitName) ?: "Not chosen")
                row("Granted Renown", creation.grantedRenown.joinToString(", ") { traitName(it.name) }.ifEmpty { "None saved" })
            }
            ForsakenSection.Character -> {
                note("Read-only preview · Saved values\nForm bonuses, granted dots, limits and derived totals are not calculated yet. Save file exports the original import unchanged.")
                for ((label, value) in listOf("Name" to c.name, "Player" to c.player, "Chronicle" to c.chronicle, "Concept" to c.concept)) row(label, value.ifEmpty { "Not set" })
                source("Blood", CatalogKind.archetypes, c.blood)
                source("Bone", CatalogKind.archetypes, c.bone)
                source("Auspice", CatalogKind.auspices, c.auspice)
                source("Tribe", CatalogKind.tribes, c.tribe)
                source("Lodge", CatalogKind.lodges, c.lodge)
                if (c.huntersAspect.isNotEmpty()) row("Hunter's Aspect", c.huntersAspect)
                row("Unofficial Content", if (c.showsUnofficialContent) "On" else "Off")
                row("Browse catalog", "Read entries grouped by book", PreviewRowStyle.Catalog)
            }
            ForsakenSection.Form -> {
                row("Saved form", traitName(c.form.name))
                if (c.favoredForm.attributes.isNotEmpty() || c.favoredForm.drawbacks.isNotEmpty()) {
                    sub("Favored Form choices")
                    c.favoredForm.attributes.forEachIndexed { index, attribute -> row("Dot ${2 + 2 * index} raises", attribute?.let(::traitName) ?: "Not chosen") }
                    c.favoredForm.drawbacks.forEachIndexed { index, drawback -> row("Drawback ${index + 1}",
                        "${drawback.form?.name?.let(::traitName) ?: "Form not chosen"} · ${drawback.attribute?.let(::traitName) ?: "Attribute not chosen"}") }
                }
            }
            ForsakenSection.Advantages -> {
                note("Saved base values. Effective Size, Armor, Defense, Speed, Initiative and dice pools are not available in this preview.")
                row("Size in Hishu", c.size.toString())
                row("Entered armor", "${c.armor} general / ${c.ballisticArmor} ballistic")
            }
            ForsakenSection.Attributes -> {
                note("Saved base dots · Bonuses are not included")
                for (category in TraitCategory.entries) {
                    sub(category.title)
                    attributeDefinitions.filter { it.category == category }.forEach { definition ->
                        c.attributes.filter { it.attribute == definition.id }.forEach { row(definition.name, style = PreviewRowStyle.Rating, rating = it.rating) }
                    }
                }
                c.attributes.filter { a -> attributeDefinitions.none { it.id == a.attribute } }.forEach { row(traitName(it.attribute), style = PreviewRowStyle.Rating, rating = it.rating) }
            }
            ForsakenSection.Skills -> {
                note("Saved base dots and Specialties · Totem grants are listed under Totem")
                for (category in TraitCategory.entries) {
                    sub(category.title)
                    modernSkillDefinitions.filter { it.category == category }.forEach { definition ->
                        c.skills.filter { it.skill == definition.id }.forEach { row(definition.name, it.specialties.joinToString(", "), PreviewRowStyle.Rating, it.rating) }
                    }
                }
                c.skills.filter { s -> modernSkillDefinitions.none { it.id == s.skill } }.forEach { row(traitName(it.skill), it.specialties.joinToString(", "), PreviewRowStyle.Rating, it.rating) }
            }
            ForsakenSection.Merits -> {
                note("Saved owned dots · Granted dots are listed under Totem")
                if (c.merits.isEmpty()) empty()
                c.merits.forEach { merit ->
                    row(catalog.name(CatalogKind.merits, merit.source) + (merit.qualifier?.let { " ($it)" } ?: ""),
                        style = PreviewRowStyle.Rating, rating = merit.rating, reference = merit.source.catalog?.let { "merits/$it" })
                }
            }
            ForsakenSection.Totem -> {
                row("Name", c.totem.name.ifEmpty { "Not set" })
                row("Aspiration", c.totem.aspiration.ifEmpty { "Not set" })
                row("Ban", c.totem.ban.ifEmpty { "Not set" })
                row("Pack points", c.totem.packPoints.toString())
                sub("Saved advantages")
                if (c.totem.advantages.isEmpty()) empty()
                c.totem.advantages.forEach { advantage ->
                    val target = if (advantage.kind == TotemKind.merit) catalog.entry(CatalogKind.merits, advantage.target)?.name ?: advantage.target else traitName(advantage.target)
                    row(target + advantage.detail.takeIf(String::isNotEmpty)?.let { " ($it)" }.orEmpty(),
                        "${traitName(advantage.kind.name)} · ${advantage.dots} saved ${if (advantage.dots == 1) "dot" else "dots"}",
                        reference = if (advantage.kind == TotemKind.merit) "merits/${advantage.target}" else null)
                }
            }
            ForsakenSection.Renown -> {
                Renown.entries.forEach { row(traitName(it.name), style = PreviewRowStyle.Rating, rating = c.renown[it.name] ?: 0) }
                if (c.renownFacetCredits.isNotEmpty()) {
                    sub("Saved free Facets")
                    c.renownFacetCredits.forEach { (renown, credits) -> row(traitName(renown), credits.toString()) }
                }
            }
            ForsakenSection.AuspiceBenefit -> {
                val entry = catalog.entry(CatalogKind.auspices, c.auspice.catalog)
                entry?.objectValue("benefit")?.let { row(it.getValue("name").jsonPrimitive.content,
                    it.getValue("summary").jsonPrimitive.content, reference = "auspices/${entry.id}") }
            }
            ForsakenSection.Lodge -> {
                source("Lodge", CatalogKind.lodges, c.lodge)
                val entry = catalog.entry(CatalogKind.lodges, c.lodge.catalog)
                listOf("benefit", "blessing", "aspiration", "ban", "tools").forEach { key -> entry?.text(key)?.let { row(traitName(key), it) } }
            }
            ForsakenSection.MoonGifts -> {
                val auspice = catalog.entry(CatalogKind.auspices, c.auspice.catalog)
                val source = c.moonGift ?: auspice?.text("moonGift")?.let { TraitSource(catalog = it) }
                if (source == null) empty() else source("Moon Gift", CatalogKind.gifts, source)
                note("The auspice's unlocked Facets are not calculated in this preview. Open its Gift to read all its Facets.")
                c.moonFacets.forEachIndexed { index, name -> row("Custom Facet ${index + 1}", name.ifEmpty { "Not named" }) }
                c.extraMoonGifts.forEach { gift ->
                    row(catalog.name(CatalogKind.gifts, gift.source), "Additional Moon Gift · Saved dots", PreviewRowStyle.Rating,
                        gift.dots, gift.source.catalog?.let { "gifts/$it" })
                    gift.facets.forEachIndexed { index, name -> row("Custom Facet ${index + 1}", name.ifEmpty { "Not named" }) }
                }
            }
            ForsakenSection.ShadowGifts, ForsakenSection.WolfGifts -> {
                val kind = if (section == ForsakenSection.WolfGifts) GiftKind.wolf else GiftKind.shadow
                val owned = c.facets.filter { (catalog.facet(it.source.catalog)?.gift?.text("kind") ?: it.customKind.name) == kind.name }
                if (owned.isEmpty()) empty()
                owned.groupBy { catalog.facet(it.source.catalog)?.gift?.id ?: "custom/${it.customGift}" }.values.forEach { group ->
                    val first = group.first()
                    sub(catalog.facet(first.source.catalog)?.gift?.name ?: first.customGift.ifEmpty { "Custom Gift" })
                    group.forEach { facet ->
                        val entry = catalog.facet(facet.source.catalog)?.facet
                        val notes = listOfNotNull(fact(entry, listOf("renown", "cost", "action", "duration")).takeIf(String::isNotEmpty),
                            entry?.text("dicePool"), if (facet.active) "Active (saved)" else null,
                            if (entry?.flag("passive") == true) "Passive" else null, if (facet.withRenown) "Learned with Renown" else null)
                        row(entry?.name ?: facet.source.custom ?: facet.source.catalog.orEmpty(), notes.joinToString("\n"),
                            reference = facet.source.catalog?.let { "facet/$it" })
                    }
                }
            }
            ForsakenSection.Rites -> {
                if (c.rites.isEmpty()) empty()
                c.rites.forEach { rite ->
                    val entry = catalog.entry(CatalogKind.rites, rite.source.catalog)
                    row(catalog.name(CatalogKind.rites, rite.source), listOfNotNull(
                        fact(entry, listOf("cost", "action", "duration")).takeIf(String::isNotEmpty), entry?.text("dicePool"),
                        if (rite.active) "Active (saved)" else null).joinToString("\n"), PreviewRowStyle.Rating,
                        entry?.number("rating") ?: rite.customRating, rite.source.catalog?.let { "rites/$it" })
                }
            }
            ForsakenSection.Fetishes -> {
                if (c.fetishes.isEmpty()) empty()
                c.fetishes.forEach { fetish -> row(catalog.name(CatalogKind.fetishes, fetish.source), fetish.note,
                    PreviewRowStyle.Rating, catalog.entry(CatalogKind.fetishes, fetish.source.catalog)?.number("rating") ?: fetish.customRating,
                    fetish.source.catalog?.let { "fetishes/$it" }) }
            }
            ForsakenSection.Aspirations -> {
                if (c.aspirations.isEmpty()) empty()
                c.aspirations.forEachIndexed { index, aspiration -> row("Aspiration ${index + 1}", aspiration.text.ifEmpty { "Not set" }) }
            }
            ForsakenSection.Health -> { note("Saved boxes · Current Health capacity is not calculated"); row("Saved Health", style = PreviewRowStyle.Health) }
            ForsakenSection.Willpower -> { note("Saved boxes · Current Willpower capacity is not calculated"); row("Saved Willpower", style = PreviewRowStyle.Willpower) }
            ForsakenSection.PrimalUrge -> {
                row("Primal Urge", style = PreviewRowStyle.Rating, rating = c.primalUrge)
                row("Essence in the pool", c.essence.toString())
            }
            ForsakenSection.Harmony -> {
                row("Harmony", c.harmony.toString())
                row("Flesh Touchstone", c.fleshTouchstone.ifEmpty { "Not set" })
                row("Spirit Touchstone", c.spiritTouchstone.ifEmpty { "Not set" })
            }
            ForsakenSection.Kuruth -> {
                source("Trigger set", CatalogKind.kuruthTriggers, c.kuruthTriggerSet)
                val entry = catalog.entry(CatalogKind.kuruthTriggers, c.kuruthTriggerSet.catalog)
                for ((kind, text) in listOf("passive" to c.kuruthTriggers.passive, "common" to c.kuruthTriggers.common, "specific" to c.kuruthTriggers.specific))
                    row(traitName(kind), (entry?.text(kind) ?: text).ifEmpty { "Not set" })
            }
            ForsakenSection.Experience -> {
                row("Beats", c.beats.toString())
                row("Recorded Experiences", c.experiences.toString())
                row("XP Mode", if (c.xpMode) "On" else "Off")
                note("Available Experiences and refunds are not calculated in this preview.")
                sub("Change log")
                if (c.changeLog.isEmpty()) empty()
                c.changeLog.forEach { change -> row(change.name, buildList {
                    add("${change.from} → ${change.to} · ${change.experiences} Experiences")
                    add(if (change.duringCreation == true) "During creation" else if (change.xpMode) "XP Mode on" else "XP Mode off")
                    change.event?.let { add(traitName(it.name)) }; change.beats?.let { add("$it ${if (it == 1) "Beat" else "Beats"}") }
                }.joinToString("\n"), date = change.date) }
                if (c.paidDots.isNotEmpty()) {
                    sub("Recorded purchases")
                    c.paidDots.forEach { (key, dots) ->
                        val name = c.changeLog.lastOrNull { it.trait == key }?.name ?: traitName(key.substringAfter(':'))
                        row(name, dots.entries.sortedBy { it.key }.joinToString("\n") { "Dot ${it.key} · ${it.value} Experiences paid" })
                    }
                }
            }
            ForsakenSection.Conditions -> {
                if (c.conditions.isEmpty()) empty()
                c.conditions.forEach { condition ->
                    val entry = catalog.entry(CatalogKind.conditions, condition.source.catalog)
                    row(catalog.name(CatalogKind.conditions, condition.source), buildList {
                        if (condition.note.isNotEmpty()) add(condition.note)
                        if (condition.counter != 0) add("Counter ${condition.counter}")
                        add(entry?.summary ?: condition.customEffect)
                        entry?.noteOptions?.firstOrNull { it.name.equals(condition.note, ignoreCase = true) }?.let { add(it.summary) }
                        if (entry?.flag("persistent") ?: condition.customPersistent) add("Persistent")
                        (entry?.text("resolution") ?: condition.customResolution).takeIf(String::isNotEmpty)?.let { add("Resolution\n$it") }
                        (entry?.text("beat") ?: condition.customBeat).takeIf(String::isNotEmpty)?.let { add("Beat\n$it") }
                    }.filter(String::isNotEmpty).joinToString("\n"), reference = condition.source.catalog?.let { "conditions/$it" }, date = condition.addedAt)
                }
            }
        }
    }
}
