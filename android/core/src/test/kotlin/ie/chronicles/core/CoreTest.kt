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
}
