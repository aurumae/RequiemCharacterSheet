package ie.requiem.sheet

import ie.chronicles.ui.*

import android.app.Application
import android.net.Uri
import androidx.core.net.toUri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import ie.requiem.rules.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.File
import java.util.UUID

internal data class Screen(
    val rows: List<LibraryRow> = emptyList(), val character: CharacterSave? = null,
    val busy: Boolean = true, val saving: Boolean = false, val error: String? = null,
    val saveFailed: Boolean = false, val overdraft: Int = 0, val savedNotice: Int = 0,
    val incomingUri: String? = null, val pendingImport: PendingImport? = null,
    val exportRequest: ExportRequest? = null, val transferError: TransferError? = null,
    val transferNotice: Int = 0, val awaitingDestination: Boolean = false,
)

internal class SheetModel(app: Application, private val restored: SavedStateHandle) : AndroidViewModel(app) {
    private val files by lazy { CharacterFiles(File(app.filesDir, "Characters"), Catalog.bundled()) }
    private val transfers = TransferFiles(app)
    private val initialized = CompletableDeferred<Unit>()
    val catalog: Catalog get() = files.catalog
    private val state = MutableStateFlow(Screen(awaitingDestination = restored.contains("exportPath")))
    val ui = state.asStateFlow()
    private var screen: Screen
        get() = state.value
        set(value) { state.value = value }
    private var session: OpenSheet? = null
    private var writer: Job? = null

    init {
        viewModelScope.launch {
            try {
                val rows = withContext(Dispatchers.IO) { files.library() }
                screen = screen.copy(rows = rows)
                val pending = withContext(Dispatchers.IO) { transfers.pendingBytes() }
                if (pending != null) {
                    restored.remove<String>("activeImportUri")
                    restored.remove<String>("openId")
                    try { prepareImport(pending) }
                    catch (e: Exception) {
                        if (e is CancellationException) throw e
                        // A damaged journal is no longer a usable request. A valid pending
                        // character remains available for Retry if its final write failed.
                        if (screen.pendingImport == null) withContext(Dispatchers.IO) { transfers.clearPending() }
                        transferFailure("Could not restore character import", e)
                    }
                } else {
                    restored.get<String>("openId")?.let { id ->
                        opened(withContext(Dispatchers.IO) { files.open(UUID.fromString(id)) })
                    }
                    restored.remove<String>("activeImportUri")?.let { uri ->
                        restored["importQueue"] = arrayListOf(uri).apply { addAll(importQueue()) }
                    }
                }
                screen = screen.copy(busy = false, incomingUri = importQueue().firstOrNull())
            } catch (e: Exception) {
                restored.remove<String>("openId")
                failure("Could not restore the library or pending import", e)
            }
            finally { initialized.complete(Unit) }
        }
    }

    fun refresh() = libraryAction("Could not reload the library") { null }
    fun create(guided: Boolean = false) = libraryAction("Could not create the character") { files.create(guided) }
    fun open(id: UUID) = libraryAction("Could not open the character") { files.open(id) }
    fun delete(id: UUID) = libraryAction("Could not delete the character") { files.delete(id); null }

    private fun libraryAction(message: String, operation: () -> OpenSheet?) {
        if (screen.busy || screen.character != null || screen.pendingImport != null || screen.exportRequest != null || screen.awaitingDestination) return
        screen = screen.copy(busy = true, error = null)
        viewModelScope.launch {
            try {
                val result = withContext(Dispatchers.IO) { operation() }
                if (result == null) showLibrary() else opened(result)
            } catch (e: Exception) { restored.remove<String>("openId"); failure(message, e) }
        }
    }

    fun edit(action: SheetEdit) {
        val current = screen.character ?: return
        if (screen.busy) return
        val next = current.edit(action, catalog)
        if (next == current) return
        val crossed = current.experiencesAvailable >= 0 && next.experiencesAvailable < 0
        screen = screen.copy(character = next, overdraft = screen.overdraft + if (crossed) 1 else 0)
        if (!screen.saveFailed) flush()
    }

    // The UI applies a purchase exactly once. The writer only persists immutable snapshots;
    // while I/O is in flight, newer input stays in memory for the next pass.
    fun flush() {
        if (writer?.isActive == true || session == null) return
        writer = viewModelScope.launch {
            try {
                screen = screen.copy(saving = true, saveFailed = false, error = null)
                while (true) {
                    val opened = session ?: break
                    val pending = screen.character ?: break
                    if (pending === opened.saved) break
                    val result = withContext(Dispatchers.IO) { files.persist(opened, pending) }
                    session = result
                    if (screen.character === pending) screen = screen.copy(character = result.saved)
                }
            } catch (e: Exception) {
                failure("Changes have not been saved", e)
                screen = screen.copy(saveFailed = true)
            } finally { screen = screen.copy(saving = false) }
        }
    }

    fun close() {
        if (screen.busy || session == null) return
        screen = screen.copy(busy = true)
        viewModelScope.launch {
            flush()
            writer?.join()
            if (screen.saveFailed) { screen = screen.copy(busy = false); return@launch }
            try { showLibrary() } catch (e: Exception) { failure("Could not load the library", e) }
        }
    }

    fun save() {
        if (screen.busy || session == null) return
        viewModelScope.launch {
            flush()
            writer?.join()
            if (!screen.saveFailed) screen = screen.copy(savedNotice = screen.savedNotice + 1)
        }
    }

    private fun opened(value: OpenSheet) {
        session = value
        restored["openId"] = value.saved.id.toString()
        screen = screen.copy(character = value.saved, busy = false, saveFailed = false, error = null,
            overdraft = 0, savedNotice = 0, pendingImport = null)
    }

    private suspend fun showLibrary(busy: Boolean = false) {
        val rows = withContext(Dispatchers.IO) { files.library() }
        restored.remove<String>("openId")
        session = null
        screen = screen.copy(rows = rows, character = null, busy = busy, saving = false, error = null,
            saveFailed = false, overdraft = 0, savedNotice = 0)
    }

    private fun importQueue(): ArrayList<String> = restored["importQueue"] ?: arrayListOf()

    fun enqueueImport(uri: Uri) {
        val queue = ArrayList(importQueue()).apply { add(uri.toString()) }
        restored["importQueue"] = queue
        screen = screen.copy(incomingUri = queue.firstOrNull())
    }

    // Called after Compose clears focus, so a field's last uncommitted edit is included.
    fun startNextImport() {
        if (!initialized.isCompleted || screen.busy || screen.pendingImport != null || screen.transferError != null || screen.exportRequest != null || screen.awaitingDestination) return
        val queue = ArrayList(importQueue())
        val uri = queue.firstOrNull() ?: return
        queue.removeAt(0)
        restored["importQueue"] = queue
        restored["activeImportUri"] = uri
        screen = screen.copy(busy = true, incomingUri = queue.firstOrNull())
        viewModelScope.launch {
            try {
                flush()
                writer?.join()
                check(!screen.saveFailed) { "Save the open sheet successfully before importing a character." }
                showLibrary(busy = true)
                val bytes = withContext(Dispatchers.IO) { transfers.read(uri.toUri()) }
                prepareImport(bytes)
            } catch (e: Exception) {
                transferFailure("Could not import character", e)
            } finally { restored.remove<String>("activeImportUri") }
        }
    }

    private suspend fun prepareImport(bytes: ByteArray) {
        val pending = withContext(Dispatchers.IO) {
            files.prepareImport(bytes).also { transfers.stage(it.document.bytes) }
        }
        screen = screen.copy(pendingImport = pending)
        if (pending.existing == null || pending.identical) finishImport(pending)
        else screen = screen.copy(busy = false)
    }

    private suspend fun finishImport(pending: PendingImport) {
        val result = withContext(Dispatchers.IO) {
            files.importCharacter(pending).also { transfers.clearPending() }
        }
        opened(result)
    }

    fun resolveImport(keepBoth: Boolean) {
        val pending = screen.pendingImport ?: return
        if (screen.busy) return
        screen = screen.copy(busy = true)
        viewModelScope.launch {
            try {
                val chosen = if (keepBoth) withContext(Dispatchers.IO) {
                    // Journal the new identity before writing: recovery cannot create a second copy.
                    files.keepBoth(pending).also { transfers.stage(it.document.bytes) }
                } else pending
                screen = screen.copy(pendingImport = chosen)
                finishImport(chosen)
            } catch (e: Exception) { transferFailure("Could not import character", e) }
        }
    }

    fun retryImport() {
        if (screen.busy) return
        screen = screen.copy(busy = true, transferError = null)
        viewModelScope.launch {
            try {
                val bytes = withContext(Dispatchers.IO) { transfers.pendingBytes() }
                    ?: error("The pending file is no longer available. Choose it again using Import Character.")
                prepareImport(bytes)
            } catch (e: Exception) { transferFailure("Could not import character", e) }
        }
    }

    fun cancelImport() {
        if (screen.busy) return
        screen = screen.copy(busy = true)
        viewModelScope.launch {
            try {
                withContext(Dispatchers.IO) { transfers.clearPending() }
                screen = screen.copy(busy = false, pendingImport = null, transferError = null)
            } catch (e: Exception) { transferFailure("Could not cancel import", e) }
        }
    }

    fun export(id: UUID, mode: ExportMode) {
        if (screen.busy || screen.character != null || screen.pendingImport != null || screen.exportRequest != null || screen.awaitingDestination) return
        screen = screen.copy(busy = true)
        viewModelScope.launch {
            try {
                val request = withContext(Dispatchers.IO) { transfers.snapshot(files.export(id), mode) }
                screen = screen.copy(busy = false, exportRequest = request)
            } catch (e: Exception) { transferFailure("Could not export character", e) }
        }
    }

    fun exportLaunched(request: ExportRequest) {
        if (request.mode == ExportMode.Save) {
            restored["exportPath"] = request.file.path
            restored["exportName"] = request.name
        }
        screen = screen.copy(exportRequest = null, awaitingDestination = request.mode == ExportMode.Save)
    }

    fun saveExport(destination: Uri?) {
        val path = restored.remove<String>("exportPath") ?: return
        val name = restored.remove<String>("exportName") ?: "Character.vtrcharacter"
        screen = screen.copy(awaitingDestination = false)
        if (destination == null) return
        viewModelScope.launch {
            initialized.await()
            screen = screen.copy(busy = true)
            try {
                withContext(Dispatchers.IO) { transfers.save(ExportRequest(File(path), name, ExportMode.Save), destination) }
                screen = screen.copy(busy = false, transferNotice = screen.transferNotice + 1)
            } catch (e: Exception) { transferFailure("Could not save exported file", e) }
        }
    }

    fun exportFailure(e: Exception) {
        restored.remove<String>("exportPath")
        restored.remove<String>("exportName")
        screen = screen.copy(exportRequest = null, awaitingDestination = false)
        transferFailure("Could not export character", e)
    }

    fun dismissTransferError() { screen = screen.copy(transferError = null) }

    private fun transferFailure(title: String, e: Exception) {
        if (e is CancellationException) throw e
        screen = screen.copy(busy = false, transferError = TransferError(title, e.localizedMessage ?: "Please try again."))
    }

    private fun failure(message: String, e: Exception) {
        if (e is CancellationException) throw e
        screen = screen.copy(busy = false, error = "$message. ${e.localizedMessage.orEmpty()}")
    }
}
