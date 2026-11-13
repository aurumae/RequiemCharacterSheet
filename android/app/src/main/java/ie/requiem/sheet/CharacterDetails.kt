package ie.requiem.sheet

import ie.chronicles.ui.*

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import ie.requiem.rules.*

@Composable
internal fun CharacterDetailRow(field: CharacterDetail, c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit, navigate: (String) -> Unit) {
    if (field.catalogKind != null) {
        IdentityRow(field, c, catalog, editable, navigate)
        return
    }
    val value = field.value(c, catalog)
    var draft by rememberSaveable(field) { mutableStateOf(value) }
    var focused by remember { mutableStateOf(false) }
    // Keep the player's spelling/cursor while typing. The saved source may resolve to a
    // book entry immediately; show its canonical name once editing ends.
    LaunchedEffect(value, focused) { if (!focused) draft = value }
    val focus = LocalFocusManager.current
    val stacked = LocalDensity.current.fontScale > 1.3f
    @Composable fun input(modifier: Modifier) {
        BasicTextField(value = draft, onValueChange = { draft = it; edit(SheetEdit.Detail(field, it)) },
            readOnly = !editable, singleLine = true,
            textStyle = MaterialTheme.typography.bodyMedium.copy(color = SheetColors.ink, textAlign = if (stacked) TextAlign.Start else TextAlign.End),
            cursorBrush = SolidColor(SheetColors.accent),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }),
            modifier = modifier.revealWhileEditing(draft).heightIn(min = 48.dp).onFocusChanged { focused = it.isFocused }
                .semantics { contentDescription = if (field == CharacterDetail.Name) "Character name" else field.label },
            decorationBox = { text ->
                Box(Modifier.fillMaxWidth(), contentAlignment = if (stacked) Alignment.CenterStart else Alignment.CenterEnd) {
                    if (draft.isBlank()) SheetText("Tap to edit", style = MaterialTheme.typography.bodyMedium, color = SheetColors.muted)
                    text()
                }
            })
    }
    if (stacked) Column(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp, vertical = 8.dp)) {
        SheetText("${field.label}:", style = LocalSheetType.current.label)
        Row(verticalAlignment = Alignment.CenterVertically) { input(Modifier.weight(1f)) }
    } else Row(Modifier.fillMaxWidth().background(Color.White).heightIn(min = 60.dp).padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        SheetText("${field.label}:", style = LocalSheetType.current.label)
        input(Modifier.weight(1f))
    }
}
