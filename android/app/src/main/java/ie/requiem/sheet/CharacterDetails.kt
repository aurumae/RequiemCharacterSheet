package ie.requiem.sheet

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
internal fun CharacterDetailRow(field: CharacterDetail, c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit) {
    if (field in listOf(CharacterDetail.Clan, CharacterDetail.Bloodline, CharacterDetail.Covenant)) {
        IdentityRow(field, c, catalog, editable, edit)
        return
    }
    val kind = field.catalogKind
    val value = field.value(c, catalog)
    var draft by rememberSaveable(field) { mutableStateOf(value) }
    var focused by remember { mutableStateOf(false) }
    var picker by rememberSaveable { mutableStateOf(false) }
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
    @Composable fun chooser() {
        if (kind != null) IconButton(onClick = { focus.clearFocus(); picker = true }, enabled = editable,
            modifier = Modifier.semantics { contentDescription = "Choose ${field.label}" }) { SheetIcon(SheetSymbol.Choose) }
    }
    if (stacked) Column(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp, vertical = 8.dp)) {
        SheetText("${field.label}:", style = LocalSheetType.current.label)
        Row(verticalAlignment = Alignment.CenterVertically) { input(Modifier.weight(1f)); chooser() }
    } else Row(Modifier.fillMaxWidth().background(Color.White).heightIn(min = 60.dp).padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        SheetText("${field.label}:", style = LocalSheetType.current.label)
        input(Modifier.weight(1f))
        chooser()
    }
    if (picker && kind != null) CatalogChoiceSheet(field.label, catalog.names(kind), value,
        onChoose = { draft = it; edit(SheetEdit.Detail(field, it)); picker = false }, onDismiss = { picker = false })
}

/** The same native searchable sheet can supply names for the remaining catalog pickers. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun CatalogChoiceSheet(title: String, choices: List<String>, selected: String, onChoose: (String) -> Unit, onDismiss: () -> Unit) {
    var search by rememberSaveable { mutableStateOf("") }
    val filtered = remember(search, choices) { choices.filter { it.contains(search.trim(), ignoreCase = true) } }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Color.White) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).imePadding()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                SheetText("Choose $title", Modifier.weight(1f), style = LocalSheetType.current.section)
                TextButton(onClick = onDismiss) { SheetText("Done") }
            }
            OutlinedTextField(value = search, onValueChange = { search = it }, singleLine = true,
                label = { SheetText("Search $title") }, modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done))
            SheetText("You can also type your own on the sheet.", Modifier.padding(vertical = 8.dp),
                style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
            if (filtered.isEmpty()) SheetText("No matching entries", Modifier.padding(vertical = 16.dp))
            LazyColumn(Modifier.weight(1f, fill = false)) {
                items(filtered, key = { it }) { name ->
                    Row(Modifier.fillMaxWidth().clickable { onChoose(name) }.heightIn(min = 56.dp).padding(vertical = 8.dp)
                        .semantics { this.selected = name == selected }, verticalAlignment = Alignment.CenterVertically) {
                        SheetText(name, Modifier.weight(1f), style = LocalSheetType.current.label)
                        if (name == selected) SheetText("✓", color = SheetColors.accent)
                    }
                    SheetRule()
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}
