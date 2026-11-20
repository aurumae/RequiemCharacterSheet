package ie.chronicles.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.text.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CatalogPicker(title: String, searchLabel: String, query: String, onQuery: (String) -> Unit,
    tag: String, dismiss: () -> Unit, state: SheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    containerColor: Color = Color.White, plainHeading: Boolean = false, compactSearchWhileTyping: Boolean = false,
    rows: LazyListScope.() -> Unit) {
    val focus = LocalFocusManager.current
    var compact by remember { mutableStateOf(false) }
    @Composable fun search(modifier: Modifier) {
        OutlinedTextField(query, onQuery, label = { SheetText(searchLabel) }, singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }),
            modifier = modifier.testTag("$tag-search"))
    }
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = state, containerColor = containerColor,
        dragHandle = if(compact) null else ({ BottomSheetDefaults.DragHandle() })) {
        // Read the dialog window's insets, not the activity behind it.
        val density = LocalDensity.current
        val keyboard = WindowInsets.ime.getBottom(density)
        val shortWindow = with(density) { (LocalWindowInfo.current.containerSize.height - keyboard).toDp() < 300.dp }
        SideEffect { compact = compactSearchWhileTyping && keyboard > 0 && shortWindow }
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).imePadding()) {
            if(!compact) {
                if(plainHeading) Row(Modifier.fillMaxWidth(),verticalAlignment=androidx.compose.ui.Alignment.CenterVertically) {
                    SheetText(title,Modifier.weight(1f),style=MaterialTheme.typography.titleMedium)
                    TextButton(onClick=dismiss) { SheetText("Cancel") }
                } else ModalHeading(title, "Cancel", dismiss)
            }
            // Keep the field in the same composition slot as the IME changes the header.
            Row(Modifier.fillMaxWidth(),verticalAlignment=androidx.compose.ui.Alignment.CenterVertically) {
                search(Modifier.weight(1f))
                if(compact) TextButton(onClick=dismiss) { SheetText("Cancel") }
            }
            LazyColumn(Modifier.weight(1f, fill = false).testTag("$tag-options"),
                contentPadding = PaddingValues(bottom = 24.dp), content = rows)
        }
    }
}
