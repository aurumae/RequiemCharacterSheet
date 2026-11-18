package ie.forsaken.sheet

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import ie.chronicles.core.CatalogSearch
import ie.chronicles.ui.*
import ie.forsaken.rules.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun CatalogBrowser(catalog: ForsakenCatalog, unofficial: Boolean, open: (String) -> Unit, dismiss: () -> Unit) {
    var query by rememberSaveable { mutableStateOf("") }
    val sections = remember(query, unofficial, catalog) {
        val search = CatalogSearch(query)
        catalog.books.values.filter { it.official || unofficial }.mapNotNull { book ->
            val entries = CatalogKind.entries.flatMap { kind -> catalog.visible(kind, unofficial)
                .filter { it.source.book == book.id && (search.matches(it.name) || search.matches(it.summary) ||
                    it.array("facets").any { facet -> search.matches(ForsakenEntry(facet as kotlinx.serialization.json.JsonObject).name) }) }
                .map { kind to it } }
            if (entries.isEmpty()) null else book to entries
        }
    }
    CatalogPicker("Catalog", "Search names or rules", query, { query = it }, "forsaken-catalog", dismiss) {
        if (sections.isEmpty()) item { SheetText("No matching entries", Modifier.padding(12.dp)) }
        sections.forEach { (book, entries) ->
            item(key = "book/${book.id}") {
                SheetText(book.name + if (!book.official) " (Unofficial)" else "",
                    Modifier.fillMaxWidth().padding(vertical = 12.dp).semantics { heading() }, style = LocalSheetType.current.section, color = SheetColors.accent)
            }
            items(entries, key = { "${book.id}/${it.first.name}/${it.second.id}" }) { (kind, entry) ->
                Column(Modifier.fillMaxWidth().clickable(role = Role.Button) { open("${kind.name}/${entry.id}") }.padding(vertical = 10.dp)) {
                    SheetText(entry.name, style = LocalSheetType.current.trait)
                    SheetText(kind.title, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    SheetText(entry.summary, style = MaterialTheme.typography.bodySmall)
                }
                SheetRule()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun CatalogDetails(entry: ForsakenEntry, catalog: ForsakenCatalog, dismiss: () -> Unit) {
    val facts = remember(entry, catalog) { catalogDetails(entry, catalog) }
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Color.White) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
            ModalHeading(entry.name, "Done", dismiss)
            LazyColumn(Modifier.testTag("catalog-details"), contentPadding = PaddingValues(bottom = 24.dp)) {
                items(facts) { fact ->
                    Column(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                        if (fact.title.isNotEmpty()) SheetText(fact.title, Modifier.semantics { heading() }, style = LocalSheetType.current.trait)
                        SelectionContainer { SheetText(fact.text, style = MaterialTheme.typography.bodyMedium) }
                    }
                }
            }
        }
    }
}
