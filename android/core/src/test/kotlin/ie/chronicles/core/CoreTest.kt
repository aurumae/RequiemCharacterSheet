package ie.chronicles.core

import java.util.UUID
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test

class CoreTest {
    @Test fun catalogPrecedenceFoldingAndUnknownReferencesDoNotDependOnGameData() {
        data class Entry(val id: String, val name: String)
        val index = CatalogIndex(listOf(Entry("first", "The Déjà’s"), Entry("first", "Duplicate"), Entry("other", "Déjà’s")), Entry::id, Entry::name)
        assertEquals(listOf("first", "other"), index.byId.keys.toList())
        assertEquals(TraitSource(catalog = "first"), index.source("DEJA'S"))
        assertEquals(TraitSource(custom = "Déja"), index.source("Déja"))
        assertEquals("removed-entry", index.name(TraitSource(catalog = "removed-entry")))
        val groups = bookSections(linkedMapOf("core" to "Core", "extra" to "Extra"), listOf("extra/a", "core/b", "extra/c"), { it.substringBefore('/') }, { "" })
        assertEquals(listOf("Core", "Extra"), groups.map { it.book })
        assertEquals(listOf("extra/a", "extra/c"), groups.last().entries)
    }
    @Test fun searchFoldsTheKeyboardAndPrintedFormsOfQuotesAndAccents() {
        for (apostrophe in "‘’‚‛′ʼ`´") {
            assertTrue(CatalogSearch(" predator's ").matches("The Predator${apostrophe}s Pursuit"))
            assertTrue(CatalogSearch("predator${apostrophe}s").matches("Predator's"))
        }
        for (quote in "“”„‟″") {
            assertTrue(CatalogSearch("\"RENE\"").matches("${quote}René${quote}"))
        }
        assertTrue(CatalogSearch("  ").matches("Any entry"))
        assertFalse(CatalogSearch("predators").matches("Predator’s"))
    }

    @Test fun sharedSerializationRetainsSavedKeysUuidCaseAndOpenLogKinds() {
        val json = Json { encodeDefaults = true; explicitNulls = false }
        val merit = Merit(TraitSource(catalog = "language"), "Irish", 1, UUID.fromString("abcdefab-cdef-abcd-efab-cdefabcdefab"))
        val encoded = json.encodeToString(merit)
        assertTrue(encoded.contains("ABCDEFAB-CDEF-ABCD-EFAB-CDEFABCDEFAB"))
        assertEquals(merit, json.decodeFromString<Merit>(encoded))
        val log = TraitChange(merit.id, 12.25, "anotherGameTrait:id", "Example", 0, 1, 1, true)
        assertEquals(log, json.decodeFromString<TraitChange>(json.encodeToString(log)))
        assertEquals("{\"catalog\":\"unknown\"}", json.encodeToString(TraitSource(catalog = "unknown")))
        assertThrows(IllegalArgumentException::class.java) { TraitSource(catalog = "id", custom = "name") }
    }
    @Test fun sharedTraitsKeepFirstSavedRecordAndPreserveUnknownSkills() {
        val merged = mergeTraits(listOf(Skill("known"), Skill("default")), listOf(Skill("known", 3), Skill("known", 5), Skill("future", 2)), Skill::skill)
        assertEquals(listOf(Skill("known", 3), Skill("default"), Skill("future", 2)), merged)
        assertEquals(9, attributeDefinitions.size)
        assertEquals(24, modernSkillDefinitions.size)
        assertEquals(listOf(Damage.lethal, Damage.none, Damage.none), listOf(Damage.lethal).visibleTrack(3, Damage.none))
        assertEquals(emptyList<Damage>(), listOf(Damage.lethal).visibleTrack(-1, Damage.none))
        assertEquals(BeatTotal(0, 3), incrementBeat(4, 2))
        assertEquals(BeatTotal(0, Int.MAX_VALUE), incrementBeat(4, Int.MAX_VALUE))
        assertEquals("1 Experience", experiencesText(1))
        assertEquals("3 dots to 1 dot", "●●● → ●".spokenForScreenReader())
    }

    @Test fun lostHealthFillsEmptyBoxesThenUpgradesTheLeftmostLeastSevereWound() {
        val track = listOf(Damage.lethal, Damage.none, Damage.bashing, Damage.aggravated, Damage.bashing)
        assertEquals(listOf(Damage.lethal, Damage.aggravated, Damage.lethal), track.foldedHealth(3))
        assertEquals(listOf(Damage.aggravated, Damage.lethal), track.foldedHealth(2))
        assertEquals(emptyList<Damage>(), track.foldedHealth(0))
        assertEquals(track + Damage.none, track.foldedHealth(track.size + 1))
        assertEquals(listOf(Damage.lethal, Damage.none), track.visibleTrack(2, Damage.none))
    }

    @Test fun ledgerUsesTheCostOfEachLevelAndRefundsItsOriginalPrice() {
        val key = "gift:example"
        val empty = ExperienceLedger(emptyMap(), emptyList())
        val two = mapOf(key to TraitLevel(2, "Second Gift"))
        val bought = empty.record(emptyMap(), two, listOf("gift"), true, false, 1.0,
            costPerDot = { _, level -> if (level == 1) 5 else 2 }, refunds = { true })
        assertEquals(mapOf(1 to 5, 2 to 2), bought.paidDots[key])
        assertEquals(7, bought.changeLog.single().experiences)
        val refunded = bought.record(two, emptyMap(), listOf("gift"), true, false, 2.0,
            costPerDot = { _, _ -> error("A refund must use the ledger") }, refunds = { true })
        assertEquals(-7, refunded.changeLog.last().experiences)
        assertTrue(refunded.paidDots.isEmpty())
    }
}
