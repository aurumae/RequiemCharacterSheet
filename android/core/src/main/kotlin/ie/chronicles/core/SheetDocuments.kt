package ie.chronicles.core

import java.util.Locale
import java.util.UUID
import kotlinx.serialization.json.*

interface StoredCharacter {
    val id: UUID
    val name: String
    val modifiedAt: Double
}

interface SheetCodec<C : StoredCharacter> {
    val currentSchema: Int
    fun requireGame(fields: JsonObject)
    fun decode(text: String, fileId: UUID? = null): C
    fun encode(character: C): String
    fun encodeEdit(original: C, edited: C, at: Double): String?
}

class UnsupportedSchema(val version: Int) : IllegalArgumentException("Unsupported character schema $version")
class UnsupportedGame(val game: String) : IllegalArgumentException(
    "This character is from another game. Open it in that game's app."
)

class CharacterDocumentError(message: String) : IllegalArgumentException(message)

/** A validated transfer file. Its original representation is retained, including unknown fields. */
data class CharacterDocument<C>(val bytes: ByteArray, val character: C)

open class SheetDocuments<C : StoredCharacter>(private val codec: SheetCodec<C>) {

    fun read(bytes: ByteArray): CharacterDocument<C> {
        try {
            val text = bytes.decodeToString(throwOnInvalidSequence = true)
            val objectValue = Json.parseToJsonElement(text) as? JsonObject ?: throw IllegalArgumentException()
            codec.requireGame(objectValue)
            val version = objectValue["schemaVersion"] as? JsonPrimitive
            if (version?.isString == false && (version.longOrNull ?: 0) > codec.currentSchema) {
                throw CharacterDocumentError("This character was saved by a newer version of the app. Update the app to open it.")
            }
            require((objectValue["name"] as? JsonPrimitive)?.isString == true)
            val character = codec.decode(text)
            // Older saves gain a stable identity once, before a pending import can be restored.
            val stored = if (objectValue["id"] == null || objectValue["id"] == JsonNull)
                codec.encode(character).toByteArray(Charsets.UTF_8) else bytes.copyOf()
            return CharacterDocument(stored, character)
        } catch (e: UnsupportedGame) {
            throw CharacterDocumentError(requireNotNull(e.message))
        } catch (e: CharacterDocumentError) {
            throw e
        } catch (_: Exception) {
            throw CharacterDocumentError("The file isn't a character file, or it's damaged.")
        }
    }

    /** Like iOS, compare the decoded saved state, ignoring only its edited date. */
    fun equivalent(a: C, b: C): Boolean = comparable(a) == comparable(b)

    private fun comparable(c: C): Map<String, JsonElement> =
        Json.parseToJsonElement(codec.encode(c)).jsonObject - "modifiedAt"

    fun copy(document: CharacterDocument<C>, takenNames: Set<String>): CharacterDocument<C> {
        val fields = Json.parseToJsonElement(document.bytes.decodeToString()).jsonObject.toMutableMap()
        fields["id"] = JsonPrimitive(UUID.randomUUID().toString().uppercase(Locale.ROOT))
        fields["name"] = JsonPrimitive(copyName(document.character.name, takenNames))
        return read(JsonObject(fields).toString().toByteArray(Charsets.UTF_8))
    }
}

fun characterFileName(name: String, extension: String): String {
    val unsafe = "/\\:*?\"<>|"
    val cleaned = name.codePoints().toArray().joinToString("") { point ->
        if (point in unsafe.map(Char::code) || Character.getType(point) in listOf(Character.CONTROL.toInt(), Character.FORMAT.toInt()))
            " " else String(Character.toChars(point))
    }.trim()
    return "${cleaned.ifEmpty { "Unnamed Character" }}.$extension"
}

fun copyName(name: String, taken: Set<String>): String {
    val base = name.ifEmpty { "Unnamed Character" }.replace(Regex(" \\(\\p{Nd}+\\)$"), "")
    var number = 1
    while ("$base ($number)" in taken) number++
    return "$base ($number)"
}
