package ie.requiem.sheet

import android.content.Context
import ie.requiem.rules.REQUIEM_FILE_EXTENSION
import androidx.core.content.FileProvider

/** Only export snapshots are exposed. The library and import journal are private. */
class CharacterShareProvider : FileProvider(R.xml.character_share_paths)

internal typealias ExportMode = ie.chronicles.ui.ExportMode
internal fun TransferFiles(context: Context) = ie.chronicles.ui.TransferFiles(context, REQUIEM_FILE_EXTENSION)
