package ie.requiem.rules

import java.util.Locale
import java.util.UUID
import kotlinx.serialization.json.*

class CharacterDocumentError(message: String) : IllegalArgumentException(message)

/** A validated transfer file. Its original representation is retained, including unknown fields. */
data class CharacterDocument(val bytes: ByteArray, val character: CharacterSave)

class CharacterDocuments(catalog: Catalog) {
    private val codec = CharacterCodec(catalog)

    fun read(bytes: ByteArray): CharacterDocument {
        try {
            val text = bytes.decodeToString(throwOnInvalidSequence = true)
            val objectValue = Json.parseToJsonElement(text) as? JsonObject ?: throw IllegalArgumentException()
            val version = objectValue["schemaVersion"] as? JsonPrimitive
            if (version?.isString == false && (version.longOrNull ?: 0) > CURRENT_SCHEMA) {
                throw CharacterDocumentError("This character was saved by a newer version of the app. Update the app to open it.")
            }
            require((objectValue["name"] as? JsonPrimitive)?.isString == true)
            val character = codec.decode(text)
            // Older saves gain a stable identity once, before a pending import can be restored.
            val stored = if (objectValue["id"] == null || objectValue["id"] == JsonNull)
                codec.encode(character).toByteArray(Charsets.UTF_8) else bytes.copyOf()
            return CharacterDocument(stored, character)
        } catch (e: CharacterDocumentError) {
            throw e
        } catch (_: Exception) {
            throw CharacterDocumentError("The file isn't a character file, or it's damaged.")
        }
    }

    /** Like iOS, compare the decoded saved state, ignoring only its edited date. */
    fun equivalent(a: CharacterSave, b: CharacterSave): Boolean = comparable(a) == comparable(b)

    private fun comparable(c: CharacterSave): Map<String, JsonElement> =
        Json.parseToJsonElement(codec.encode(c)).jsonObject - "modifiedAt"

    fun copy(document: CharacterDocument, takenNames: Set<String>): CharacterDocument {
        val fields = Json.parseToJsonElement(document.bytes.decodeToString()).jsonObject.toMutableMap()
        fields["id"] = JsonPrimitive(UUID.randomUUID().toString().uppercase(Locale.ROOT))
        fields["name"] = JsonPrimitive(copyName(document.character.name, takenNames))
        return read(JsonObject(fields).toString().toByteArray(Charsets.UTF_8))
    }
}

fun characterFileName(name: String): String {
    val unsafe = "/\\:*?\"<>|"
    val cleaned = name.codePoints().toArray().joinToString("") { point ->
        if (point in unsafe.map(Char::code) || Character.getType(point) in listOf(Character.CONTROL.toInt(), Character.FORMAT.toInt()))
            " " else String(Character.toChars(point))
    }.trim()
    return "${cleaned.ifEmpty { "Unnamed Character" }}.vtrcharacter"
}

fun copyName(name: String, taken: Set<String>): String {
    val base = name.ifEmpty { "Unnamed Character" }.replace(Regex(" \\(\\p{Nd}+\\)$"), "")
    var number = 1
    while ("$base ($number)" in taken) number++
    return "$base ($number)"
}
