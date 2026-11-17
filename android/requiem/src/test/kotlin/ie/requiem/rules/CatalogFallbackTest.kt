package ie.requiem.rules

import org.junit.Assert.*
import org.junit.Test

class CatalogFallbackTest {
    /** General advisory-text evidence: descriptions survive unknown fields and rule values.
     * This does not certify numeric behavior for a rule Android has not implemented.
     */
    @Test fun unknownCatalogFieldsAndRuleValuesRemainAdvisoryText() {
        val catalog = Catalog(mapOf("future.json" to """{
          "format":"requiem-catalog","version":1,
          "book":{"id":"future","name":"Future Examples","official":true,"url":"https://example.invalid/book"},
          "futureBookField":{"nested":[1,true]},
          "merits":[{
            "id":"future-merit","name":"Future Merit","ratings":[1,2,3],
            "source":{"book":"future","page":42},
            "summary":"Discuss the unimplemented benefit with the Storyteller.",
            "futureEntryField":{"nested":[1,true]},
            "prerequisites":[{"kind":"futureRequirement","minimum":99,"text":"Storyteller approval"}],
            "effects":[{"type":"futureEffect","amount":{"fixed":99}},
                       {"type":"speed","amount":{"fixed":2}}]
          }],
          "disciplines":[{
            "id":"future-discipline","name":"Future Discipline","kind":"ritual",
            "source":{"book":"future","page":43},
            "summary":"Resolve the new Humanity rule with the Storyteller.",
            "ritualRules":{"covenant":"example","covenantStatusMinimum":0,"humanity":"futureHumanityRule"}
          }]
        }"""))
        val blank = CharacterSave()
        val option = blank.catalogSections(EntryKind.Merit, catalog, "Storyteller")
            .flatMap { it.entries }.single()
        val entry = option.entry
        assertNotNull(entry.raw["futureEntryField"])
        assertNull(option.warning)
        assertEquals(listOf(PrerequisiteCheck("Storyteller approval", null)), blank.prerequisites(entry, catalog))
        val detail = blank.bookDetail(entry, catalog, rating = 2)
        assertEquals("Future Merit", detail.title)
        assertEquals("Discuss the unimplemented benefit with the Storyteller.", detail.summary)
        assertEquals("Future Examples, p. 42", detail.citation)
        assertTrue(detail.facts.contains(DetailFact("Prerequisite", "Storyteller approval · Check yourself")))
        assertEquals(listOf(DetailFact("On your sheet", "Adds 2 to Speed")), detail.facts.filter { it.label == "On your sheet" })

        val owned = blank.edit(SheetEdit.AddEntry(EntryKind.Merit, entry.source()), catalog)
            .copy(disciplines = listOf(Discipline(TraitSource(catalog = "future-discipline"), rating = 2)))
        assertEquals(entry.source(), owned.merits.single().source)
        assertEquals(blank.speed(catalog) + 2, owned.speed(catalog))
        assertEquals(blank.health(catalog), owned.health(catalog))
        assertEquals(blank.defense(catalog), owned.defense(catalog))
        assertEquals(blank.totalAttribute("strength", catalog), owned.totalAttribute("strength", catalog))
        assertNull(owned.humanityCap(catalog))
        val ritual = requireNotNull(catalog.entry(CatalogKind.disciplines, "future-discipline"))
        val ritualDetail = owned.bookDetail(ritual, catalog, rating = 1)
        assertEquals("Resolve the new Humanity rule with the Storyteller.", ritualDetail.summary)
        assertFalse(ritualDetail.facts.any { it.label == "Humanity" })
        val codec = CharacterCodec(catalog)
        val restored = codec.decode(codec.encode(owned))
        assertEquals(owned.merits, restored.merits)
        assertEquals(owned.disciplines, restored.disciplines)
        assertEquals(detail.summary, restored.bookDetail(entry, catalog).summary)
    }
}
