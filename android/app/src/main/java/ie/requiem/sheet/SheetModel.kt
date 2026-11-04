package ie.requiem.sheet

import android.app.Application
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
)

internal class SheetModel(app: Application, private val restored: SavedStateHandle) : AndroidViewModel(app) {
    private val files by lazy { CharacterFiles(File(app.filesDir, "Characters"), Catalog.bundled()) }
    val catalog: Catalog get() = files.catalog
    private val state = MutableStateFlow(Screen())
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
                screen = Screen(rows = rows, busy = false)
                restored.get<String>("openId")?.let { open(UUID.fromString(it)) }
            } catch (e: Exception) { failure("Could not load the library", e) }
        }
    }

    fun refresh() = libraryAction("Could not reload the library") { null }
    fun create() = libraryAction("Could not create the character") { files.create() }
    fun open(id: UUID) = libraryAction("Could not open the character") { files.open(id) }
    fun delete(id: UUID) = libraryAction("Could not delete the character") { files.delete(id); null }

    private fun libraryAction(message: String, operation: () -> OpenSheet?) {
        if (screen.busy || screen.character != null) return
        screen = screen.copy(busy = true, error = null)
        viewModelScope.launch {
            try {
                val opened = withContext(Dispatchers.IO) { operation() }
                if (opened == null) showLibrary() else {
                    session = opened
                    restored["openId"] = opened.saved.id.toString()
                    screen = screen.copy(character = opened.saved, busy = false, saveFailed = false, overdraft = 0)
                }
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

    private suspend fun showLibrary() {
        val rows = withContext(Dispatchers.IO) { files.library() }
        restored.remove<String>("openId")
        session = null
        screen = Screen(rows = rows, busy = false)
    }

    private fun failure(message: String, e: Exception) {
        if (e is CancellationException) throw e
        screen = screen.copy(busy = false, error = "$message. ${e.localizedMessage.orEmpty()}")
    }
}
