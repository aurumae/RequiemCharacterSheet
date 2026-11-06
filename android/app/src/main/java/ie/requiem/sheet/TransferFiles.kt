package ie.requiem.sheet

import android.content.ClipData
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.AtomicFile
import androidx.core.content.FileProvider
import ie.requiem.rules.CharacterDocumentError
import java.io.File
import java.io.IOException
import java.util.UUID

internal enum class ExportMode { Share, Save }
internal data class ExportRequest(val file: File, val name: String, val mode: ExportMode)
internal data class TransferError(val title: String, val message: String)

/** Only export snapshots are exposed; character storage and the import journal remain private. */
class CharacterShareProvider : FileProvider(R.xml.character_share_paths)

internal class TransferFiles(private val context: Context) {
    private val pending = AtomicFile(File(context.noBackupFilesDir, "pending-character-import.vtrcharacter"))
    private val exports = File(context.cacheDir, "character-exports")

    fun read(uri: Uri): ByteArray {
        require(uri.scheme == "content") { "Choose a file using Import Character, or share it from your file manager." }
        val input = context.contentResolver.openInputStream(uri) ?: throw IOException("The file could not be opened.")
        return input.use {
            val limit = 32 * 1024 * 1024
            val bytes = it.readNBytes(limit + 1)
            if (bytes.size > limit) throw CharacterDocumentError("This character file is too large to import (maximum 32 MB).")
            bytes
        }
    }

    fun pendingBytes(): ByteArray? = if (pending.baseFile.exists() || File(pending.baseFile.path + ".bak").exists())
        pending.readFully() else null

    fun stage(bytes: ByteArray) {
        val stream = pending.startWrite()
        try { stream.write(bytes); pending.finishWrite(stream) }
        catch (e: Exception) { pending.failWrite(stream); throw e }
    }

    fun clearPending() = pending.delete()

    fun snapshot(data: CharacterExport, mode: ExportMode): ExportRequest {
        // Keep recent snapshots alive while another app or the document picker reads them.
        exports.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 7 * 86_400_000L }
            ?.forEach { it.deleteRecursively() }
        val directory = File(exports, UUID.randomUUID().toString())
        check(directory.mkdirs()) { "Could not prepare the exported file." }
        // The displayed filename is separate so long character names cannot exceed a filesystem limit.
        val file = File(directory, "character.vtrcharacter")
        file.writeBytes(data.bytes)
        return ExportRequest(file, data.fileName, mode)
    }

    fun save(request: ExportRequest, destination: Uri) {
        val output = context.contentResolver.openOutputStream(destination, "wt")
            ?: throw IOException("The selected location could not be opened.")
        output.use { target -> request.file.inputStream().use { it.copyTo(target) } }
    }
}

internal fun characterShareIntent(context: Context, request: ExportRequest): Intent {
    val uri = FileProvider.getUriForFile(context, "${context.packageName}.characterfiles", request.file, request.name)
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "application/octet-stream"
        putExtra(Intent.EXTRA_STREAM, uri)
        clipData = ClipData.newRawUri(request.name, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    return Intent.createChooser(send, "Export character").apply {
        putExtra(Intent.EXTRA_EXCLUDE_COMPONENTS, arrayOf(ComponentName(context, MainActivity::class.java)))
    }
}

internal fun Intent.characterImportUri(): Uri? = when (action) {
    Intent.ACTION_SEND -> getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java) ?: clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
    Intent.ACTION_VIEW -> data
    else -> null
}
