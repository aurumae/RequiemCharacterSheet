package ie.requiem.rules

import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.io.File

class CharacterDocumentTest {
    private val documents = CharacterDocuments(Catalog.bundled())
    private fun fixture() = javaClass.getResource("/characters/v10-advanced.json")!!.readBytes()

    @Test fun filesRequireACharacterNameAndRejectNewerFormatsBeforeAnyMigration() {
        for (text in listOf("{}", "[]", "null", "{", "{\"name\":3}", "{\"name\":\"Bad\",\"id\":\"no\"}",
            "{\"name\":\"Bad\",\"schemaVersion\":\"10\"}")) {
            val e = assertThrows(CharacterDocumentError::class.java) { documents.read(text.toByteArray()) }
            assertEquals("The file isn't a character file, or it's damaged.", e.message)
        }
        assertThrows(CharacterDocumentError::class.java) { documents.read(byteArrayOf(0xc3.toByte(), 0x28)) }
        val future = assertThrows(CharacterDocumentError::class.java) { documents.read(ContractFixtures.future()) }
        assertEquals("This character was saved by a newer version of the app. Update the app to open it.", future.message)
    }

    @Test fun keepBothChangesOnlyIdentityAndNumberedNameIncludingUnknownFields() {
        val objectValue = Json.parseToJsonElement(fixture().decodeToString()).jsonObject.toMutableMap()
        objectValue["name"] = JsonPrimitive("Lucius Avelorn (7)")
        objectValue["unrecognised"] = Json.parseToJsonElement("{\"futureFlag\":true,\"number\":123.456}")
        val bytes = JsonObject(objectValue).toString().toByteArray()
        val original = documents.read(bytes)
        assertArrayEquals(bytes, original.bytes)
        val copied = documents.copy(original, setOf("Lucius Avelorn (1)", "Lucius Avelorn (3)"))
        val result = Json.parseToJsonElement(copied.bytes.decodeToString()).jsonObject
        assertEquals("Lucius Avelorn (2)", copied.character.name)
        assertNotEquals(original.character.id, copied.character.id)
        assertEquals(objectValue - setOf("id", "name"), result - setOf("id", "name"))
        assertEquals("Unnamed Character (1)", copyName("", emptySet()))
        assertEquals("Name (1)", copyName("Name (2)", emptySet()))
    }

    @Test fun portableNamesCannotEscapeTheExportDirectory() {
        assertEquals("Unnamed Character.vtrcharacter", characterFileName(" \n\t "))
        assertEquals("Éabha  Crúac.vtrcharacter", characterFileName("Éabha/:Crúac"))
        assertEquals("A         B.vtrcharacter", characterFileName("A/\\:*?\"<>|B"))
        assertEquals("Lucius.vtrcharacter", characterFileName("  Lucius  "))
        assertEquals("A B.vtrcharacter", characterFileName("A\u200bB"))
    }

    @Test fun sharedCopyNamesMatchSwift() {
        val cases = Json.parseToJsonElement(javaClass.getResource("/character-transfer.json")!!.readText()).jsonArray
        for (value in cases) {
            val c = value.jsonObject
            assertEquals(c.getValue("copy").jsonPrimitive.content,
                copyName(c.getValue("name").jsonPrimitive.content, c.getValue("taken").jsonArray.map { it.jsonPrimitive.content }.toSet()))
        }
    }

    @Test fun exchangesActualExportedFilesAndCopiesWithSwift() {
        val directory = System.getProperty("exchangeDir")?.let(::File)
        for (name in ContractFixtures.names("transfer")) {
            val bytes = directory?.takeIf { ContractFixtures.selected("characters/$name.json") }?.resolve("swift-transfer-$name.vtrcharacter")?.readBytes()
                ?: javaClass.getResource("/characters/$name.json")!!.readBytes()
            val imported = documents.read(bytes)
            assertArrayEquals(bytes, imported.bytes)
            val copy = documents.copy(imported, emptySet())
            assertEquals(imported.character.copy(id = copy.character.id, name = copy.character.name), copy.character)
            directory?.takeIf { ContractFixtures.selected("characters/$name.json") }?.resolve("kotlin-document-$name.vtrcharacter")?.writeBytes(imported.bytes)
            directory?.takeIf { ContractFixtures.selected("characters/$name.json") }?.resolve("kotlin-document-copy-$name.vtrcharacter")?.writeBytes(copy.bytes)
        }
    }
}
