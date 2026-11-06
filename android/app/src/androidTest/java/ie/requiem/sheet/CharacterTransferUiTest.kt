package ie.requiem.sheet

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.core.content.FileProvider
import androidx.test.platform.app.InstrumentationRegistry
import ie.requiem.rules.*
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.io.File
import java.util.UUID
import java.util.concurrent.atomic.AtomicReference

class CharacterTransferUiTest {
    @get:Rule val ui = createAndroidComposeRule<MainActivity>()
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext
    private val codec = CharacterCodec(Catalog.bundled())
    private fun stored(id: UUID) = File(context.filesDir, "Characters/$id.json")
    private fun ready(tag: String) = ui.waitUntil(10_000) { ui.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }
    private fun library() {
        if (ui.onAllNodesWithTag("dark-pack-splash").fetchSemanticsNodes().isNotEmpty()) ui.onNodeWithTag("dark-pack-splash").performClick()
        ready("character-library")
    }
    private fun row(text: String) {
        ui.onNodeWithTag("character-library").performScrollToNode(hasText(text))
        ui.onNodeWithText(text).performClick()
    }
    private fun uri(bytes: ByteArray): Uri {
        val file = File(context.cacheDir, "character-exports/test-${UUID.randomUUID()}/input.vtrcharacter")
        file.parentFile!!.mkdirs(); file.writeBytes(bytes)
        return FileProvider.getUriForFile(context, "${context.packageName}.characterfiles", file)
    }
    private fun receive(bytes: ByteArray, mime: String? = "application/json", view: Boolean = false) {
        val uri = uri(bytes)
        val intent = Intent(context, MainActivity::class.java).apply {
            action = if (view) Intent.ACTION_VIEW else Intent.ACTION_SEND
            if (view) setDataAndType(uri, mime) else { type = mime; putExtra(Intent.EXTRA_STREAM, uri) }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(intent)
    }
    private fun conflict(name: String) {
        ui.waitUntil(10_000) { ui.onAllNodesWithText("“$name” Is Already Here").fetchSemanticsNodes().isNotEmpty() }
    }
    private fun back() { ui.onNodeWithContentDescription("Back").performClick(); ready("character-library") }
    private fun options(name: String) {
        ui.onNodeWithTag("character-library").performScrollToNode(hasText(name))
        ui.onNodeWithContentDescription("Options for $name").performClick()
    }

    @Test fun externalImportFlushesOpenEditsAndSupportsCancelKeepBothReplaceAndIdentical() {
        library()
        val original = codec.decode(codec.encode(CharacterSave(name = "Transfer ${UUID.randomUUID().toString().take(8)}", modifiedAt = 800_000_000.25)))
        val bytes = codec.encode(original).toByteArray()
        receive(bytes, mime = null)
        ready("character-sheet")
        // Do not submit the field: incoming-file handling must commit its focused text first.
        ui.onNodeWithContentDescription("Character name").performTextReplacement(original.name + " local")
        val incoming = original.copy(name = original.name + " incoming", modifiedAt = 800_000_100.5)
        val changed = codec.encode(incoming).toByteArray()
        receive(changed, mime = "application/octet-stream", view = true)
        conflict(incoming.name)
        assertEquals(original.name + " local", codec.decode(stored(original.id).readText()).name)
        val localBytes = stored(original.id).readBytes()
        ui.onNodeWithText("Cancel").performClick()
        ready("character-library")
        assertArrayEquals(localBytes, stored(original.id).readBytes())
        receive(changed)
        conflict(incoming.name)
        ui.activityRule.scenario.recreate()
        conflict(incoming.name)
        ui.onNodeWithText("Keep Both").performClick()
        ready("character-sheet")
        ui.onNodeWithContentDescription("Character name").assertTextContains(incoming.name + " (1)")
        val copy = File(context.filesDir, "Characters").listFiles()!!.mapNotNull { runCatching { codec.decode(it.readText()) }.getOrNull() }
            .single { it.name == incoming.name + " (1)" }
        assertNotEquals(original.id, copy.id)
        assertEquals(incoming.copy(id = copy.id, name = copy.name), copy)
        assertArrayEquals(localBytes, stored(original.id).readBytes())
        back()
        receive(changed)
        conflict(incoming.name)
        ui.onNodeWithText("Replace").performClick()
        ready("character-sheet")
        assertArrayEquals(changed, stored(original.id).readBytes())
        back()
        receive(codec.encode(incoming.copy(modifiedAt = 1.0)).toByteArray())
        ready("character-sheet")
        ui.onNodeWithText("Keep Both").assertDoesNotExist()
        assertArrayEquals(changed, stored(original.id).readBytes())
    }

    @Test fun libraryPickerAndExportsUseSystemContractsAndPreserveBytes() {
        library()
        val character = CharacterSave(name = "File ${UUID.randomUUID().toString().take(8)}", modifiedAt = 800_000_000.25)
        val bytes = codec.encode(character).toByteArray()
        var result: Instrumentation.ActivityResult = Instrumentation.ActivityResult(Activity.RESULT_CANCELED, null)
        val captured = AtomicReference<Intent>()
        val monitor = object : Instrumentation.ActivityMonitor() {
            override fun onStartActivity(intent: Intent): Instrumentation.ActivityResult? {
                if (intent.action !in listOf(Intent.ACTION_OPEN_DOCUMENT, Intent.ACTION_CREATE_DOCUMENT, Intent.ACTION_CHOOSER)) return null
                captured.set(intent)
                return result
            }
        }
        instrumentation.addMonitor(monitor)
        try {
            row("Import Character")
            ui.waitUntil(5000) { captured.get() != null }
            assertEquals(Intent.ACTION_OPEN_DOCUMENT, captured.get().action)
            assertFalse(stored(character.id).exists())
            result = Instrumentation.ActivityResult(Activity.RESULT_OK, Intent().setData(uri(bytes)))
            captured.set(null)
            row("Import Character")
            ready("character-sheet")
            assertArrayEquals(bytes, stored(character.id).readBytes())
            back()
            result = Instrumentation.ActivityResult(Activity.RESULT_CANCELED, null)
            // The long-press shortcut and overflow present the same library-only actions.
            ui.onNodeWithTag("character-library").performScrollToNode(hasText(character.name))
            ui.onNodeWithText(character.name).performTouchInput { longClick() }
            captured.set(null)
            ui.onNodeWithText("Export").performClick()
            ui.waitUntil(5000) { captured.get()?.action == Intent.ACTION_CHOOSER }
            val send = captured.get().getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)!!
            assertEquals(Intent.ACTION_SEND, send.action)
            assertEquals("application/octet-stream", send.type)
            assertTrue(send.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
            assertEquals(0, send.flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            val shared = send.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)!!
            assertArrayEquals(bytes, context.contentResolver.openInputStream(shared)!!.use { it.readBytes() })
            context.contentResolver.query(shared, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)!!.use {
                assertTrue(it.moveToFirst()); assertEquals(character.name + ".vtrcharacter", it.getString(0))
            }
            val destination = uri(byteArrayOf())
            result = Instrumentation.ActivityResult(Activity.RESULT_OK, Intent().setData(destination))
            captured.set(null)
            options(character.name)
            ui.onNodeWithText("Save to file").performClick()
            ui.waitUntil(5000) { captured.get()?.action == Intent.ACTION_CREATE_DOCUMENT }
            assertEquals("application/octet-stream", captured.get().type)
            assertEquals(character.name + ".vtrcharacter", captured.get().getStringExtra(Intent.EXTRA_TITLE))
            ui.waitUntil(5000) { context.contentResolver.openInputStream(destination)!!.use { it.readBytes() }.contentEquals(bytes) }
            assertArrayEquals(bytes, stored(character.id).readBytes())
        } finally { instrumentation.removeMonitor(monitor) }
    }

    @Test fun damagedAndFutureFilesShowErrorsWithoutCreatingCharacters() {
        library()
        val before = File(context.filesDir, "Characters").listFiles()?.map { it.name }?.toSet().orEmpty()
        for ((text, error) in listOf("{}" to "The file isn't a character file, or it's damaged.",
            "{\"schemaVersion\":11}" to "This character was saved by a newer version of the app. Update the app to open it.")) {
            receive(text.toByteArray())
            ui.waitUntil(10_000) { ui.onAllNodesWithText(error).fetchSemanticsNodes().isNotEmpty() }
            ui.onNodeWithText("OK").performClick()
            ready("character-library")
            assertEquals(before, File(context.filesDir, "Characters").listFiles()?.map { it.name }?.toSet().orEmpty())
        }
    }
}
