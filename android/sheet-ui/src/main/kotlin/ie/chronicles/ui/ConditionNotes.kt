package ie.chronicles.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import ie.chronicles.core.*

data class NoteGroup(val title: String, val options: List<ConditionNoteOption>, val warning: String? = null)

@Composable
fun ConditionNoteMenu(prompt: String, note: String, groups: List<NoteGroup>, choose: (String) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        SheetText("$prompt:", Modifier.weight(1f), style = LocalSheetType.current.label)
        Box {
            TextButton(onClick = { open = true }, modifier = Modifier.semantics {
                contentDescription = prompt; stateDescription = note
            }) { SheetText(note.ifEmpty { "Choose" }) }
            DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                groups.forEach { group ->
                    if (group.title.isNotEmpty()) SheetText(listOfNotNull(group.title, group.warning).joinToString(" — "),
                        Modifier.padding(8.dp).semantics { heading() })
                    group.options.forEach { option ->
                        DropdownMenuItem(text = { SheetText(option.name) }, onClick = { open = false; choose(option.name) })
                    }
                }
            }
        }
    }
}

@Composable
fun ConditionNoteEffect(prompt: String, note: String, groups: List<NoteGroup>, source: BookSource?, books: Map<String, CatalogBook>) {
    val group = groups.firstOrNull { it.options.any { option -> option.name == note } }
    val option = group?.options?.firstOrNull { it.name == note }
    if (option == null) SheetText("Choose the ${prompt.lowercase()} for its effect.", color = SheetColors.muted)
    else {
        SheetText("${option.name}: ${option.summary}", style = MaterialTheme.typography.bodySmall)
        group.warning?.let { SheetText(it, color = SheetColors.accent) }
        option.source?.takeIf { it != source }?.let { SheetText(it.citation(books), color = SheetColors.muted) }
    }
}
