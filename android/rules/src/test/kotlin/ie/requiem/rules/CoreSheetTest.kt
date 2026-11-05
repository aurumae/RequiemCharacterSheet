package ie.requiem.rules

import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class CoreSheetTest {
    private val catalog = Catalog.bundled()
    private val codec = CharacterCodec(catalog)

    @Test fun coreAdvancementMatchesSwiftIncludingRenamesAndFreeLosses() {
        val steps = Json.parseToJsonElement(javaClass.getResource("/core-advancement.json")!!.readText()).jsonArray
        var c = CharacterSave()
        val costs = mutableListOf<Int>()
        for (element in steps) {
            val step = element.jsonObject
            val kind = step.getValue("kind").jsonPrimitive.content
            val id = step.getValue("id").jsonPrimitive.content
            c = c.edit(SheetEdit.XpMode(step.getValue("xpMode").jsonPrimitive.boolean), catalog)
            val action = when (kind) {
                "attribute" -> SheetEdit.AttributeRating(id, step.getValue("rating").jsonPrimitive.int)
                "skill" -> SheetEdit.SkillRating(id, step.getValue("rating").jsonPrimitive.int)
                else -> {
                    val old = c.skills.first { it.skill == id }.specialties
                    val target = step.getValue("specialties").jsonArray.map { it.jsonPrimitive.content }
                    when {
                        target.size > old.size -> SheetEdit.AddSpecialty(id, target.last())
                        target.size < old.size -> SheetEdit.ReplaceSpecialty(id, old.lastIndex, old.last(), "")
                        else -> SheetEdit.ReplaceSpecialty(id, 0, old[0], target[0])
                    }
                }
            }
            c = codec.decode(codec.encode(c.edit(action, catalog, 800_000_123.125)))
            if (step["cost"] != JsonNull) costs += step.getValue("cost").jsonPrimitive.int
            assertEquals(costs, c.changeLog.map { it.experiences })
            assertEquals(step.getValue("available").jsonPrimitive.int, c.experiencesAvailable)
            assertEquals(step.getValue("paidLevels").jsonArray.map { it.jsonPrimitive.int }, c.paidDots["$kind:$id"].orEmpty().keys.sorted())
            if (kind == "specialty") assertEquals(step.getValue("specialties").jsonArray.map { it.jsonPrimitive.content }, c.skills.first { it.skill == id }.specialties)
        }
    }

    @Test fun allCoreRatingsEnforceCapsAndRepeatedAbsoluteEditsAreFreeOfSideEffects() {
        for (potency in listOf(1, 5, 6, 10, 11)) {
            val start = CharacterSave(bloodPotency = potency, xpMode = true)
            for (definition in attributeDefinitions) {
                val c = start.edit(SheetEdit.AttributeRating(definition.id, 99), catalog)
                assertEquals(potency.coerceIn(5, 10), c.attributes.first { it.attribute == definition.id }.rating)
                assertSame(c, c.edit(SheetEdit.AttributeRating(definition.id, 99), catalog))
                assertEquals(1, c.edit(SheetEdit.AttributeRating(definition.id, -1), catalog).attributes.first { it.attribute == definition.id }.rating)
            }
            for (definition in skillDefinitions) {
                val c = start.edit(SheetEdit.SkillRating(definition.id, 99), catalog)
                assertEquals(potency.coerceIn(5, 10), c.skills.first { it.skill == definition.id }.rating)
                assertSame(c, c.edit(SheetEdit.SkillRating(definition.id, 99), catalog))
                assertEquals(0, c.edit(SheetEdit.SkillRating(definition.id, -1), catalog).skills.first { it.skill == definition.id }.rating)
            }
        }
    }

    @Test fun attributeBonusesDoNotIncludeDicePoolOnlyBonuses() {
        val c = CharacterSave(disciplines = listOf(Discipline(TraitSource(catalog = "vigor"), 2),
            Discipline(TraitSource(catalog = "resilience"), 3), Discipline(TraitSource(catalog = "praestantia"), 4)))
        assertEquals(2, c.attributeBonus("strength", catalog))
        assertEquals(3, c.attributeBonus("stamina", catalog))
        assertEquals(0, c.attributeBonus("dexterity", catalog))
        assertEquals(9, c.health(catalog))
    }

    @Test fun changingAttributesTrimsSpentMarksBeforeTheNextWrite() {
        val c = CharacterSave(willpowerTrack = List(4) { WillpowerMark.spent })
            .edit(SheetEdit.AttributeRating("resolve", 3), catalog)
        val lowered = c.edit(SheetEdit.AttributeRating("resolve", 1), catalog)
        val raised = lowered.edit(SheetEdit.AttributeRating("resolve", 3), catalog)
        assertEquals(listOf(WillpowerMark.spent, WillpowerMark.spent, WillpowerMark.none, WillpowerMark.none),
            codec.decode(codec.encode(raised)).willpowerTrack)
    }

    @Test fun identityLinksKnownNamesKeepsCustomTextAndAppliesClanBaneThreshold() {
        assertFalse(CharacterSave(humanity = 7).edit(SheetEdit.Detail(CharacterDetail.Clan, "Ventrue"), catalog).clanBaneActive)
        var c = CharacterSave(humanity = 6)
        c = c.edit(SheetEdit.Detail(CharacterDetail.Clan, "ventrue"), catalog)
        assertEquals("ventrue", c.clan.catalog)
        assertTrue(c.clanBaneActive)
        c = c.edit(SheetEdit.Detail(CharacterDetail.Covenant, "THE CARTHIAN MOVEMENT"), catalog)
        assertNotNull(c.covenant.catalog)
        c = c.edit(SheetEdit.Detail(CharacterDetail.Covenant, "Our custom covenant"), catalog)
        assertEquals("Our custom covenant", c.covenant.custom)
        assertTrue(c.changeLog.isEmpty())
        val unknown = c.copy(clan = TraitSource(catalog = "future-clan"))
        assertEquals(unknown.clan, unknown.edit(SheetEdit.Detail(CharacterDetail.Player, "Sam"), catalog).clan)
    }

    @Test fun blankSpecialtiesStaleEditsAndGuidedActionsAreIgnored() {
        val c = CharacterSave()
        assertSame(c, c.edit(SheetEdit.AddSpecialty("occult", " \n "), catalog))
        val added = c.edit(SheetEdit.AddSpecialty("occult", " Ghosts "), catalog)
        assertEquals(listOf("Ghosts"), added.skills.first { it.skill == "occult" }.specialties)
        assertSame(added, added.edit(SheetEdit.ReplaceSpecialty("occult", 0, "Old text", "Replacement"), catalog))
        val guided = c.copy(creation = CreationState())
        listOf(SheetEdit.AttributeRating("strength", 4), SheetEdit.SkillRating("occult", 3),
            SheetEdit.AddSpecialty("occult", "Ghosts"), SheetEdit.Detail(CharacterDetail.Clan, "Ventrue"))
            .forEach { assertSame(guided, guided.edit(it, catalog)) }
    }
}
