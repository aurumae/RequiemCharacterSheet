package ie.forsaken.sheet

import ie.chronicles.core.*
import ie.forsaken.rules.*
import kotlinx.serialization.json.*
import org.junit.*
import org.junit.Assert.*
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.UUID

class PlayTransferTest {
    @get:Rule val temporary = TemporaryFolder()
    private fun store() = forsakenStore(temporary.root)
    private fun fixture(name: String = "play") = javaClass.getResource("/forsaken-v1-$name.json")!!.readBytes()
    private fun fields(bytes: ByteArray) = Json.parseToJsonElement(bytes.decodeToString()).jsonObject
    private fun changed(bytes: ByteArray, change: MutableMap<String, JsonElement>.() -> Unit): ByteArray =
        JsonObject(fields(bytes).toMutableMap().apply(change)).toString().toByteArray()

    @Test fun ordinaryEditsPersistOnceWithHistoricalCostsAndStaleWritesAreRefused() {
        val repository=store(); val edits=ForsakenEdits()
        val opened=repository.importCharacter(repository.prepareImport(fixture()))
        val oldLog=opened.saved.state.changeLog.size
        val raised=edits.change(opened.saved,at=800086400.125) { state -> state.copy(skills=state.skills.map {
            if(it.skill=="athletics") it.copy(rating=it.rating+1) else it
        }) }
        val saved=repository.persist(opened,raised)
        assertNotEquals(opened.text,saved.text)
        val restarted=store().open(saved.saved.id)
        assertEquals(oldLog+1,restarted.saved.state.changeLog.size)
        assertEquals(2,restarted.saved.state.changeLog.last().experiences)
        assertEquals("skill:athletics",restarted.saved.state.changeLog.last().trait)
        assertEquals(opened.saved.state.facets,restarted.saved.state.facets)
        assertEquals(opened.saved.state.totem,restarted.saved.state.totem)
        assertEquals(opened.saved.state.renownFacetCredits,restarted.saved.state.renownFacetCredits)
        assertSame(restarted,repository.persist(restarted,restarted.saved))
        assertArrayEquals(saved.file.readBytes(),repository.export(saved.saved.id).bytes)
        assertThrows(IllegalStateException::class.java) { repository.persist(opened,raised) }
        val lowered=edits.change(restarted.saved) { state -> state.copy(skills=state.skills.map {
            if(it.skill=="athletics") it.copy(rating=it.rating-1) else it
        }) }
        val refunded=repository.persist(restarted,lowered)
        assertEquals(-2,refunded.saved.state.changeLog.last().experiences)
        assertEquals(ForsakenRules(opened.saved.state).experiencesSpent,ForsakenRules(refunded.saved.state).experiencesSpent)
        assertTrue(temporary.root.listFiles()!!.none { it.name.endsWith(".tmp") })
    }

    @Test fun creationIsReadOnlyEvenAtTheWriterBoundary() {
        val repository=store(); val opened=repository.importCharacter(repository.prepareImport(fixture("creation")))
        val illegal=ForsakenCodec().character(opened.saved.state.copy(name="Changed"))
        assertThrows(IllegalStateException::class.java) { repository.persist(opened,illegal) }
        assertThrows(IllegalStateException::class.java) { ForsakenEdits().change(opened.saved) { it.copy(tribe=TraitSource(custom="")) } }
        assertArrayEquals(fixture("creation"),repository.export(opened.saved.id).bytes)
    }

    @Test fun submittedFilesOpenRestartAndExportByteForByte() {
        for (name in listOf("play", "creation")) {
            val bytes = fixture(name)
            val repository = store()
            val opened = repository.importCharacter(repository.prepareImport(bytes))
            assertArrayEquals(bytes, opened.file.readBytes())
            assertArrayEquals(bytes, repository.export(opened.saved.id).bytes)
            assertTrue(repository.export(opened.saved.id).fileName.endsWith(".wtfcharacter"))
            assertSame(opened, repository.persist(opened, opened.saved))
            assertEquals(opened.saved.state, store().open(opened.saved.id).saved.state)
            assertArrayEquals(bytes, store().export(opened.saved.id).bytes)
        }
        assertEquals(setOf("Mara Voss", "Ash"), store().library().map { it.name }.toSet())
        assertEquals(true, store().library().single { it.name == "Ash" }.guided)
    }

    @Test fun cancelIdenticalReplaceAndKeepBothProtectOriginalAndUnknownFields() {
        val repository = store()
        val bytes = changed(fixture()) { put("unrecognized", Json.parseToJsonElement("""{"keep":[null,9.25]}""")) }
        val opened = repository.importCharacter(repository.prepareImport(bytes))
        val incoming = changed(bytes) { put("name", JsonPrimitive("Incoming")); put("modifiedAt", JsonPrimitive(800086400.125)) }
        val pending = repository.prepareImport(incoming)
        assertFalse(pending.identical)
        // Preparing then cancelling makes no mutation.
        assertArrayEquals(bytes, repository.export(opened.saved.id).bytes)
        val copy = repository.importCharacter(repository.keepBoth(pending))
        assertNotEquals(opened.saved.id, copy.saved.id)
        assertEquals("Incoming (1)", copy.saved.name)
        assertEquals(fields(incoming) - setOf("id", "name"), fields(repository.export(copy.saved.id).bytes) - setOf("id", "name"))
        assertArrayEquals(bytes, repository.export(opened.saved.id).bytes)
        repository.importCharacter(repository.prepareImport(incoming))
        assertArrayEquals(incoming, repository.export(opened.saved.id).bytes)
        val identical = repository.prepareImport(changed(incoming) { put("modifiedAt", JsonPrimitive(1.0)) })
        assertTrue(identical.identical)
        repository.importCharacter(identical)
        assertArrayEquals(incoming, repository.export(opened.saved.id).bytes)
        assertEquals(2, store().library().size)
    }

    @Test fun caseInsensitiveIdentityAndOldFilesWithoutIdKeepTheirData() {
        val repository = store()
        val id = UUID.fromString("ABCDEF01-ABCD-4000-8000-ABCDEF123456")
        val lower = changed(fixture()) { put("id", JsonPrimitive(id.toString().lowercase())) }
        val opened = repository.importCharacter(repository.prepareImport(lower))
        assertEquals(id, opened.saved.id)
        assertArrayEquals(lower, repository.export(id).bytes)
        val uppercase = changed(lower) { put("id", JsonPrimitive(id.toString().uppercase())) }
        assertTrue(repository.prepareImport(uppercase).identical)
        val partial = changed(fixture("creation")) { remove("id"); put("unknown", JsonPrimitive("retain")) }
        val first = repository.prepareImport(partial)
        val recovered = repository.prepareImport(first.document.bytes)
        assertEquals(first.document.character.id, recovered.document.character.id)
        assertEquals(fields(partial), fields(first.document.bytes) - "id")
        repository.importCharacter(recovered)
        assertArrayEquals(first.document.bytes, store().export(recovered.document.character.id).bytes)
    }

    @Test fun wrongGameAndFutureFilesAreRefusedBeforeImportOrLibraryMutation() {
        val repository = store()
        val opened = repository.importCharacter(repository.prepareImport(fixture()))
        val gameError = "This character is from another game. Open it in that game's app."
        val originals = listOf(
            """{"name":"Vampire","id":"${opened.saved.id}","schemaVersion":12}""",
            """{"name":"Vampire","game":"requiem","id":"${opened.saved.id}","schemaVersion":999}""",
            """{"name":"Unknown","game":"other","id":"${opened.saved.id}","schemaVersion":999}""",
        )
        originals.forEach { foreign ->
            assertEquals(gameError, assertThrows(CharacterDocumentError::class.java) { repository.prepareImport(foreign.toByteArray()) }.message)
            val id = UUID.randomUUID()
            val foreignBytes = changed(foreign.toByteArray()) { put("id", JsonPrimitive(id.toString())) }
            val file = File(temporary.root, "$id.json").apply { writeBytes(foreignBytes) }
            assertEquals(gameError, store().library().single { it.id == id }.problem)
            assertThrows(UnsupportedGame::class.java) { store().open(id) }
            assertThrows(UnsupportedGame::class.java) { store().export(id) }
            assertArrayEquals(foreignBytes, file.readBytes())
            assertTrue(file.delete())
        }
        val next = changed(fixture()) { put("schemaVersion", JsonPrimitive(2)) }
        assertTrue(assertThrows(CharacterDocumentError::class.java) { repository.prepareImport(next) }.message!!.contains("newer version"))
        for (bad in listOf("{", "[]", """{"game":"forsaken","name":"Bad","schemaVersion":"1"}""",
            """{"game":"forsaken","name":"Bad","healthTrack":["unknown"]}"""))
            assertThrows(CharacterDocumentError::class.java) { repository.prepareImport(bad.toByteArray()) }
        assertThrows(CharacterDocumentError::class.java) { repository.prepareImport(byteArrayOf(0xc3.toByte(), 0x28)) }
        assertArrayEquals(fixture(), repository.export(opened.saved.id).bytes)
        assertEquals(1, repository.library().size)
    }

    @Test fun staleReplacementFailsAndOnlyBlankCreationIsAllowed() {
        val repository = store()
        val opened = repository.importCharacter(repository.prepareImport(fixture()))
        val pending = repository.prepareImport(changed(fixture()) { put("name", JsonPrimitive("Replace")) })
        val newer = changed(fixture()) { put("name", JsonPrimitive("Newer")) }
        opened.file.writeBytes(newer)
        assertThrows(IllegalStateException::class.java) { repository.importCharacter(pending) }
        assertArrayEquals(newer, opened.file.readBytes())
        val blank = repository.create()
        assertEquals("", blank.saved.name)
        assertNull(blank.saved.state.creation)
        assertThrows(IllegalStateException::class.java) { repository.create(true) }
        assertEquals(2, repository.library().size)
    }
}
