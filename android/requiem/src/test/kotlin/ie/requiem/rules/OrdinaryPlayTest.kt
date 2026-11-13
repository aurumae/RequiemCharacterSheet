package ie.requiem.rules

import java.io.File
import java.util.UUID
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class OrdinaryPlayTest {
    private val catalog = Catalog.bundled()
    private val codec = CharacterCodec(catalog)
    private fun book(kind: CatalogKind, id: String) = requireNotNull(catalog.entry(kind, id))
    private fun add(kind: EntryKind, id: String, qualifier: String? = null) = SheetEdit.AddEntry(kind, TraitSource(catalog = id), qualifier)
    private fun id(row: Int) = UUID.fromString("10000000-0000-0000-0000-${row.toString().padStart(12, '0')}")

    @Test fun sharedPlaySequenceMatchesSwiftPricesRefundsAndRoundTrips() {
        val steps = Json.parseToJsonElement(javaClass.getResource("/ordinary-play.json")!!.readText()).jsonArray
        var c = CharacterSave()
        val expected = mutableListOf<Int>()
        for ((index, element) in steps.withIndex()) {
            val s = element.jsonObject
            val kind = s.str("kind")?.let(EntryKind::valueOf)
            val row = id(s.int("row"))
            val action: SheetEdit = when (s.str("action")) {
                "clan" -> SheetEdit.Detail(CharacterDetail.Clan, s.str("text")!!)
                "xp" -> SheetEdit.XpMode(s.flag("enabled"))
                "add" -> SheetEdit.AddEntry(kind!!, TraitSource(catalog = s.str("source")!!), id = row)
                "remove" -> SheetEdit.RemoveEntry(kind!!, row)
                "rate" -> SheetEdit.EntryRating(kind!!, row, s.int("rating"))
                "healthMark" -> SheetEdit.Mark(s.int("index"))
                "mystery" -> SheetEdit.Mystery(TraitSource(catalog = s.str("source")!!), coilId = row)
                "number" -> SheetEdit.Number(NumberField.valueOf(s.str("field")!!), s.int("value"))
                "customDevotion" -> SheetEdit.AddEntry(EntryKind.Devotion, TraitSource(custom = s.str("text")!!), devotionCost = s.int("value"), id = row)
                "devotionCost" -> SheetEdit.CustomDevotionCost(row, s.int("value"))
                "rename" -> SheetEdit.RenameEntry(kind!!, row, s.str("text")!!)
                else -> error("Unknown action")
            }
            c = codec.decode(codec.encode(c.edit(action, catalog, 800_000_000.25 + index)))
            expected += s.ints("costs")
            assertEquals("Step $index", expected, c.changeLog.map { it.experiences })
            assertEquals("Step $index", s.int("available"), c.experiencesAvailable)
            s.str("health")?.let { assertEquals(it.toInt(), c.health(catalog)) }
        }
        assertEquals(-31, c.experiencesAvailable)
        assertTrue(c.healthTrack.all { it == Damage.none })
        assertEquals(2, c.coils.single().rating)
        assertEquals(mapOf(1 to 1), c.paidDots["scale:${id(12).swiftKey()}"])
        assertEquals(mapOf(1 to 0), c.paidDots["ritual:${id(9).swiftKey()}"])
        assertFalse(c.paidDots.containsKey("discipline:${id(1).swiftKey()}"))
        ContractFixtures.exchange("ordinary-play.json")?.let {
            val swift = codec.decode(File(it, "swift-ordinary-play.json").readText())
            assertEquals(c.experiencesAvailable, swift.experiencesAvailable)
            assertEquals(c.changeLog.map { change -> change.experiences }, swift.changeLog.map { change -> change.experiences })
            assertEquals(c.rituals.map { ritual -> ritual.source }, swift.rituals.map { ritual -> ritual.source })
            assertEquals(c.coils.map { coil -> coil.rating }, swift.coils.map { coil -> coil.rating })
            File(it, "kotlin-ordinary-play.json").writeText(codec.encode(c))
        }
    }

    @Test fun bloodPotencyLossClampsBaseDotsAndVitaeButDoesNotRefundBloodPotency() {
        var c = CharacterSave().edit(SheetEdit.Number(NumberField.BloodPotency, 6), catalog)
            .edit(SheetEdit.AttributeRating("strength", 6), catalog).edit(SheetEdit.SkillRating("athletics", 6), catalog)
            .edit(SheetEdit.XpMode(true), catalog).edit(SheetEdit.Number(NumberField.BloodPotency, 7), catalog)
            .edit(SheetEdit.AttributeRating("strength", 7), catalog).edit(SheetEdit.SkillRating("athletics", 7), catalog)
            .edit(SheetEdit.Number(NumberField.Vitae, 25), catalog)
        assertEquals(-11, c.experiencesAvailable)
        c = c.edit(SheetEdit.Number(NumberField.BloodPotency, 1), catalog)
        assertEquals(listOf(-4, -2, 0), c.changeLog.takeLast(3).map { it.experiences })
        assertEquals(listOf("attribute:strength", "skill:athletics", "bloodPotency:bloodPotency"), c.changeLog.takeLast(3).map { it.trait })
        assertEquals(-5, c.experiencesAvailable)
        assertEquals(5, c.attributeRating("strength")); assertEquals(5, c.skillRating("athletics")); assertEquals(10, c.currentVitae)
    }

    @Test fun choicesKeepMeritGapsDuplicatesRepeatabilityAndBaneLimits() {
        val iron = add(EntryKind.Merit, "iron-skin")
        var c = CharacterSave(xpMode = true).edit(iron, catalog)
        assertSame(c, c.edit(iron, catalog)); assertSame(c, c.edit(add(EntryKind.Merit, "iron-skin"), catalog))
        assertEquals(listOf(0, 2, 4), c.entryRows(EntryKind.Merit, catalog).single().choices)
        c = c.edit(SheetEdit.EntryRating(EntryKind.Merit, iron.id, 3), catalog)
        assertEquals(4, c.merits.single().rating)
        c = c.edit(add(EntryKind.Merit, "language", "French"), catalog).edit(add(EntryKind.Merit, "language", "Irish"), catalog)
        assertEquals(3, c.merits.size)
        repeat(3) { c = c.edit(SheetEdit.AddEntry(EntryKind.Bane, TraitSource(custom = "Bane $it")), catalog) }
        assertSame(c, c.edit(SheetEdit.AddEntry(EntryKind.Bane, TraitSource(custom = "Fourth")), catalog))
        c = c.edit(SheetEdit.RemoveEntry(EntryKind.Bane, c.banes.first().id), catalog).edit(SheetEdit.AddEntry(EntryKind.Bane, TraitSource(custom = "Replacement")), catalog)
        assertEquals(3, c.banes.size)
    }

    @Test fun prerequisitesWarnWithoutBlockingOrdinaryPlay() {
        var c = CharacterSave()
        val fast = book(CatalogKind.merits, "fast-reflexes")
        assertEquals("Requires One of: Wits 3, or Dexterity 3", c.prerequisites(fast, catalog).warningText())
        c = c.edit(add(EntryKind.Merit, "fast-reflexes"), catalog)
        assertEquals(1, c.merits.size)
        c = c.edit(SheetEdit.AttributeRating("dexterity", 3), catalog)
        assertTrue(c.prerequisites(fast, catalog).all { it.met != false })
        assertTrue(c.prerequisites(book(CatalogKind.merits, "anonymity"), catalog).any { it.met == null })
        val attache = book(CatalogKind.merits, "attache")
        assertTrue(c.prerequisites(attache, catalog).contains(PrerequisiteCheck("Invictus Status 1", false)))
        c = c.edit(add(EntryKind.Merit, "covenant-status", "Invictus"), catalog)
        assertTrue(c.prerequisites(attache, catalog).contains(PrerequisiteCheck("Invictus Status 1", true)))
        val unavailable = catalog.bookEntries(CatalogKind.merits).first { it.raw.flag("unavailableToKindred") }
        assertTrue(c.prerequisites(unavailable, catalog).warningText().contains("Not available to Kindred"))
        assertTrue(c.edit(add(EntryKind.Merit, unavailable.id), catalog).merits.any { it.source.catalog == unavailable.id })
    }

    @Test fun bonusesDistinguishDicePoolsFromDerivedTraitsAndTrimRemovedMarks() {
        var c = CharacterSave(attributes = attributeDefinitions.map { Attribute(it.id, when(it.id) { "dexterity" -> 4; "wits" -> 5; else -> 1 }) },
            disciplines = listOf(Discipline(TraitSource(catalog = "praestantia"), 5)))
        assertEquals(9, c.rollAttribute("dexterity", catalog)); assertEquals(10, c.speed(catalog)); assertEquals(4, c.defense(catalog)); assertEquals(10, c.initiative(catalog))
        assertEquals(8, c.combatPool("firearms", catalog))
        val giant = add(EntryKind.Merit, "giant")
        c = c.edit(giant, catalog).edit(SheetEdit.Mark(6), catalog).edit(SheetEdit.RemoveEntry(EntryKind.Merit, giant.id), catalog)
        c = c.edit(add(EntryKind.Merit, "giant"), catalog)
        assertTrue(codec.decode(codec.encode(c)).healthTrack.all { it == Damage.none })
        c = c.edit(add(EntryKind.Merit, "defensive-combat", "Brawl"), catalog).edit(SheetEdit.SkillRating("brawl", 3), catalog)
        assertEquals(listOf("brawl"), c.alternativeDefenseSkills(catalog)); assertEquals(7, c.defense(catalog, "brawl"))
    }

    @Test fun humanityBaneCrossingAndTouchstonesPreservePlayerChoices() {
        var c = CharacterSave().edit(SheetEdit.Detail(CharacterDetail.Clan, "Mekhet"), catalog)
            .edit(SheetEdit.TouchstoneText(6, "My sister"), catalog)
        c = c.edit(SheetEdit.Number(NumberField.Humanity, 6), catalog)
        assertTrue(c.clanBaneActive); assertTrue(c.clanBane(catalog)!!.extraBane); assertTrue(c.banes.isEmpty())
        c = c.edit(SheetEdit.Number(NumberField.Humanity, 8), catalog)
        assertTrue(c.clanBaneActive)
        c = c.edit(SheetEdit.ClanBane(false), catalog).edit(SheetEdit.Number(NumberField.Humanity, 6), catalog)
        assertTrue(c.clanBaneActive)
        c = c.edit(SheetEdit.ClanBane(false), catalog).edit(SheetEdit.Number(NumberField.Humanity, 5), catalog)
        assertFalse(c.clanBaneActive)
        assertEquals("My sister", codec.decode(codec.encode(c)).touchstones.first { it.level == 6 }.text)
    }

    @Test fun vitaeWillpowerAndBeatsFollowTheirLimitsWithoutRecordingPurchases() {
        var c = CharacterSave()
        assertEquals(listOf(1,10,11,12,13,15,20,25,30,50,75), (0..10).map { c.copy(bloodPotency = it).maxVitae })
        assertEquals(listOf(1,1,2,3,4,5,6,7,8,10,15), (0..10).map { c.copy(bloodPotency = it).vitaePerTurn })
        repeat(5) { c = c.edit(SheetEdit.Counter(NumberField.Beats, 1), catalog) }
        assertEquals(0, c.beats); assertEquals(1, c.experiences)
        c = c.edit(SheetEdit.Willpower(1), catalog).edit(SheetEdit.Number(NumberField.Armor, 300), catalog).edit(SheetEdit.Number(NumberField.Vitae, 300), catalog)
        assertEquals(WillpowerMark.spent, codec.decode(codec.encode(c)).willpowerTrack[1]); assertEquals(99, c.armor); assertEquals(10, c.currentVitae)
        assertTrue(c.changeLog.isEmpty())
        assertSame(c, c.edit(SheetEdit.Willpower(2), catalog))
    }

    @Test fun sorceryWarningsMysteryRenamesAndDiscountsMatchTheSwiftRules() {
        var c = CharacterSave(disciplines = listOf(Discipline(TraitSource(catalog = "cruac"), 3), Discipline(TraitSource(catalog = "theban-sorcery"), 4)))
        assertEquals(7, c.humanityCap(catalog)!!.limit)
        assertEquals(listOf("Casting requires Humanity 4"), c.copy(humanity = 3).ritualWarnings(Ritual(TraitSource(catalog = "stigmata")), catalog))
        assertNotNull(c.ritualLearningWarning(book(CatalogKind.disciplines, "cruac"), catalog))
        c = c.edit(add(EntryKind.Merit, "covenant-status", "Circle of the Crone"), catalog)
        assertNull(c.ritualLearningWarning(book(CatalogKind.disciplines, "cruac"), catalog))
        c = c.edit(SheetEdit.Mystery(TraitSource(custom = "Serpent")), catalog)
        val coil = c.coils.single()
        c = c.edit(SheetEdit.EntryRating(EntryKind.Coil, coil.id, 2), catalog).edit(SheetEdit.Mystery(TraitSource(custom = "Serpents"), rename = true), catalog)
        assertEquals(coil.id, c.coils.single().id); assertEquals(2, c.coils.single().rating); assertTrue(c.isMysteryCoil(c.coils.single(), catalog))
        c = c.edit(SheetEdit.Mystery(TraitSource(catalog = "mystery-of-the-wyrm")), catalog)
        assertEquals(2, c.coils.size); assertNotNull(c.coilWarning(c.coils.last(), catalog))
        assertEquals(2, c.scaleCost(book(CatalogKind.scales, "kindred-sense-endowment")))
        c = c.edit(SheetEdit.EntryRating(EntryKind.Coil, c.coils.first().id, 2), catalog)
        assertEquals(1, c.scaleCost(book(CatalogKind.scales, "kindred-sense-endowment")))
    }

    @Test fun catalogSearchDetailsAndKnownDiceAreAvailableAcrossEveryBook() {
        val c = CharacterSave(clan = TraitSource(catalog = "daeva"), disciplines = listOf(Discipline(TraitSource(catalog = "resilience"), 3), Discipline(TraitSource(catalog = "vigor"), 1)))
        assertTrue(c.catalogOptions(EntryKind.Discipline, catalog).first().group.startsWith("In-clan"))
        assertEquals("Vampire", c.catalogOptions(EntryKind.Merit, catalog).first().group)
        assertTrue(c.catalogOptions(EntryKind.Discipline, catalog, "Cruac").any { it.entry.id == "cruac" })
        for (kind in EntryKind.entries) for (entry in catalog.bookEntries(kind.catalogKind)) {
            val details = c.bookDetail(entry, catalog, 3)
            assertTrue(details.title.isNotBlank()); assertTrue(details.citation.isNotBlank())
        }
        val body = c.bookDetail(book(CatalogKind.devotions, "body-of-will"), catalog)
        assertTrue(body.facts.contains(DetailFact("Your dice", "6")))
        assertTrue(body.facts.contains(DetailFact("Dice pool", "Stamina + Survival + Resilience")))
        val ritual = c.bookDetail(book(CatalogKind.rituals, "rigor-mortis"), catalog)
        assertTrue(ritual.facts.contains(DetailFact("Casting cost", "1 Vitae")))
    }
}
