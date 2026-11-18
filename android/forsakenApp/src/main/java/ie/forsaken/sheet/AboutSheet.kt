package ie.forsaken.sheet

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import ie.chronicles.ui.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun AboutSheet(dismiss: () -> Unit) {
    var page by rememberSaveable { mutableStateOf("about") }
    val resources = LocalResources.current
    val license = remember(resources, page) {
        val id = when (page) { "Comforter" -> R.raw.comforter_ofl; "Grechen Fuemen" -> R.raw.grechen_fuemen_ofl; else -> null }
        id?.let { resources.openRawResource(it).bufferedReader().use { reader -> reader.readText().split(Regex("\n\\s*\n")) } }.orEmpty()
    }
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Color.White) {
        BackHandler(enabled = page != "about") { page = "about" }
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                SheetText(if (page == "about") "About this app" else page, Modifier.weight(1f).semantics { heading() },
                    style = MaterialTheme.typography.titleLarge, color = SheetColors.accent)
                TextButton(onClick = dismiss) { SheetText("Done") }
            }
            if (page != "about") TextButton(onClick = { page = "about" }) { SheetText("Back to About") }
            LazyColumn(Modifier.testTag("about-content"), contentPadding = PaddingValues(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                when (page) {
                    "about" -> {
                        item { SheetText("Forsaken Character Sheet", style = MaterialTheme.typography.titleLarge, color = SheetColors.accent) }
                        item { SheetText("Android preview ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})") }
                        item { SheetText("Read-only character viewer. Import an iOS character, read its saved traits and catalog rules, and export it unchanged. Editing and calculated totals are not available yet.") }
                        item { TextButton(onClick = { page = "Dark Pack" }) { SheetText("Dark Pack · Legal notice") } }
                        item { SheetText("Fonts", style = MaterialTheme.typography.titleMedium, color = SheetColors.accent) }
                        for (name in listOf("Comforter", "Grechen Fuemen")) item {
                            TextButton(onClick = { page = name }) { SheetText("$name · SIL Open Font License 1.1") }
                        }
                        item { SheetText("Section headings lettered in Flat Earth Scribe by Nate Piekos of Blambot, used under licence.") }
                    }
                    "Dark Pack" -> {
                        item { Image(painterResource(R.drawable.dark_pack), "Dark Pack logo", Modifier.size(150.dp)) }
                        item { SelectionContainer { SheetText(stringResource(R.string.dark_pack_copyright)) } }
                        item { SelectionContainer { SheetText(stringResource(R.string.dark_pack_disclaimer)) } }
                    }
                    else -> items(license) { paragraph -> SelectionContainer { SheetText(paragraph, style = MaterialTheme.typography.bodySmall) } }
                }
            }
        }
    }
}
