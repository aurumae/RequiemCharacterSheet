package ie.forsaken.rules

import ie.chronicles.core.*
import org.junit.Assert.*
import org.junit.Test
import java.util.UUID

class ForsakenLogTest {
    private val catalog=ForsakenTestCatalog.catalog
    private val codec=ForsakenCodec(catalog)
    private val edits=ForsakenEdits(catalog)
    private fun rules(c: ForsakenCharacter)=ForsakenRules(c.state,catalog)

    @Test fun qualifiedMeritNamesAreRecordedAndDisplayedWithoutRewritingHistory() {
        var c=codec.character(ForsakenState(xpMode=true))
        c=edits.change(c) { it.copy(merits=listOf(Merit(TraitSource(catalog="specialty-merit"),"Claws",1))) }
        val purchase=c.state.changeLog.single()
        assertEquals("specialty-merit (Claws)",purchase.name)
        assertEquals(1,purchase.experiences)
        c=edits.change(c) { it.copy(merits=it.merits.map { row -> row.copy(qualifier="Teeth") }) }
        assertEquals("specialty-merit (Teeth)",rules(c).changeName(purchase))
        assertEquals(listOf(purchase),c.state.changeLog)
        assertEquals(c.state.changeLog,codec.decode(codec.encode(c)).state.changeLog)
        c=edits.change(c) { it.copy(merits=emptyList()) }
        assertEquals("specialty-merit (Claws)",rules(c).changeName(purchase))
        assertEquals(-1,c.state.changeLog.last().experiences)
        val unnamed=purchase.copy(trait="merit:${UUID.randomUUID()}",name="")
        assertEquals("Unnamed Merit",rules(c).changeName(unnamed))
    }

    @Test fun conditionHistoryUsesCurrentThenFinalNotesAndKeepsLegacyKeys() {
        val row=CharacterCondition(TraitSource(catalog="test-condition"))
        var c=edits.condition(codec.character(),row,ConditionEvent.added)
        val added=c.state.changeLog.single()
        assertEquals("test-condition −1",added.name)
        c=edits.change(c) { it.copy(conditions=it.conditions.map { condition -> condition.copy(note="Pack",counter=3) }) }
        assertEquals("test-condition −3 (Pack)",rules(c).changeName(added))
        assertEquals(listOf(added),c.state.changeLog)
        val legacy=added.copy(id=UUID.randomUUID(),trait="condition:${row.id.saveKey()}",name="Legacy name")
        c=codec.character(c.state.copy(changeLog=c.state.changeLog+legacy))
        assertEquals("Legacy name",rules(c).changeName(legacy))
        c=edits.condition(c,c.state.conditions.single(),ConditionEvent.ended)
        assertEquals("test-condition −3 (Pack)",rules(c).changeName(added))
        assertEquals("Legacy name",rules(c).changeName(legacy))
        val saved=codec.decode(codec.encode(c))
        assertEquals(c.state.changeLog,saved.state.changeLog)
        assertEquals(added,saved.state.changeLog.first())
    }

    @Test fun sacredHuntUsesTheLodgeIdWithinSiskurDahRatherThanDisplayNames() {
        val lodge=catalog.entry(CatalogKind.lodges,"adherents")!!
        assertEquals("Match the lodge ID",catalog.sacredHunt(lodge)?.summary)
        assertNull(catalog.sacredHunt(catalog.entry(CatalogKind.lodges,"story")!!))
    }
}
