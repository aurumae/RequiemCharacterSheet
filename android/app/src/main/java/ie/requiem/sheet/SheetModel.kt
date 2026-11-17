package ie.requiem.sheet

import android.app.Application
import androidx.lifecycle.SavedStateHandle
import ie.chronicles.ui.SheetLibraryModel
import ie.requiem.rules.*
import java.io.File

internal typealias Screen = ie.chronicles.ui.LibraryScreen<CharacterSave>

internal class SheetModel private constructor(app: Application, restored: SavedStateHandle, books: Lazy<Catalog>) :
    SheetLibraryModel<CharacterSave>(app, restored, REQUIEM_FILE_EXTENSION,
        { CharacterFiles(File(app.filesDir, "Characters"), books.value) }) {
    constructor(app: Application, restored: SavedStateHandle) : this(app, restored, lazy { Catalog.bundled() })
    val catalog by books
    fun edit(action: SheetEdit) = updateCharacter({ it.experiencesAvailable }) { it.edit(action, catalog) }
}
