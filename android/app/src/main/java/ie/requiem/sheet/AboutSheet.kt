package ie.requiem.sheet

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun AboutSheet(dismiss: () -> Unit) {
    var page by rememberSaveable { mutableStateOf("about") }
    val title = when (page) { "dark-pack" -> "Dark Pack"; "fell" -> "IM Fell English"; "cinzel" -> "Cinzel"; else -> "About this app" }
    val resources = LocalResources.current
    val paragraphs = remember(page, resources) {
        val resource = when (page) { "fell" -> R.raw.im_fell_english_ofl; "cinzel" -> R.raw.cinzel_ofl; else -> null }
        resource?.let { resources.openRawResource(it).bufferedReader().use { reader -> licenceParagraphs(reader.readText()) } }.orEmpty()
    }
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Color.White) {
        // Register inside the dialog so Back navigates a licence before closing About.
        BackHandler(enabled = page != "about") { page = "about" }
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
            ModalHeading(title, "Done", dismiss)
            if (page != "about") TextButton(onClick = { page = "about" }) { SheetText("Back to About") }
            LazyColumn(Modifier.testTag("about-content"), contentPadding = PaddingValues(bottom = 24.dp)) {
                when (page) {
                    "about" -> {
                        item { SheetText(stringResource(R.string.app_name), style = LocalSheetType.current.label) }
                        item { SheetText("Version ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})", Modifier.padding(vertical = 8.dp), color = SheetColors.muted) }
                        item { SubsectionLabel("Licences") }
                        item { AboutLink("Dark Pack", "Legal notice and unofficial fan content") { page = "dark-pack" } }
                        item { SubsectionLabel("Fonts") }
                        item { AboutLink("IM Fell English", "Igino Marini · SIL Open Font License 1.1") { page = "fell" } }
                        item { AboutLink("Cinzel", "Natanael Gama and the Cinzel Project Authors · SIL Open Font License 1.1") { page = "cinzel" } }
                    }
                    "dark-pack" -> {
                        item { Image(painterResource(R.drawable.dark_pack), "Dark Pack logo", Modifier.padding(vertical = 12.dp).size(150.dp)) }
                        item { SelectionContainer { SheetText(stringResource(R.string.dark_pack_copyright), Modifier.padding(vertical = 8.dp)) } }
                        item { SelectionContainer { SheetText(stringResource(R.string.dark_pack_disclaimer), Modifier.padding(vertical = 8.dp)) } }
                    }
                    else -> itemsIndexed(paragraphs) { _, paragraph ->
                        val isHeading = paragraph.length < 45 && paragraph == paragraph.uppercase() && paragraph.any { it.isLetter() }
                        SelectionContainer {
                            SheetText(paragraph, Modifier.fillMaxWidth().padding(vertical = 8.dp).semantics { if (isHeading) heading() },
                                style = if (isHeading) MaterialTheme.typography.titleSmall else MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AboutLink(title: String, subtitle: String, open: () -> Unit) {
    Column(Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = open).padding(vertical = 12.dp).semantics(mergeDescendants = true) {}) {
        SheetText(title, style = LocalSheetType.current.trait)
        SheetText(subtitle, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
    }
    SheetRule()
}

// Preserve licence headings even when the source places their body on the next line.
private fun licenceParagraphs(text: String): List<String> = buildList {
    val lines = mutableListOf<String>()
    fun flush() { if (lines.isNotEmpty()) { add(lines.joinToString(" ")); lines.clear() } }
    text.lineSequence().forEach { raw ->
        val line = raw.trim()
        when {
            line.isEmpty() || line.all { it == '-' } -> flush()
            line.length < 45 && line == line.uppercase() && line.any { it.isLetter() } -> { flush(); add(line) }
            else -> lines.add(line)
        }
    }
    flush()
}
