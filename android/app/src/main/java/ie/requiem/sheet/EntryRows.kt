package ie.requiem.sheet

import ie.chronicles.ui.*

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import ie.requiem.rules.*

@Composable
internal fun PowerEntryRow(kind: EntryKind, row: SheetEntry, editable: Boolean, edit: (SheetEdit) -> Unit,
    open: () -> Unit, editQualifier: (() -> Unit)?, remove: () -> Unit) {
    val rating = row.rating
    var menu by remember { mutableStateOf(false) }
    var ratings by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().background(Color.White)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
            Box(Modifier.weight(1f)) {
                if (rating != null && row.choices.isNotEmpty()) TraitRatingControl(row.name.ifBlank { kind.title }, rating, row.bonus,
                    row.choices.first()..row.choices.last(), editable, allowedValues = row.choices,
                    reserveFiveDots = kind == EntryKind.Merit, onNameClick = if (row.known || editable) open else null, visibleCap = row.visibleDots) {
                    edit(SheetEdit.EntryRating(kind, row.id, it))
                } else Row(Modifier.fillMaxWidth().clickable(enabled = row.known || editable, onClick = open).heightIn(min = 48.dp).padding(8.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    SheetText(row.name.ifBlank { "Tap to edit ${kind.title}" }, Modifier.weight(1f), style = LocalSheetType.current.trait)
                    row.rating?.let { SheetText("•".repeat(it.coerceIn(0, 10)), color = SheetColors.accent, style = MaterialTheme.typography.bodySmall) }
                }
            }
            Box {
                IconButton(onClick = { menu = true }, modifier = Modifier.semantics { contentDescription = "Options for ${row.name.ifBlank { kind.title }}" }) { SheetIcon(SheetSymbol.More, SheetColors.muted) }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    if (row.known || editable) DropdownMenuItem(text = { SheetText(if (row.known) "Details" else "Edit") }, onClick = { menu = false; open() })
                    if (editable && row.choices.isNotEmpty()) DropdownMenuItem(text = { SheetText("Set rating") }, onClick = { menu = false; ratings = true })
                    if (editable && editQualifier != null) DropdownMenuItem(text = { SheetText("Edit qualifier") }, onClick = { menu = false; editQualifier() })
                    if (editable) DropdownMenuItem(text = { SheetText("Delete") }, onClick = { menu = false; remove() })
                }
                DropdownMenu(expanded = ratings && editable, onDismissRequest = { ratings = false }) {
                    row.choices.forEach { value -> DropdownMenuItem(text = { SheetText(value.toString()) }, onClick = { ratings = false; edit(SheetEdit.EntryRating(kind, row.id, value)) }) }
                }
            }
        }
        Column(Modifier.padding(horizontal = 8.dp)) {
            if (kind == EntryKind.Bane && row.known) {
                SheetText(row.summary, style = MaterialTheme.typography.bodySmall)
                SheetText(row.citation, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
            }
            row.notes.forEach { SheetText(it, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted) }
            row.warnings.forEach { WarningText(it) }
        }
        SheetRule()
    }
}

@Composable
internal fun AddSheetRow(title: String, enabled: Boolean, click: () -> Unit) {
    Row(Modifier.fillMaxWidth().background(Color.White).clickable(enabled = enabled, onClick = click).heightIn(min = 52.dp).padding(8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        SheetIcon(SheetSymbol.Add, if (enabled) SheetColors.accent else SheetColors.muted)
        SheetText(title, color = if (enabled) SheetColors.accent else SheetColors.muted)
    }
}

@Composable
internal fun WrittenRow(text: String, placeholder: String, editable: Boolean, description: String, open: () -> Unit, remove: () -> Unit) {
    var menu by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth().background(Color.White), verticalAlignment = Alignment.Top) {
        SheetText(text.ifBlank { placeholder }, Modifier.weight(1f).clickable(enabled = editable, onClick = open).heightIn(min = 56.dp).padding(8.dp)
            .semantics { contentDescription = description }, style = LocalSheetType.current.trait)
        if (editable) Box {
            IconButton(onClick = { menu = true }, modifier = Modifier.semantics { contentDescription = "Options for $description" }) { SheetIcon(SheetSymbol.More, SheetColors.muted) }
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                DropdownMenuItem(text = { SheetText("Edit") }, onClick = { menu = false; open() })
                DropdownMenuItem(text = { SheetText("Delete") }, onClick = { menu = false; remove() })
            }
        }
    }
    SheetRule()
}
