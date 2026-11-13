package ie.requiem.sheet

import ie.requiem.rules.*
import java.io.File
import org.junit.*
import org.junit.Assert.*
import org.junit.rules.TemporaryFolder

class CharacterTransferTest {
    @get:Rule val temp = TemporaryFolder()
    private val catalog = Catalog.bundled()
    private val codec = CharacterCodec(catalog)
    private fun repo() = CharacterFiles(temp.root, catalog)
    private fun fixture(name: String = "v10-advanced") = javaClass.getResource("/characters/$name.json")!!.readBytes()

    @Test fun exchangesActualStoredFilesAndCopiesWithSwift() {
        for (name in ContractFixtures.names("transfer")) {
            val exchange = ContractFixtures.exchange("characters/$name.json")?.let(::File)
            val bytes = exchange?.resolve("swift-transfer-$name.vtrcharacter")?.readBytes() ?: fixture(name)
            val store = CharacterFiles(File(temp.root, name), catalog)
            val opened = store.importCharacter(store.prepareImport(bytes))
            val exported = store.export(opened.saved.id).bytes
            assertArrayEquals(bytes, exported)
            val copy = store.importCharacter(store.keepBoth(store.prepareImport(bytes)))
            assertEquals(opened.saved.copy(id = copy.saved.id, name = copy.saved.name), copy.saved)
            exchange?.resolve("kotlin-transfer-$name.vtrcharacter")?.writeBytes(exported)
            exchange?.resolve("kotlin-transfer-copy-$name.vtrcharacter")?.writeBytes(store.export(copy.saved.id).bytes)
        }
    }

    @Test fun everyNewerScenarioIsRejectedWithoutChangingStorage() {
        val store = repo()
        val original = store.importCharacter(store.prepareImport(fixture()))
        for (bytes in ContractFixtures.rejectedFiles()) {
            assertThrows(CharacterDocumentError::class.java) { store.prepareImport(bytes) }
            assertArrayEquals(fixture(), store.export(original.saved.id).bytes)
            val file = File(temp.root, "${java.util.UUID.randomUUID()}.json").apply { writeBytes(bytes) }
            val id = java.util.UUID.fromString(file.nameWithoutExtension)
            assertNotNull(store.library().single { it.id == id }.problem)
            assertThrows(UnsupportedSchema::class.java) { store.open(id) }
            assertArrayEquals(bytes, file.readBytes())
            assertTrue(file.delete())
        }
    }

    @Test fun swiftFilesImportAndExportByteForByteIncludingLegacyAndLowercaseIdentity() {
        for (name in listOf("v10-advanced", "v10-guided", "v10-morbus", "v9-guided", "v8-paid", "v11-conditions", "v12-elder-bane")) {
            val bytes = fixture(name)
            val pending = repo().prepareImport(bytes)
            assertNull(pending.existing)
            val opened = repo().importCharacter(pending)
            assertArrayEquals(bytes, opened.file.readBytes())
            assertArrayEquals(bytes, repo().export(opened.saved.id).bytes)
            repo().delete(opened.saved.id)
        }
        val c = codec.decode(fixture().decodeToString())
        val lower = fixture().decodeToString().replace(c.id.toString().uppercase(), c.id.toString()).toByteArray()
        val opened = repo().importCharacter(repo().prepareImport(lower))
        assertArrayEquals(lower, repo().export(opened.saved.id).bytes)
    }

    @Test fun identicalImportsIgnoreEditedDateAndUuidCasingWithoutTouchingExistingBytes() {
        val repo = repo()
        val original = repo.importCharacter(repo.prepareImport(fixture()))
        val incoming = codec.encode(original.saved.copy(modifiedAt = original.saved.modifiedAt + 100))
            .replace(original.saved.id.toString().uppercase(), original.saved.id.toString()).toByteArray()
        val renamed = File(temp.root, "${original.saved.id.toString().uppercase()}.json")
        assertTrue(original.file.renameTo(renamed))
        val pending = repo.prepareImport(incoming)
        assertTrue(pending.identical)
        repo.importCharacter(pending)
        assertEquals(1, repo.library().size)
        assertArrayEquals(fixture(), renamed.readBytes())
    }

    @Test fun prepareAndCancelNeverWriteAndKeepBothRetainsLedgerAndTimestamps() {
        val repo = repo()
        val original = repo.importCharacter(repo.prepareImport(fixture()))
        val changed = codec.encode(original.saved.copy(name = "Lucius", modifiedAt = 1234.25)).toByteArray()
        val pending = repo.prepareImport(changed)
        assertFalse(pending.identical)
        assertArrayEquals(fixture(), original.file.readBytes())
        val first = repo.importCharacter(repo.keepBoth(pending))
        val second = repo.importCharacter(repo.keepBoth(pending))
        assertEquals("Lucius (1)", first.saved.name)
        assertEquals("Lucius (2)", second.saved.name)
        assertEquals(pending.document.character.copy(id = first.saved.id, name = first.saved.name), first.saved)
        assertArrayEquals(fixture(), original.file.readBytes())
        repo.delete(first.saved.id)
        assertEquals("Lucius (1)", repo.importCharacter(repo.keepBoth(pending)).saved.name)
        repo.importCharacter(pending)
        assertArrayEquals(changed, original.file.readBytes())
    }

    @Test fun invalidFilesDoNotChangeLibraryAndLegacyWithoutIdentityGetsOnePersistedIdentity() {
        val repo = repo()
        val original = repo.importCharacter(repo.prepareImport(fixture()))
        for (bytes in listOf("{}".toByteArray(), ContractFixtures.future(), "{\"name\":null}".toByteArray())) {
            assertThrows(CharacterDocumentError::class.java) { repo.prepareImport(bytes) }
            assertArrayEquals(fixture(), original.file.readBytes())
            assertEquals(1, repo.library().size)
        }
        val legacy = repo.prepareImport(fixture("v1-unversioned"))
        val restored = repo.prepareImport(legacy.document.bytes)
        assertEquals(legacy.document.character.id, restored.document.character.id)
        val saved = repo.importCharacter(restored)
        assertEquals(saved.saved.id, repo().open(saved.saved.id).saved.id)
    }

    @Test fun aConflictCannotOverwriteAFileChangedAfterTheQuestionWasShown() {
        val repo = repo()
        val opened = repo.importCharacter(repo.prepareImport(fixture()))
        val pending = repo.prepareImport(codec.encode(opened.saved.copy(name = "Imported")).toByteArray())
        val newer = repo.persist(opened, opened.saved.copy(name = "Edited meanwhile"))
        assertThrows(IllegalStateException::class.java) { repo.importCharacter(pending) }
        assertEquals("Edited meanwhile", repo.open(newer.saved.id).saved.name)
    }
}
