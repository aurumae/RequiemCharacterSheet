package ie.requiem.sheet

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.Composable
import ie.chronicles.ui.*
import ie.requiem.rules.SheetEdit

class MainActivity : ComponentActivity() {
    private val model: SheetModel by viewModels()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The reference is a light paper sheet, including when the device is in dark mode.
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT))
        val sheetModel = model
        if (savedInstanceState == null) intent.characterImportUri()?.let(sheetModel::enqueueImport)
        setContent { SheetTheme { LaunchWithDarkPack { Requiem(sheetModel) } } }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // The model owns pending transfers; retain the launch intent for activity recreation.
        intent.characterImportUri()?.let(model::enqueueImport)
    }
    override fun onStop() { super.onStop(); model.flush() }
}

@Composable
private fun Requiem(model: SheetModel) {
    CharacterLibraryHost(model, MainActivity::class.java, sections = { SheetSection.available(it, model.catalog) },
        title = { it.title }, xp = { c, enabled ->
            if (c.creation == null) XpBadge(c.xpMode, c.experiencesAvailable, enabled) { model.edit(SheetEdit.XpMode(!c.xpMode)) }
        }, aboutSheet = { AboutSheet(it) }) { c, busy, section, report, handled ->
        SheetEditor(c, model.catalog, busy, model::edit, section, report, handled)
    }
}
