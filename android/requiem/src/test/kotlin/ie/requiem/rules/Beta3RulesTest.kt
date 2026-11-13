package ie.requiem.rules

import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class Beta3RulesTest {
    private val catalog = Catalog.bundled()
    private val codec = CharacterCodec(catalog)
    private fun source(id: String) = TraitSource(catalog = id)
    private fun entry(kind: CatalogKind, id: String) = requireNotNull(catalog.entry(kind, id))
    private fun CharacterSave.status(id: String, dots: Int = 1) = copy(covenant = source(id),
        merits = listOf(Merit(source("covenant-status"), rating = dots, qualifier = catalog.name(CatalogKind.covenants, source(id)))))
    private fun CharacterSave.checks(id: String) = prerequisites(entry(CatalogKind.merits, id), catalog)
    private fun encoded(c: CharacterSave) = Json.parseToJsonElement(codec.encode(c)).jsonObject

    @Test fun elderBanesActivateOnCrossingAndResetOnlyWhenClanChanges() {
        var c = CharacterSave(clan = source("daeva"), humanity = 4)
        assertEquals("The Captivating Curse", c.elderBane(catalog)?.name)
        c = c.edit(SheetEdit.Number(NumberField.Humanity, 3), catalog)
        assertTrue(c.elderBaneActive)
        c = c.edit(SheetEdit.Number(NumberField.Humanity, 5), catalog)
        assertTrue(c.elderBaneActive)
        c = c.edit(SheetEdit.ElderBane(false), catalog).edit(SheetEdit.Number(NumberField.Humanity, 3), catalog)
        assertTrue(c.elderBaneActive)
        c = c.edit(SheetEdit.ElderBane(false), catalog).edit(SheetEdit.Number(NumberField.Humanity, 2), catalog)
        assertFalse(c.elderBaneActive)
        assertFalse(c.edit(SheetEdit.Detail(CharacterDetail.Clan, "Daeva"), catalog).elderBaneActive)
        c = c.edit(SheetEdit.Detail(CharacterDetail.Clan, "Gangrel"), catalog)
        assertTrue(c.elderBaneActive)
        assertEquals("The Visceral Curse", c.elderBane(catalog)?.name)
        c = c.edit(SheetEdit.Detail(CharacterDetail.Clan, "Custom clan"), catalog)
        assertFalse(c.elderBaneActive); assertNull(c.elderBane(catalog))
        assertTrue(c.banes.isEmpty())
    }

    @Test fun conditionalWritersAndAbsentElderStateNeverInferAChange() {
        val plain = CharacterSave(clan = source("daeva"), humanity = 2)
        val conditions = plain.edit(SheetEdit.AddCondition(source("charmed")), catalog)
        val history = conditions.edit(SheetEdit.ConditionAction(conditions.conditions.single().id, ConditionEvent.ended), catalog)
        for (c in listOf(plain, conditions, history)) {
            val expected = if (c === plain) 10 else 11
            assertEquals(expected, encoded(c).getValue("schemaVersion").jsonPrimitive.int)
            assertFalse("elderBaneActive" in encoded(c))
            assertFalse(codec.decode(codec.encode(c)).elderBaneActive)
            val elder = c.edit(SheetEdit.ElderBane(true), catalog)
            assertEquals(12, encoded(elder).getValue("schemaVersion").jsonPrimitive.int)
            assertTrue(codec.decode(codec.encode(elder)).elderBaneActive)
            assertEquals(expected, encoded(elder.edit(SheetEdit.ElderBane(false), catalog)).getValue("schemaVersion").jsonPrimitive.int)
        }
    }

    @Test fun quintessenceUsesVoivodePricingAndRefundsHistoricalPrices() {
        val coil = Coil(source("coil-of-the-quintessence"))
        var c = CharacterSave(xpMode = true, experiences = 30, mystery = source("mystery-of-the-voivode"), coils = listOf(coil))
        assertNull(c.coilWarning(coil.copy(rating = 3), catalog))
        c = c.edit(SheetEdit.EntryRating(EntryKind.Coil, coil.id, 1), catalog)
        c = c.copy(mystery = source("mystery-of-the-wyrm")).edit(SheetEdit.EntryRating(EntryKind.Coil, coil.id, 2), catalog)
        assertEquals(listOf(3, 4), c.changeLog.map { it.experiences })
        assertNotNull(c.coilWarning(c.coils.single(), catalog))
        c = c.edit(SheetEdit.EntryRating(EntryKind.Coil, coil.id, 0), catalog)
        assertEquals(-7, c.changeLog.last().experiences); assertEquals(30, c.experiencesAvailable)
    }

    @Test fun statusChoicesAliasesAndMeritOverridesAreScopedToTheirEntries() {
        val status = entry(CatalogKind.merits, "covenant-status")
        assertEquals(catalog.names(CatalogKind.covenants).sorted(), CharacterSave().qualifierChoices(status, catalog)!!.sorted())
        val legion = CharacterSave().status("legion-of-the-green", 2)
        assertEquals(2, legion.covenantStatus("invictus", catalog))
        assertTrue(legion.belongsToCovenant("invictus", catalog))
        assertTrue(legion.checks("attache").all { it.met == true })
        assertTrue(legion.checks("attache").single().description.contains("Legion of the Green"))
        assertEquals(0, legion.copy(covenant = source("carthian-movement")).covenantStatus("invictus", catalog))
        val gallows = CharacterSave().status("gallows-post")
        assertTrue(gallows.checks("breaking-the-chains").all { it.met == true })
        assertFalse(gallows.checks("cease-fire").single().met!!)
        assertFalse(gallows.checks("carthian-pull").single().met!!)
        val firawn = CharacterSave().status("firawn")
        assertTrue(firawn.checks("altar").single().met!!)
        assertFalse(firawn.checks("mother-daughter-bond").single().met!!)
    }

    @Test fun clanAndBloodlineMeritAccessDoesNotWaiveUnrelatedRequirements() {
        val dukhan = CharacterSave(clan = source("dukhan"))
        assertTrue(dukhan.checks("dream-visions").single().met!!)
        assertFalse(dukhan.checks("kiss-of-the-succubus").single().met!!)
        val icelus = CharacterSave(clan = source("ventrue"), bloodline = source("icelus"))
        assertTrue(icelus.checks("dream-visions").single().met!!)
        assertTrue(icelus.checks("psychognosis").first().met!!)
        assertTrue(icelus.checks("psychognosis").any { it.met == null && it.description.contains("Psychology") })
        assertFalse(dukhan.checks("psychognosis").first().met!!)
    }

    @Test fun bronCreationReplacesChoicesAndOnlyMovesInvalidFreeDots() {
        var c = CharacterSave(clan = source("ventrue"), creation = CreationState())
            .edit(SheetEdit.FavoredAttribute("resolve"), catalog)
        assertEquals(2, c.attributeRating("resolve"))
        c = c.edit(SheetEdit.Detail(CharacterDetail.Bloodline, "Bron"), catalog)
        assertEquals(listOf("stamina", "presence"), c.favoredAttributes(catalog))
        assertEquals("Bron", c.favoredAttributeGiver(catalog)?.name)
        assertEquals(1, c.attributeRating("resolve")); assertTrue(c.needsFavoredAttribute(catalog))
        c = c.edit(SheetEdit.FavoredAttribute("presence"), catalog).edit(SheetEdit.Detail(CharacterDetail.Bloodline, ""), catalog)
        assertEquals("presence", c.creation?.favoredAttribute)
        val playing = c.copy(creation = null)
        assertEquals(playing.attributes, playing.edit(SheetEdit.Detail(CharacterDetail.Bloodline, "Bron"), catalog).attributes)
        val bron = playing.copy(bloodline = source("bron"))
        assertTrue(bron.favoredAttributesText(catalog).contains("Bron"))
        assertTrue(bron.favoredAttributesText(catalog).contains("Ventrue"))
    }

    @Test fun bloodlinesOfAnyClanAndCovenantAdviceKeepCorrectGroups() {
        val c = CharacterSave(clan = source("ventrue"), covenant = source("circles-of-mor"))
        val options = c.identityOptions(CharacterDetail.Bloodline, catalog)
        val any = options.first { it.entry.id == "penumbrae" }
        assertTrue(any.details.contains("Parent clan: Any clan")); assertNull(any.warning)
        assertFalse(any.group == "Other Bloodlines")
        val warning = c.copy(covenant = source("invictus")).identityOptions(CharacterDetail.Bloodline, catalog).first { it.entry.id == "penumbrae" }
        assertTrue(warning.warning!!.contains("Circle of the Crone"))
        assertEquals(any.group, warning.group)
    }

    @Test fun ritualTeachersAliasesMembershipAndHumanityMatchTheSourceRules() {
        for ((discipline, covenant) in listOf("kimiya" to "jaliniyya", "theban-sorcery" to "ahl-al-mumit", "cruac" to "firawn", "cruac" to "circles-of-mor", "therion" to "tenth-choir")) {
            val e = entry(CatalogKind.disciplines, discipline)
            assertNull(CharacterSave().status(covenant).ritualLearningWarning(e, catalog))
            assertNotNull(CharacterSave(covenant = source(covenant)).ritualLearningWarning(e, catalog))
        }
        val triadic = entry(CatalogKind.disciplines, "triadic-evolution")
        assertFalse(CharacterSave().hasRitualStatus(triadic, catalog))
        assertTrue(CharacterSave(covenant = source("belials-brood")).hasRitualStatus(triadic, catalog))
        val guided = CharacterSave(creation = CreationState(), disciplines = listOf(Discipline(triadic.source(), rating = 1)))
        assertTrue(guided.creationReport(catalog).problems.any { it.description == "Triadic Evolution needs membership of Belial's Brood" })
        val c = CharacterSave(disciplines = listOf(Discipline(source("kimiya"), rating = 5), Discipline(source("therion"), rating = 5)))
        assertNull(c.humanityCap(catalog))
        assertEquals("No limit on Humanity.", c.bookDetail(entry(CatalogKind.disciplines, "kimiya"), catalog).facts.single { it.label == "Humanity" }.value)
        assertTrue(c.bookDetail(entry(CatalogKind.disciplines, "therion"), catalog).facts.single { it.label == "Humanity" }.value.contains("breaking point"))
    }

    @Test fun anyCoilScalesAndZeroCostDevotionsPreservePurchaseHistory() {
        val scale = entry(CatalogKind.scales, "spirit-tether")
        assertEquals(2, CharacterSave().scaleCost(scale))
        assertEquals(2, CharacterSave(coils = listOf(Coil(TraitSource(custom = "Homebrew"), rating = 1))).scaleCost(scale))
        assertEquals(1, CharacterSave(coils = listOf(Coil(TraitSource(custom = "Homebrew"), rating = 2))).scaleCost(scale))
        assertEquals("Any Coil ••", scale.scalePrerequisiteText(catalog))
        assertEquals("Any Mystery", CharacterSave().catalogOptions(EntryKind.Scale, catalog).single { it.entry.id == scale.id }.group)
        var c = CharacterSave(xpMode = true, experiences = 10)
        for (id in listOf("infectious-bite", "city-attunement")) {
            c = c.edit(SheetEdit.AddEntry(EntryKind.Devotion, source(id)), catalog)
            assertEquals(10, c.experiencesAvailable)
            c = c.edit(SheetEdit.RemoveEntry(EntryKind.Devotion, c.devotions.single().id), catalog)
            assertEquals(10, c.experiencesAvailable)
        }
        assertTrue(c.changeLog.all { it.experiences == 0 })
    }

    @Test fun requiredQualifiersAndBookSectionsRemainValidUnderSearch() {
        val c = CharacterSave(clan = source("ventrue"), bloodline = source("bron"))
        val language = entry(CatalogKind.merits, "language")
        assertFalse(c.validQualifier(language, "  ", catalog))
        assertEquals(c, c.edit(SheetEdit.AddEntry(EntryKind.Merit, language.source(), "  "), catalog))
        for (kind in EntryKind.entries) {
            val sections = c.catalogSections(kind, catalog)
            val books = sections.mapNotNull { it.book }
            assertEquals(catalog.books.values.filter { it in books }, books)
            assertEquals(catalog.entries(kind.catalogKind).keys, sections.flatMap { it.entries }.map { it.entry.id }.toSet())
            assertEquals(sections.size, sections.map { it.id }.distinct().size)
        }
        val sections = c.catalogSections(EntryKind.Discipline, catalog, "Crochan")
        assertEquals(2, sections.size)
        assertEquals("in-clan", sections.first().id)
        assertEquals(sections.first().entries.single().entry.id, sections.last().entries.single().entry.id)
        for (n in listOf(-1, 0, 1, 2)) assertEquals("$n ${if (n == 1) "Experience" else "Experiences"}", experiencesText(n))
    }
}
