package ie.requiem.sheet

import ie.requiem.rules.*
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.UUID

internal data class LibraryRow(
    val id: UUID, val name: String = "", val edited: Double? = null,
    val guided: Boolean = false, val problem: String? = null,
    val details: String = "",
)

internal data class OpenSheet(val file: File, val saved: CharacterSave, val text: String)

/** Used from one serialized writer. A session keeps the bytes it opened to detect stale writes. */
internal class CharacterFiles(private val directory: File, val catalog: Catalog) {
    private val codec = CharacterCodec(catalog)

    fun library(): List<LibraryRow> = files().map { (id, file) ->
        try {
            val c = read(id, file).saved
            val details = listOf(catalog.name(CatalogKind.clans, c.clan), catalog.name(CatalogKind.covenants, c.covenant))
                .filter { it.isNotBlank() }.joinToString(" · ")
            LibraryRow(id, c.name, c.modifiedAt, c.creation != null, details = details)
        } catch (e: UnsupportedSchema) {
            LibraryRow(id, problem = "Unsupported save version ${e.version}")
        } catch (_: Exception) {
            LibraryRow(id, problem = "Unreadable character file")
        }
    }.sortedWith(compareByDescending<LibraryRow> { it.edited }.thenBy { it.id })

    fun open(id: UUID): OpenSheet = read(id, files().first { it.first == id }.second)

    fun create(guided: Boolean = false): OpenSheet {
        val c = CharacterSave(creation = if (guided) CreationState() else null)
        val text = codec.encode(c)
        val file = File(directory, "${c.id}.json")
        check(!file.exists())
        write(file, text)
        return OpenSheet(file, codec.decode(text), text)
    }

    fun persist(session: OpenSheet, edited: CharacterSave): OpenSheet {
        val text = codec.encodeEdit(session.saved, edited, (System.currentTimeMillis() - 978_307_200_000L) / 1000.0)
            ?: return session
        check(session.file.readText() == session.text) { "The file changed after it was opened" }
        val saved = codec.decode(text)
        write(session.file, text)
        return OpenSheet(session.file, saved, text)
    }

    fun delete(id: UUID) {
        val session = open(id)
        Files.delete(session.file.toPath())
    }

    private fun read(id: UUID, file: File): OpenSheet {
        val text = file.readText()
        val c = codec.decode(text, fileId = id)
        require(c.id == id) { "Character ID does not match its file" }
        return OpenSheet(file, c, text)
    }

    private fun files(): List<Pair<UUID, File>> {
        if (!directory.exists()) return emptyList()
        return (directory.listFiles() ?: throw IOException("Cannot read the character directory")).mapNotNull {
            if (!it.isFile || it.extension != "json") return@mapNotNull null
            val id = runCatching { UUID.fromString(it.nameWithoutExtension) }.getOrNull()
            if (id == null || !id.toString().equals(it.nameWithoutExtension, ignoreCase = true)) null else id to it
        }
    }

    private fun write(file: File, text: String) {
        Files.createDirectories(directory.toPath())
        val temp = File.createTempFile(".sheet-", ".tmp", directory)
        try {
            FileOutputStream(temp).use { it.write(text.toByteArray(Charsets.UTF_8)); it.fd.sync() }
            Files.move(temp.toPath(), file.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } finally { temp.delete() }
    }
}
