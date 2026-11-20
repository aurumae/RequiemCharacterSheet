package ie.chronicles.ui

import android.text.format.DateUtils
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.repeatOnLifecycle
import ie.chronicles.core.*
import kotlinx.coroutines.delay
import java.text.DateFormat
import java.util.Date

@Composable
fun <C : StoredCharacter> ImportConflict(pending: PendingImport<C>, busy: Boolean, resolve: (Boolean) -> Unit, cancel: () -> Unit) {
    fun edited(value: Double) = DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT)
        .format(Date((value * 1000).toLong() + 978_307_200_000L))
    val name = pending.document.character.name.ifEmpty { "Unnamed Character" }
    val existingDate = pending.existing?.edited
    val message = "The imported copy was edited ${edited(pending.document.character.modifiedAt)}. " +
        if (existingDate == null) "The one on this device could not be read." else "The one on this device was edited ${edited(existingDate)}."
    AlertDialog(onDismissRequest = { if (!busy) cancel() }, title = { SheetText("“$name” Is Already Here") },
        text = { SheetText(message, Modifier.verticalScroll(rememberScrollState())) },
        confirmButton = {
            Column(Modifier.fillMaxWidth()) {
                TextButton(onClick = { resolve(false) }, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                    SheetText("Replace", color = MaterialTheme.colorScheme.error)
                }
                TextButton(onClick = { resolve(true) }, enabled = !busy, modifier = Modifier.fillMaxWidth()) { SheetText("Keep Both") }
                TextButton(onClick = cancel, enabled = !busy, modifier = Modifier.fillMaxWidth()) { SheetText("Cancel") }
            }
        })
}

@Composable
fun <C : StoredCharacter> Library(rows: List<LibraryRow>, model: SheetLibraryModel<C>, importCharacter: () -> Unit,
    allowCreation: Boolean = true, allowGuidedCreation: Boolean = true, notice: String? = null,
    header: @Composable () -> Unit = { SectionBand("CHARACTERS") }, about: () -> Unit) {
    var exportPicker by rememberSaveable { mutableStateOf(false) }
    var confirmId by rememberSaveable { mutableStateOf<String?>(null) }
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(lifecycle) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            while (true) { now = System.currentTimeMillis(); delay(DateUtils.MINUTE_IN_MILLIS) }
        }
    }
    LazyColumn(Modifier.fillMaxSize().pageEdges().testTag("character-library"), contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp)) {
        item { header() }
        if (notice != null) item {
            SheetText(notice, Modifier.fillMaxWidth().padding(12.dp), color = SheetColors.muted)
        }
        if (rows.isEmpty() && allowCreation) item {
            SheetText(if (allowGuidedCreation) "Start with a blank sheet or follow guided character creation." else "Start with a blank sheet or import a character.",
                Modifier.fillMaxWidth().background(Color.White).padding(12.dp), color = SheetColors.muted)
        }
        items(rows, key = { it.id.toString() }) { row ->
            val title = row.name.ifBlank { if (row.problem == null) "Unnamed Character" else "Unavailable character" }
            var menu by remember { mutableStateOf(false) }
            Row(Modifier.fillMaxWidth().background(Color.White), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f).combinedClickable(enabled = row.problem == null, onClickLabel = "Open sheet",
                    onClick = { model.open(row.id) }, onLongClickLabel = "Character options", onLongClick = { menu = true })
                    .padding(horizontal = 8.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    SheetText(title, style = LocalSheetType.current.label)
                    if (row.details.isNotEmpty()) SheetText(row.details, style = MaterialTheme.typography.bodyMedium)
                    if (row.guided) SheetText("Guided creation · In progress", style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    val problem = row.problem
                    if (problem != null) SheetText(problem, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    else row.edited?.let {
                        SheetText("Edited " + DateUtils.getRelativeTimeSpanString((it * 1000).toLong() + 978_307_200_000L,
                            now, DateUtils.MINUTE_IN_MILLIS),
                            style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    }
                }
                if (row.problem == null) Box {
                    IconButton(onClick = { menu = true }, modifier = Modifier.semantics { contentDescription = "Options for $title" }) {
                        SheetIcon(SheetSymbol.More, SheetColors.muted)
                    }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        DropdownMenuItem(text = { SheetText("Export") }, onClick = { menu = false; model.export(row.id, ExportMode.Share) })
                        DropdownMenuItem(text = { SheetText("Save to file") }, onClick = { menu = false; model.export(row.id, ExportMode.Save) })
                        DropdownMenuItem(text = { SheetText("Delete character") }, onClick = { menu = false; confirmId = row.id.toString() })
                    }
                }
            }
            SheetRule()
        }
        if (allowCreation) item {
            Row(Modifier.fillMaxWidth().background(Color.White).clickable(onClick = { model.create() }).padding(8.dp).heightIn(min = 48.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                SheetIcon(SheetSymbol.Add)
                SheetText("New blank sheet", style = MaterialTheme.typography.bodyMedium, color = SheetColors.accent)
            }
        }
        if (allowCreation && allowGuidedCreation) item { AddSheetRow("Guided character creation", true) { model.create(guided = true) } }
        item { AddSheetRow("Import Character", true, importCharacter) }
        item { AddSheetRow("Export Character", rows.any { it.problem == null }) { exportPicker = true } }
        item { TextButton(onClick = about) { SheetText("About this app", style = LocalSheetType.current.libraryAbout) } }
    }
    if (exportPicker) AlertDialog(onDismissRequest = { exportPicker = false }, title = { SheetText("Export Character") }, text = {
        LazyColumn {
            items(rows.filter { it.problem == null }, key = { it.id.toString() }) { row ->
                TextButton(onClick = { exportPicker = false; model.export(row.id, ExportMode.Share) }, modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.fillMaxWidth()) {
                        SheetText(row.name.ifBlank { "Unnamed Character" }, style = LocalSheetType.current.trait)
                        if (row.details.isNotBlank()) SheetText(row.details, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
    }, confirmButton = { TextButton(onClick = { exportPicker = false }) { SheetText("Cancel") } })
    val selected = rows.firstOrNull { it.id.toString() == confirmId }
    if (selected != null) AlertDialog(onDismissRequest = { confirmId = null },
        title = { SheetText("Delete character?") },
        text = { SheetText("“${selected.name.ifBlank { "Unnamed character" }}” will be removed from this device.") },
        confirmButton = { TextButton(onClick = { confirmId = null; model.delete(selected.id) }) { SheetText("Delete") } },
        dismissButton = { TextButton(onClick = { confirmId = null }) { SheetText("Cancel") } })
}
