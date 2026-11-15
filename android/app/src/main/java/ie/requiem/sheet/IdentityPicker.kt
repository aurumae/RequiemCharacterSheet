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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import ie.requiem.rules.*
import kotlinx.coroutines.launch

@Composable
internal fun IdentityRow(field: CharacterDetail, c: CharacterSave, catalog: Catalog, editable: Boolean, navigate: (String) -> Unit) {
    val value = field.value(c, catalog)
    @Composable fun label() {
        SheetText("${field.label}:", Modifier.heightIn(min = 48.dp).clickable { navigate("identityDetail|${field.name}") }
            .padding(vertical = 12.dp).semantics { contentDescription = "${field.label} details" }, style = LocalSheetType.current.label)
    }
    @Composable fun input(modifier: Modifier) {
        Row(modifier.heightIn(min = 48.dp).clickable(enabled = editable, role = Role.Button) { navigate("identityPick|${field.name}") }
            .semantics(mergeDescendants = true) { contentDescription = field.label; stateDescription = value.ifBlank { "Not chosen" } }
            .testTag("identity-${field.name}"), verticalAlignment = Alignment.CenterVertically) {
            SheetText(value.ifBlank { "Choose" }, Modifier.weight(1f), color = if (value.isBlank()) SheetColors.muted else SheetColors.ink)
            SheetIcon(SheetSymbol.Choose)
        }
    }
    if (LocalDensity.current.fontScale > 1.3f) Column(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp)) {
        label(); input(Modifier.fillMaxWidth())
    } else Row(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        label(); input(Modifier.weight(1f))
    }
}

@Composable
internal fun IdentityDialogs(route: String, c: CharacterSave, catalog: Catalog, edit: (SheetEdit) -> Unit, navigate: (String?) -> Unit) {
    val parts = route.split('|'); val field = CharacterDetail.valueOf(parts[1])
    val value = field.value(c, catalog)
    val entry = field.catalogKind?.let { catalog.entry(it, catalog.source(it, value)) }
    when {
        parts[0] == "identityCustom" -> TextPrompt("Custom ${field.label}", field.label, value, false, true, {
            edit(SheetEdit.Detail(field, it)); navigate(null)
        }, { navigate(null) })
        parts[0] == "identityDetail" && entry != null -> EntryDetailSheet(c.bookDetail(entry, catalog)) { navigate(null) }
        else -> IdentityPicker(field, c, catalog, { edit(SheetEdit.Detail(field, it)); navigate(null) },
            { navigate("identityCustom|${field.name}") }, { navigate(null) })
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun IdentityPicker(field: CharacterDetail, c: CharacterSave, catalog: Catalog,
    onChoose: (String) -> Unit, onCustom: () -> Unit, dismiss: () -> Unit) {
    var search by rememberSaveable { mutableStateOf("") }
    var closing by remember { mutableStateOf(false) }
    val options = remember(field, c, search) { c.identityOptions(field, catalog, search) }
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val focus = LocalFocusManager.current
    fun finish(action: () -> Unit) {
        if (closing) return
        closing = true
        focus.clearFocus()
        scope.launch { state.hide(); action() }
    }
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = state, containerColor = Color.White) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).imePadding()) {
            ModalHeading("Choose ${field.label}", "Cancel", dismiss)
            OutlinedTextField(search, onValueChange = { search = it }, singleLine = true, label = { SheetText("Search ${field.label}s") },
                modifier = Modifier.fillMaxWidth().testTag("identity-search"), keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }), keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done))
            LazyColumn(Modifier.weight(1f, fill = false).testTag("identity-options"), contentPadding = PaddingValues(bottom = 24.dp)) {
                item { TextButton(onClick = { finish(onCustom) }, enabled = !closing) { SheetText("Custom ${field.label}") } }
                if (field in listOf(CharacterDetail.Bloodline, CharacterDetail.Covenant)) item {
                    TextButton(onClick = { finish { onChoose("") } }, enabled = !closing) { SheetText(if (field == CharacterDetail.Bloodline) "No Bloodline" else "Unaligned") }
                }
                if (options.isEmpty()) item { SheetText("No matching entries", Modifier.padding(12.dp)) }
                catalog.bookSections(options, { it.entry }, { it.group }).forEach { section ->
                    item("group-${section.id}") { CatalogSectionHeading(section.book, section.title) }
                    items(section.entries, key = { "${section.id}/${it.entry.id}" }) { option ->
                        val selected = option.entry.name == field.value(c, catalog)
                        Column(Modifier.fillMaxWidth().clickable(enabled = !closing, role = Role.Button) { finish { onChoose(option.entry.name) } }
                            .testTag("identity-option-${option.entry.id}").padding(vertical = 12.dp)
                            .semantics(mergeDescendants = true) { this.selected = selected }) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                SheetText(option.entry.name, Modifier.weight(1f), style = LocalSheetType.current.trait)
                                if (selected) SheetText("✓", Modifier.clearAndSetSemantics {}, color = SheetColors.accent)
                            }
                            SheetText(option.entry.summary, style = MaterialTheme.typography.bodySmall)
                            option.details.forEach { SheetText(it, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted) }
                            option.warning?.let { WarningText(it) }
                            SheetText(option.entry.citation, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                        }
                        SheetRule()
                    }
                }
            }
        }
    }
}
