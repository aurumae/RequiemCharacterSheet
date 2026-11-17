package ie.chronicles.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

/** Games supply one section per lazy item, including separately keyed editing rows. */
@Composable
fun <S : Any> SheetList(rowSections: List<S>, requested: S?, report: (S) -> Unit, onHandled: () -> Unit,
    rows: LazyListScope.() -> Unit) {
    val list = rememberLazyListState()
    val reportCurrent by rememberUpdatedState(report)
    val handled by rememberUpdatedState(onHandled)
    var jumping by remember { mutableStateOf(false) }
    val readingLine = with(LocalDensity.current) { 80.dp.roundToPx() }
    LaunchedEffect(list, rowSections, readingLine) {
        snapshotFlow {
            if (jumping || !list.isScrollInProgress) null
            else list.layoutInfo.visibleItemsInfo.lastOrNull { it.offset <= readingLine }?.index
        }.collect { index -> index?.let(rowSections::getOrNull)?.let(reportCurrent) }
    }
    LaunchedEffect(requested, rowSections) {
        if (requested != null) {
            jumping = true
            try {
                val index = rowSections.indexOf(requested)
                if (index >= 0) { list.scrollToItem(index); reportCurrent(requested) }
            } finally { jumping = false; handled() }
        }
    }
    LazyColumn(state = list, modifier = Modifier.fillMaxSize().pageEdges().sheetWatermark().testTag("character-sheet"),
        contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp), content = rows)
}
