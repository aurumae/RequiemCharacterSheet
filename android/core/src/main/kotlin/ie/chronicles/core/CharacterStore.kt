package ie.chronicles.core

import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.UUID

data class LibraryRow(
    val id: UUID, val name: String = "", val edited: Double? = null,
    val guided: Boolean = false, val problem: String? = null,
    val details: String = "",
)

data class OpenSheet<C>(val file: File, val saved: C, val text: String)
data class CharacterExport(val fileName: String, val bytes: ByteArray)
data class PendingImport<C>(
    val document: CharacterDocument<C>, val existing: LibraryRow?, val identical: Boolean,
    val existingFile: File?, val existingBytes: ByteArray?,
)

/** Used from one serialized writer. A session keeps the bytes it opened to detect stale writes. */
class CharacterStore<C : StoredCharacter>(
    private val directory: File,
    private val codec: SheetCodec<C>,
    val extension: String,
    private val blank: (guided: Boolean) -> C,
    private val summarize: (C) -> LibraryRow,
) {
    private val documents = SheetDocuments(codec)

    fun library(): List<LibraryRow> = files().map { (id, file) ->
        val saved = runCatching { read(id, file).saved }
        summary(id, saved)
    }.sortedWith(compareByDescending<LibraryRow> { it.edited }.thenBy { it.id })

    private fun summary(id: UUID, saved: Result<C>): LibraryRow = saved.mapCatching(summarize).getOrElse { error ->
        val problem = when (error) {
            is UnsupportedGame -> error.message
            is UnsupportedSchema -> "Unsupported save version ${error.version}"
            is Exception -> "Unreadable character file"
            else -> throw error
        }
        LibraryRow(id, problem = problem)
    }

    fun open(id: UUID): OpenSheet<C> = read(id, files().first { it.first == id }.second)

    fun create(guided: Boolean = false): OpenSheet<C> {
        val c = blank(guided)
        val text = codec.encode(c)
        val file = File(directory, "${c.id}.json")
        check(!file.exists())
        write(file, text)
        return OpenSheet(file, codec.decode(text), text)
    }

    fun persist(session: OpenSheet<C>, edited: C): OpenSheet<C> {
        val text = codec.encodeEdit(session.saved, edited, foundationNow())
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

    fun export(id: UUID): CharacterExport {
        val file = files().first { it.first == id }.second
        val bytes = file.readBytes()
        val saved = read(id, file, bytes.decodeToString(throwOnInvalidSequence = true)).saved
        return CharacterExport(characterFileName(saved.name, extension), bytes)
    }

    fun prepareImport(bytes: ByteArray): PendingImport<C> {
        val document = documents.read(bytes)
        val id = document.character.id
        val matching = files().filter { it.first == id }
        check(matching.size <= 1) { "More than one saved file has this character's identity." }
        val file = matching.singleOrNull()?.second ?: return PendingImport(document, null, false, null, null)
        // Show and compare the same bytes that Replace will check again at commit.
        val existingBytes = file.readBytes()
        val saved = runCatching { read(id, file, existingBytes.decodeToString(throwOnInvalidSequence = true)).saved }
        val identical = saved.getOrNull()?.let { documents.equivalent(it, document.character) } ?: false
        return PendingImport(document, summary(id, saved), identical, file, existingBytes)
    }

    /** Prepare the exact copy before writing, so a pending import can be journalled safely. */
    fun keepBoth(pending: PendingImport<C>): PendingImport<C> = prepareImport(
        documents.copy(pending.document, library().map { it.name }.toSet()).bytes)

    /** The caller obtains explicit Replace consent for an existing, different character. */
    fun importCharacter(pending: PendingImport<C>): OpenSheet<C> {
        val id = pending.document.character.id
        val file = pending.existingFile ?: File(directory, "$id.json")
        check(if (pending.existingBytes == null) files().none { it.first == id }
            else file.exists() && file.readBytes().contentEquals(pending.existingBytes)) {
            "This character changed while the import was open. Import the file again to compare the latest copy."
        }
        if (!pending.identical) write(file, pending.document.bytes)
        return read(id, file)
    }

    private fun read(id: UUID, file: File, text: String = file.readBytes().decodeToString(throwOnInvalidSequence = true)): OpenSheet<C> {
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

    private fun write(file: File, text: String) = write(file, text.toByteArray(Charsets.UTF_8))

    private fun write(file: File, bytes: ByteArray) {
        Files.createDirectories(directory.toPath())
        val temp = File.createTempFile(".sheet-", ".tmp", directory)
        try {
            FileOutputStream(temp).use { it.write(bytes); it.fd.sync() }
            Files.move(temp.toPath(), file.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } finally { temp.delete() }
    }
}
