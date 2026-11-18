package ie.forsaken.sheet

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import ie.chronicles.core.*
import ie.chronicles.ui.*
import ie.forsaken.rules.*
import java.text.DateFormat
import java.util.Date

@Composable
internal fun PreviewSheet(character: ForsakenCharacter, catalog: ForsakenCatalog, requested: ForsakenSection?,
    report: (ForsakenSection) -> Unit, handled: () -> Unit) {
    val c = character.state
    val rows = remember(c, catalog) { previewRows(c, catalog) }
    var detail by rememberSaveable(character.id.toString()) { mutableStateOf<String?>(null) }
    var browse by rememberSaveable(character.id.toString()) { mutableStateOf(false) }
    var fileInfo by rememberSaveable(character.id.toString()) { mutableStateOf(false) }
    val headings = rememberHeadingArt()
    SheetList(rows.map { it.section }, requested, report, handled) {
        items(rows, key = { it.key }) { row ->
            when (row.style) {
                PreviewRowStyle.Heading -> ForsakenHeading(row.title, headings[row.title])
                PreviewRowStyle.Subheading -> SubsectionLabel(row.title)
                PreviewRowStyle.Note -> SheetText(row.title, Modifier.padding(horizontal = 8.dp, vertical = 10.dp),
                    style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                PreviewRowStyle.Catalog -> {
                    TextButton(onClick = { browse = true }, modifier = Modifier.fillMaxWidth()) { SheetText(row.title) }
                    TextButton(onClick = { fileInfo = true }, modifier = Modifier.fillMaxWidth()) { SheetText("File information") }
                }
                PreviewRowStyle.Health -> {
                    if (c.healthTrack.isEmpty()) SheetText("No boxes saved", Modifier.padding(8.dp))
                    else HealthBoxes(c.healthTrack, c.healthTrack.size, false) {}
                }
                PreviewRowStyle.Willpower -> {
                    if (c.willpowerTrack.isEmpty()) SheetText("No boxes saved", Modifier.padding(8.dp))
                    else WillpowerBoxes(c.willpowerTrack, c.willpowerTrack.size, false) {}
                }
                else -> SavedRow(row, row.reference?.takeIf { catalog.resolve(it) != null }?.let { { detail = it } })
            }
        }
    }
    if (browse) CatalogBrowser(catalog, c.showsUnofficialContent, { detail = it }) { browse = false }
    detail?.let { reference -> catalog.resolve(reference)?.let { entry -> CatalogDetails(entry, catalog) { detail = null } } }
    if (fileInfo) AlertDialog(onDismissRequest = { fileInfo = false }, title = { SheetText("File information") },
        text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            SheetText("Werewolf The Forsaken · Schema ${c.schemaVersion}")
            SheetText("Created ${savedDate(c.createdAt)}")
            SheetText("Edited ${savedDate(c.modifiedAt)}")
            SheetText("Identity ${c.id}", style = MaterialTheme.typography.bodySmall)
            SheetText("An unchanged import exports with its original contents and dates. Keep Both makes a separate copy with a new identity and name.", style = MaterialTheme.typography.bodySmall)
        } }, confirmButton = { TextButton(onClick = { fileInfo = false }) { SheetText("Done") } })
}

@Composable
private fun SavedRow(row: PreviewRow, open: (() -> Unit)?) {
    Column(Modifier.fillMaxWidth().testTag("saved-${row.key}")
        .then(if (open != null) Modifier.clickable(role = Role.Button, onClickLabel = "Read ${row.title}", onClick = open) else Modifier)
        .padding(horizontal = 8.dp, vertical = 10.dp).semantics(mergeDescendants = true) {}) {
        val rating = row.rating
        if (rating != null) {
            SheetText(row.title, style = LocalSheetType.current.trait)
            Row(Modifier.padding(top = 4.dp).clearAndSetSemantics { contentDescription = "${row.rating} saved dots" },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                // The number is always exact, including out-of-range saved values. These are not effective ratings.
                repeat(maxOf(5, rating).coerceAtMost(10)) { RatingDot(it < rating, diameter = 16.dp) }
                SheetText(row.rating.toString(), Modifier.padding(start = 4.dp))
            }
        } else SheetText(row.title, style = if (open != null) LocalSheetType.current.trait else LocalSheetType.current.label)
        if (row.value.isNotEmpty()) SheetText(row.value, Modifier.padding(top = 3.dp), style = MaterialTheme.typography.bodyMedium)
        row.date?.let { SheetText(savedDate(it), Modifier.padding(top = 4.dp), style = MaterialTheme.typography.bodySmall, color = SheetColors.muted) }
        if (open != null) SheetText("Read details ›", Modifier.padding(top = 4.dp), style = MaterialTheme.typography.bodySmall, color = SheetColors.accent)
    }
    SheetRule()
}

internal fun savedDate(date: Double): String = DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT)
    .format(Date((date * 1000).toLong() + 978_307_200_000L))
