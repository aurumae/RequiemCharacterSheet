package ie.chronicles.ui

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.*
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@Composable
fun SheetFieldRow(rowId: String, label: String, spokenLabel: String, value: String, editable: Boolean, onEdit: (String) -> Unit) {
    var draft by rememberSaveable(rowId) { mutableStateOf(value) }
    var focused by remember { mutableStateOf(false) }
    // Keep the player's spelling/cursor while typing. The saved source may resolve to a
    // book entry immediately; show its canonical name once editing ends.
    LaunchedEffect(value, focused) { if (!focused) draft = value }
    val focus = LocalFocusManager.current
    val stacked = LocalDensity.current.fontScale > 1.3f
    @Composable fun input(modifier: Modifier) {
        BasicTextField(value = draft, onValueChange = { draft = it; onEdit(it) },
            readOnly = !editable, singleLine = true,
            textStyle = MaterialTheme.typography.bodyMedium.copy(color = SheetColors.ink, textAlign = if (stacked) TextAlign.Start else TextAlign.End),
            cursorBrush = SolidColor(SheetColors.accent),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }),
            modifier = modifier.heightIn(min = 48.dp).onFocusChanged { focused = it.isFocused }
                .semantics { contentDescription = spokenLabel },
            decorationBox = { text ->
                Box(Modifier.fillMaxWidth(), contentAlignment = if (stacked) Alignment.CenterStart else Alignment.CenterEnd) {
                    if (draft.isBlank()) SheetText("Tap to edit", style = MaterialTheme.typography.bodyMedium, color = SheetColors.muted)
                    text()
                }
            })
    }
    val row = Modifier.fillMaxWidth().revealWhileEditing(draft).focusGroup()
    if (stacked) Column(row.background(Color.White).padding(horizontal = 8.dp, vertical = 8.dp)) {
        SheetText("$label:", style = LocalSheetType.current.label)
        Row(verticalAlignment = Alignment.CenterVertically) { input(Modifier.weight(1f)) }
    } else Row(row.background(Color.White).heightIn(min = 60.dp).padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        SheetText("$label:", style = LocalSheetType.current.label)
        input(Modifier.weight(1f))
    }
}
