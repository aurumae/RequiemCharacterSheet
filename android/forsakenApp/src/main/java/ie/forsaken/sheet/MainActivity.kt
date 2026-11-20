package ie.forsaken.sheet

import android.app.Application
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.DpSize
import androidx.core.content.FileProvider
import androidx.lifecycle.SavedStateHandle
import ie.chronicles.ui.*
import ie.forsaken.rules.*
import java.io.File

class MainActivity : ComponentActivity() {
    private val model: PreviewModel by viewModels()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT))
        if (savedInstanceState == null) intent.characterImportUri()?.let(model::enqueueImport)
        setContent { ForsakenTheme { LaunchWithDarkPack { ForsakenPreview(model) } } }
    }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); intent.characterImportUri()?.let(model::enqueueImport) }
    override fun onStop() { super.onStop(); model.flush() }
}

class CharacterShareProvider : FileProvider(R.xml.character_share_paths)

class PreviewModel(app: Application, restored: SavedStateHandle) : SheetLibraryModel<ForsakenCharacter>(
    app, restored, FORSAKEN_FILE_EXTENSION, { forsakenStore(File(app.filesDir, "characters")) },
) {
    val catalog = ForsakenCatalog.bundled
    internal val actions = ForsakenActions(catalog) { action ->
        updateCharacter({ ForsakenRules(it.state, catalog).experiencesAvailable }, action)
    }
}

@Composable
internal fun ForsakenTheme(content: @Composable () -> Unit) = ChroniclesTheme(
    SheetIdentity(Color(0xFF855A4A), Color(0xFFF1DDD4), R.font.grechen_fuemen, R.font.comforter,
        R.drawable.forsaken_logo, "Werewolf The Forsaken Second Edition", watermark = R.drawable.sheet_watermark,
        logoSize = DpSize(330.dp, 100.dp), compactLogoSize = DpSize(210.dp, 64.dp),
        typography = SheetTypography(labelFont = R.font.comforter, labelSize = 30, traitSize = 21, subheadingSize = 32,
            subheadingSpacing = 0f, traitNamesInAccent = false, controlUsesDisplay = true, controlSize = 21,
            libraryAboutUsesLabel = true, ratedTraitSize = 23, replaceNumerals = false)), content)

@Composable
internal fun ForsakenPreview(model: PreviewModel) {
    CharacterLibraryHost(model, MainActivity::class.java, sections = { ForsakenSection.available(it.state, model.catalog) },
        title = { it.title }, xp = { c, interactive ->
            if (c.state.creation == null) XpBadge(c.state.xpMode, ForsakenRules(c.state, model.catalog).experiencesAvailable, interactive) {
                model.actions.change { it.copy(xpMode = !it.xpMode) }
            }
        }, aboutSheet = { AboutSheet(it) }, allowGuidedCreation = false, characterReadOnly = { it.state.creation != null },
        libraryHeader = { ForsakenLibraryHeading() },
        compactWhileTyping = true,
        libraryNotice = "Guided creation is coming later. Imported creation sheets are read-only.",
    ) { c, busy, section, report, handled ->
        if (c.state.creation != null) PreviewSheet(c, model.catalog, section, report, handled)
        else ForsakenSheet(c, model.actions, !busy, section, report, handled)
    }
}
