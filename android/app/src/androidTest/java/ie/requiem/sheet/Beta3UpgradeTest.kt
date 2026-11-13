package ie.requiem.sheet

import androidx.test.platform.app.InstrumentationRegistry
import ie.requiem.rules.*
import java.io.File
import java.util.UUID
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test

/** Explicit release acceptance: install code 10, stage fixtures, install 11 without uninstalling. */
class Beta3UpgradeTest {
    @Test fun preexistingCharactersSurviveInPlaceUpdateWithoutRewriting() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("upgradeCheck") == "true")
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        assertEquals(11L, context.packageManager.getPackageInfo(context.packageName, 0).longVersionCode)
        val directory = File(context.filesDir, "Characters")
        val expected = File(context.filesDir, "Beta3UpgradeExpected")
        val files = expected.listFiles().orEmpty().filter { it.extension == "json" }
        assertEquals("Stage ordinary, guided, Conditions and elder-bane characters under code 10 first", 4, files.size)
        val catalog = Catalog.bundled()
        val codec = CharacterCodec(catalog)
        val store = CharacterFiles(directory, catalog)
        files.forEach { original ->
            val bytes = original.readBytes()
            val character = codec.decode(bytes.decodeToString())
            val id = UUID.fromString(original.nameWithoutExtension)
            assertEquals(id, character.id)
            val opened = store.open(id)
            assertEquals(character, opened.saved)
            assertArrayEquals(bytes, store.export(id).bytes)
            store.persist(opened, opened.saved)
            assertArrayEquals(bytes, store.export(id).bytes)
        }
        assertTrue(files.any { codec.decode(it.readText()).creation != null })
        assertTrue(files.any { codec.decode(it.readText()).conditions.isNotEmpty() })
        assertTrue(files.any { codec.decode(it.readText()).elderBaneActive })
    }
}
