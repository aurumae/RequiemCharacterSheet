package ie.requiem.sheet

import ie.requiem.rules.*
import org.junit.*
import org.junit.Assert.*
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.UUID

class CharacterFilesTest {
    @get:Rule val temp = TemporaryFolder()
    private val catalog = Catalog.bundled()
    private fun repository() = CharacterFiles(temp.root, catalog)
    private fun fixture(name: String) = javaClass.getResource("/characters/$name.json")!!.readText()

    @Test fun purchasedStaminaAndDamageSurviveAColdReopenAndRefundOnlyOnce() {
        val first = repository()
        val blank = first.create()
        fun change(c: CharacterSave, action: SheetEdit) = c.edit(action, catalog, 800_000_000.25)
        val free = change(blank.saved, SheetEdit.Stamina(1))
        val paid = change(change(free, SheetEdit.XpMode(true)), SheetEdit.Stamina(1))
        val marked = change(paid, SheetEdit.Mark(7))
        val written = first.persist(blank, marked)
        assertEquals(listOf(0, 4), written.saved.changeLog.map { it.experiences })
        val second = repository()
        val opened = second.open(blank.saved.id)
        assertSame(opened, second.persist(opened, opened.saved))
        assertEquals(-4, opened.saved.experiencesAvailable)
        assertEquals(Damage.bashing, opened.saved.healthTrack[7])
        assertEquals(mapOf(3 to 4), opened.saved.paidDots["attribute:stamina"])
        val refund = second.persist(opened, change(opened.saved, SheetEdit.Stamina(-1)))
        val reopened = repository().open(blank.saved.id)
        assertEquals(refund.saved, reopened.saved)
        assertTrue(reopened.saved.paidDots.isEmpty())
        assertEquals(listOf(0, 4, -4), reopened.saved.changeLog.map { it.experiences })
        assertEquals(0, reopened.saved.experiencesAvailable)
        val freeLoss = change(change(paid, SheetEdit.XpMode(false)), SheetEdit.Stamina(-1))
        assertTrue(freeLoss.paidDots.isEmpty())
        assertEquals(0, freeLoss.changeLog.last().experiences)
    }

    @Test fun protectedFilesRemainVisibleAndUnmodified() {
        val repo = repository()
        val codec = CharacterCodec(catalog)
        val guidedText = fixture("v9-guided")
        val guided = codec.decode(guidedText)
        val file = File(temp.root, "${guided.id.toString().uppercase()}.json").apply { writeText(guidedText) }
        val opened = repo.open(guided.id)
        val actions = listOf(SheetEdit.Rename("changed"), SheetEdit.XpMode(true), SheetEdit.Stamina(1), SheetEdit.Mark(0))
        actions.forEach { assertSame(opened.saved, opened.saved.edit(it, catalog)) }
        assertThrows(IllegalStateException::class.java) { repo.persist(opened, guided.copy(name = "changed")) }
        val future = File(temp.root, "${UUID.randomUUID()}.json").apply { writeText(fixture("v10-future")) }
        val broken = File(temp.root, "${UUID.randomUUID()}.json").apply { writeText("{") }
        assertEquals(2, repo.library().count { it.problem != null })
        assertEquals(true, repo.library().first().guided)
        assertEquals(guidedText, file.readText())
        assertEquals(fixture("v10-future"), future.readText())
        assertEquals("{", broken.readText())
    }

    @Test fun staleSessionCannotReplaceANewerFileAndUnchangedLegacyIsNeverRewritten() {
        val repo = repository()
        val id = UUID.randomUUID()
        val old = File(temp.root, "$id.json").apply { writeText(fixture("v1-unversioned")) }
        val session = repo.open(id)
        assertEquals(id, session.saved.id)
        assertSame(session, repo.persist(session, session.saved))
        assertEquals(fixture("v1-unversioned"), old.readText())
        old.writeText(fixture("v10-future"))
        assertThrows(IllegalStateException::class.java) { repo.persist(session, session.saved.copy(name = "edit")) }
        assertEquals(fixture("v10-future"), old.readText())
    }
}
