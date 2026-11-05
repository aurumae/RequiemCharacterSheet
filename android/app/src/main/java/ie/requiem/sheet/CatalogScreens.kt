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
    val options = remember(c, kind, catalog, search, choosingMystery) { c.catalogOptions(kind, catalog, search, choosingMystery) }
    val title = if (choosingMystery) "Choose Mystery" else "Add ${kind.title}"
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Color.White) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).imePadding()) {
            ModalHeading(title, "Cancel", dismiss)
            OutlinedTextField(value = search, onValueChange = { search = it }, singleLine = true,
                label = { Text(if (choosingMystery) "Search Mysteries" else "Search ${kind.title}s") },
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done), modifier = Modifier.fillMaxWidth().testTag("catalog-search"))
            LazyColumn(Modifier.weight(1f, fill = false).testTag("catalog-options")) {
                item { TextButton(onClick = custom, modifier = Modifier.fillMaxWidth()) { Text(if (choosingMystery) "Custom Mystery" else "Custom ${kind.title}") } }
                if (choosingMystery) item { TextButton(onClick = none, modifier = Modifier.fillMaxWidth()) { Text("None") } }
                if (options.isEmpty()) item { Text("No matching entries", Modifier.padding(16.dp)) }
                options.groupBy { it.group }.forEach { (group, rows) ->
                    item("group-$group") { SubsectionLabel(group) }
                    items(rows, key = { it.entry.id }) { option ->
                        Column(Modifier.fillMaxWidth().clickable(enabled = !option.owned && option.blockedReason == null) { choose(option.entry) }
                            .testTag("catalog-${option.entry.id}").padding(vertical = 12.dp)
                            .semantics(mergeDescendants = true) { stateDescription = if (option.owned) "Already on the sheet" else option.blockedReason.orEmpty() }) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(option.title, Modifier.weight(1f), style = LocalSheetType.current.trait)
                                if (option.owned) Text("✓", color = SheetColors.accent)
                            }
                            option.details.forEach { Text(it, style = MaterialTheme.typography.bodySmall, color = SheetColors.accent) }
                            if (option.entry.summary.isNotBlank()) Text(option.entry.summary, style = MaterialTheme.typography.bodySmall)
                            option.blockedReason?.let { WarningText(it) } ?: option.warning?.let { WarningText(it) }
                            Text(option.entry.citation, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                        }
                        SheetRule()
                    }
                }
                item { Spacer(Modifier.height(16.dp)) }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun EntryDetailSheet(detail: BookDetail, dismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Color.White) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
            ModalHeading(detail.title, "Done", dismiss)
            LazyColumn(Modifier.testTag("entry-details")) {
                item {
                    if (detail.summary.isNotBlank()) Text(detail.summary, Modifier.padding(vertical = 8.dp))
                    Text(detail.citation, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    detail.warnings.forEach { WarningText(it) }
                    detail.facts.forEach { DetailFactRow(it) }
                    Spacer(Modifier.height(12.dp))
                }
                items(detail.blocks) { block ->
                    Column(Modifier.fillMaxWidth().alpha(if (block.learned) 1f else .55f).padding(vertical = 12.dp)
                        .semantics(mergeDescendants = true) { stateDescription = if (block.learned) "Learned" else "Not learned" }) {
                        Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(block.title, Modifier.weight(1f), style = LocalSheetType.current.trait)
                            Text(block.dots, color = SheetColors.accent, style = MaterialTheme.typography.bodySmall)
                        }
                        if (block.summary.isNotEmpty()) Text(block.summary, Modifier.padding(top = 4.dp))
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
        Text(title, Modifier.weight(1f).semantics { heading() }, style = LocalSheetType.current.section)
        TextButton(onClick = onAction) { Text(action) }
    }
}
@Composable private fun DetailFactRow(fact: DetailFact) {
    Column(Modifier.fillMaxWidth().padding(vertical = 5.dp)) {
        Text(fact.label, style = MaterialTheme.typography.labelMedium, color = SheetColors.muted)
        Text(fact.value, style = MaterialTheme.typography.bodyMedium)
    }
}
@Composable internal fun WarningText(text: String) {
    Text(text, Modifier.padding(vertical = 4.dp), style = MaterialTheme.typography.bodySmall, color = SheetColors.accent)
}
