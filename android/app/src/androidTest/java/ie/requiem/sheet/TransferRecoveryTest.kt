package ie.requiem.sheet

import android.app.Application
import androidx.core.content.FileProvider
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModelStore
import androidx.test.platform.app.InstrumentationRegistry
import ie.requiem.rules.*
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.util.UUID

class TransferRecoveryTest {
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val app get() = instrumentation.targetContext.applicationContext as Application
    private val files get() = CharacterFiles(File(app.filesDir, "Characters"), Catalog.bundled())
    private val transfers get() = TransferFiles(app)
    private val codec = CharacterCodec(Catalog.bundled())
    private fun wait(model: SheetModel, condition: (Screen) -> Boolean): Screen = runBlocking {
        withTimeout(10_000) { model.ui.first { !it.busy && condition(it) } }
    }
    private fun withModel(state: SavedStateHandle = SavedStateHandle(), action: (SheetModel) -> Unit) {
        val store = ViewModelStore()
        lateinit var model: SheetModel
        instrumentation.runOnMainSync { model = SheetModel(app, state); store.put("transfer", model) }
        try { action(model) } finally { instrumentation.runOnMainSync { store.clear() } }
    }

    @Test fun journalRestoresDuplicateChoiceAndCompletedCopyIsNotImportedTwice() {
        val original = codec.decode(codec.encode(CharacterSave(name = "Recovery ${UUID.randomUUID()}", modifiedAt = 800_000_000.0)))
        files.importCharacter(files.prepareImport(codec.encode(original).toByteArray()))
        val incoming = original.copy(player = "Imported", modifiedAt = 800_000_050.0)
        transfers.stage(codec.encode(incoming).toByteArray())
        try {
            withModel(SavedStateHandle(mapOf("openId" to original.id.toString()))) { model ->
                val pending = wait(model) { it.pendingImport != null }
                assertNull(pending.character)
                assertEquals(incoming, pending.pendingImport!!.document.character)
            }
            var copied: CharacterSave? = null
            withModel { model ->
                wait(model) { it.pendingImport != null }
                instrumentation.runOnMainSync { model.resolveImport(keepBoth = true) }
                copied = wait(model) { it.character != null }.character!!
            }
            val copy = copied!!
            assertEquals(incoming.name + " (1)", copy.name)
            assertNotEquals(original.id, copy.id)
            // Simulate death after the atomic character write but before clearing the journal.
            transfers.stage(files.export(copy.id).bytes)
            val count = files.library().size
            withModel { model ->
                assertEquals(copy.id, wait(model) { it.character != null }.character!!.id)
                assertEquals(count, files.library().size)
                assertNull(transfers.pendingBytes())
            }
        } finally { transfers.clearPending() }
    }

    @Test fun saveDestinationResultAfterModelRecreationUsesTheOriginalExportSnapshot() {
        val character = CharacterSave(name = "Save recovery", modifiedAt = 800_000_000.0)
        val bytes = codec.encode(character).toByteArray()
        val snapshot = transfers.snapshot(CharacterExport("Save recovery.vtrcharacter", bytes), ExportMode.Save)
        val state = SavedStateHandle(mapOf("exportPath" to snapshot.file.path, "exportName" to snapshot.name))
        val target = File(app.cacheDir, "character-exports/test-${UUID.randomUUID()}/saved.vtrcharacter")
        target.parentFile!!.mkdirs(); target.writeBytes(byteArrayOf())
        val destination = FileProvider.getUriForFile(app, "${app.packageName}.characterfiles", target)
        withModel(state) { model ->
            wait(model) { it.awaitingDestination }
            instrumentation.runOnMainSync { model.saveExport(destination) }
            wait(model) { it.transferNotice > 0 }
            assertArrayEquals(bytes, target.readBytes())
        }
    }
}
