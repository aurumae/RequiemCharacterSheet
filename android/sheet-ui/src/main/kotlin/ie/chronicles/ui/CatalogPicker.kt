package ie.chronicles.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.text.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CatalogPicker(title: String, searchLabel: String, query: String, onQuery: (String) -> Unit,
    tag: String, dismiss: () -> Unit, state: SheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    rows: LazyListScope.() -> Unit) {
    val focus = LocalFocusManager.current
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = state, containerColor = Color.White) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).imePadding()) {
            ModalHeading(title, "Cancel", dismiss)
            OutlinedTextField(query, onQuery, label = { SheetText(searchLabel) }, singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }),
                modifier = Modifier.fillMaxWidth().testTag("$tag-search"))
            LazyColumn(Modifier.weight(1f, fill = false).testTag("$tag-options"),
                contentPadding = PaddingValues(bottom = 24.dp), content = rows)
        }
    }
}
