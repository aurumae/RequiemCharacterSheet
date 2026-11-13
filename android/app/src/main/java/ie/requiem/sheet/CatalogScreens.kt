package ie.requiem.sheet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import ie.requiem.rules.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun EntryPicker(kind: EntryKind, c: CharacterSave, catalog: Catalog, choosingMystery: Boolean,
    choose: (BookEntry) -> Unit, custom: () -> Unit, none: () -> Unit, dismiss: () -> Unit) {
    var search by rememberSaveable { mutableStateOf("") }
    val sections = remember(c, kind, catalog, search, choosingMystery) { c.catalogSections(kind, catalog, search, choosingMystery) }
    val title = if (choosingMystery) "Choose Mystery" else "Add ${kind.title}"
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Color.White) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).imePadding()) {
            ModalHeading(title, "Cancel", dismiss)
            OutlinedTextField(value = search, onValueChange = { search = it }, singleLine = true,
                label = { SheetText(if (choosingMystery) "Search Mysteries" else "Search ${kind.title}s") },
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done), modifier = Modifier.fillMaxWidth().testTag("catalog-search"))
            LazyColumn(Modifier.weight(1f, fill = false).testTag("catalog-options")) {
                item { TextButton(onClick = custom, modifier = Modifier.fillMaxWidth()) { SheetText(if (choosingMystery) "Custom Mystery" else "Custom ${kind.title}") } }
                if (choosingMystery) item { TextButton(onClick = none, modifier = Modifier.fillMaxWidth()) { SheetText("None") } }
                if (sections.isEmpty()) item { SheetText("No matching entries", Modifier.padding(16.dp)) }
                sections.forEach { section ->
                    item("group-${section.id}") { CatalogSectionHeading(section.book, section.title) }
                    items(section.entries, key = { "${section.id}/${it.entry.id}" }) { option ->
                        Column(Modifier.fillMaxWidth().clickable(enabled = !option.owned && option.blockedReason == null) { choose(option.entry) }
                            .testTag("catalog-${option.entry.id}").padding(vertical = 12.dp)
                            .semantics(mergeDescendants = true) { stateDescription = if (option.owned) "Already on the sheet" else option.blockedReason.orEmpty() }) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                SheetText(option.title, Modifier.weight(1f), style = LocalSheetType.current.trait)
                                if (option.owned) SheetText("✓", Modifier.clearAndSetSemantics {}, color = SheetColors.accent)
                            }
                            option.details.forEach { detail -> SheetText(detail,
                                if (kind == EntryKind.Merit) Modifier.clearAndSetSemantics { contentDescription = option.entry.ratingsDescription() } else Modifier,
                                style = if (kind == EntryKind.Merit) MaterialTheme.typography.bodyLarge else MaterialTheme.typography.bodySmall, color = SheetColors.accent) }
                            if (option.entry.summary.isNotBlank()) SheetText(option.entry.summary, style = MaterialTheme.typography.bodySmall)
                            option.blockedReason?.let { WarningText(it) } ?: option.warning?.let { WarningText(it) }
                            SheetText(option.entry.citation, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                        }
                        SheetRule()
                    }
                }
                item { Spacer(Modifier.height(16.dp)) }
            }
        }
    }
}

@Composable internal fun CatalogSectionHeading(book: String?, title: String) {
    if (book != null) SheetText(book, Modifier.fillMaxWidth().padding(top = 20.dp, bottom = 6.dp).semantics { heading() },
        style = LocalSheetType.current.trait, color = SheetColors.accent)
    if (title.isNotBlank()) SubsectionLabel(title)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun EntryDetailSheet(detail: BookDetail, dismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Color.White) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
            ModalHeading(detail.title, "Done", dismiss)
            LazyColumn(Modifier.testTag("entry-details")) {
                item {
                    if (detail.summary.isNotBlank()) SheetText(detail.summary, Modifier.padding(vertical = 8.dp))
                    SheetText(detail.citation, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    detail.warnings.forEach { WarningText(it) }
                    detail.facts.forEach { DetailFactRow(it) }
                    Spacer(Modifier.height(12.dp))
                }
                items(detail.blocks) { block ->
                    Column(Modifier.fillMaxWidth().alpha(if (block.learned) 1f else .7f).padding(vertical = 12.dp)
                        .semantics(mergeDescendants = true) { stateDescription = if (block.learned) "Learned" else "Not learned" }) {
                        Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            SheetText(block.title, Modifier.weight(1f), style = LocalSheetType.current.trait)
                            SheetText(block.dots, color = SheetColors.accent, style = MaterialTheme.typography.bodySmall)
                        }
                        if (block.summary.isNotEmpty()) SheetText(block.summary, Modifier.padding(top = 4.dp))
                        block.facts.forEach { DetailFactRow(it) }
                    }
                    SheetRule()
                }
                item { Spacer(Modifier.height(16.dp)) }
            }
        }
    }
}

@Composable
internal fun ModalHeading(title: String, action: String, onAction: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        SheetText(title, Modifier.weight(1f).semantics { heading() }, style = LocalSheetType.current.section)
        TextButton(onClick = onAction) { SheetText(action) }
    }
}
@Composable private fun DetailFactRow(fact: DetailFact) {
    Column(Modifier.fillMaxWidth().padding(vertical = 5.dp)) {
        SheetText(fact.label, style = MaterialTheme.typography.labelMedium, color = SheetColors.muted)
        SheetText(fact.value, style = MaterialTheme.typography.bodyMedium)
    }
}
@Composable internal fun WarningText(text: String) {
    SheetText(text, Modifier.padding(vertical = 4.dp), style = MaterialTheme.typography.bodySmall, color = SheetColors.accent)
}
