package ie.requiem.sheet

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import android.text.format.DateUtils
import kotlinx.coroutines.delay
import java.text.DateFormat
import java.util.Date

class MainActivity : ComponentActivity() {
    private val model: SheetModel by viewModels()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The reference is a light paper sheet, including when the device is in dark mode.
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT))
        val sheetModel = model
        if (savedInstanceState == null) intent.characterImportUri()?.let(sheetModel::enqueueImport)
        setContent { SheetTheme { LaunchWithDarkPack { Requiem(sheetModel) } } }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // The model owns pending transfers; retain the launch intent for activity recreation.
        intent.characterImportUri()?.let(model::enqueueImport)
    }
    override fun onStop() { super.onStop(); model.flush() }
}

@Composable
private fun Requiem(model: SheetModel) {
    val state by model.ui.collectAsStateWithLifecycle()
    var about by rememberSaveable { mutableStateOf(false) }
    val snack = remember { SnackbarHostState() }
    val focus = LocalFocusManager.current
    val context = LocalContext.current
    val importFile = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let(model::enqueueImport)
    }
    // A generic MIME type preserves .vtrcharacter; document providers append .json for application/json.
    val saveFile = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream"), model::saveExport)
    val c = state.character
    var requestedSection by rememberSaveable(c?.id?.toString()) { mutableStateOf<SheetSection?>(null) }
    val window = LocalWindowInfo.current.containerSize
    val sideInset = if (window.width > window.height) with(LocalDensity.current) { (window.width * .08f).toDp() } else 16.dp
    var announced by rememberSaveable(c?.id?.toString()) { mutableIntStateOf(0) }
    var saved by remember(c?.id) { mutableStateOf(false) }
    LaunchedEffect(state.overdraft) {
        if (state.overdraft > announced) {
            announced = state.overdraft
            snack.showSnackbar("Your available Experiences are now below zero.", withDismissAction = true)
        }
    }
    LaunchedEffect(state.savedNotice) {
        if (state.savedNotice > 0) { saved = true; delay(1500); saved = false }
    }
    LaunchedEffect(state.incomingUri, state.busy, state.pendingImport, state.transferError, state.exportRequest, state.awaitingDestination) {
        if (state.incomingUri != null && !state.busy && state.pendingImport == null && state.transferError == null && state.exportRequest == null && !state.awaitingDestination) {
            about = false
            focus.clearFocus()
            model.startNextImport()
        }
    }
    LaunchedEffect(state.exportRequest) {
        state.exportRequest?.let { request ->
            try {
                model.exportLaunched(request)
                when (request.mode) {
                    ExportMode.Share -> context.startActivity(characterShareIntent(context, request))
                    ExportMode.Save -> saveFile.launch(request.name)
                }
            } catch (e: Exception) { model.exportFailure(e) }
        }
    }
    LaunchedEffect(state.transferNotice) {
        if (state.transferNotice > 0) snack.showSnackbar("Character file saved.", withDismissAction = true)
    }
    BackHandler(enabled = c != null) { focus.clearFocus(); model.close() }
    PageBackground {
        Column(Modifier.fillMaxSize().safeDrawingPadding().imePadding().padding(horizontal = sideInset).padding(top = 20.dp, bottom = 40.dp)) {
            if (c != null) Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { focus.clearFocus(); model.close() }, enabled = !state.busy, modifier = Modifier.semantics { contentDescription = "Back" }) {
                    SheetIcon(SheetSymbol.Back, SheetColors.ink)
                }
                SheetSectionMenu(SheetSection.available(c, model.catalog)) { focus.clearFocus(); requestedSection = it }
                Spacer(Modifier.weight(1f))
                if (c.creation == null) {
                    XpBadge(c.xpMode, c.experiencesAvailable, !state.busy) { model.edit(ie.requiem.rules.SheetEdit.XpMode(!c.xpMode)) }
                }
                TextButton(onClick = { focus.clearFocus(); model.save() }, enabled = !state.busy && !saved) { SheetText(if (saved) "Saved" else "Save") }
            }
            LogoHeader()
            state.error?.let {
                Surface(color = MaterialTheme.colorScheme.errorContainer) {
                    Column(Modifier.fillMaxWidth().padding(12.dp)) {
                        SheetText(it, Modifier.semantics { liveRegion = LiveRegionMode.Polite })
                        TextButton(onClick = { if (c == null) model.refresh() else model.flush() }) { SheetText("Retry") }
                    }
                }
            }
            when {
                c != null -> key(c.id) { SheetEditor(c, model.catalog, state.busy, model::edit, requestedSection) { requestedSection = null } }
                state.busy -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                else -> Library(state.rows, model, importCharacter = { importFile.launch(arrayOf("*/*")) }) { about = true }
            }
        }
        SnackbarHost(snack, Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom = 32.dp))
    }
    if (about) AboutSheet { about = false }
    state.pendingImport?.takeIf { it.existing != null && state.transferError == null }?.let { pending ->
        ImportConflict(pending, state.busy, model::resolveImport, model::cancelImport)
    }
    state.transferError?.let { error ->
        val hasPending = state.pendingImport != null
        AlertDialog(onDismissRequest = { if (hasPending) model.cancelImport() else model.dismissTransferError() },
            title = { SheetText(error.title) }, text = { SheetText(error.message) },
            confirmButton = {
                TextButton(onClick = { if (hasPending) model.retryImport() else model.dismissTransferError() }) {
                    SheetText(if (hasPending) "Retry" else "OK")
                }
            }, dismissButton = { if (hasPending) TextButton(onClick = model::cancelImport) { SheetText("Cancel") } })
    }
}

@Composable
private fun ImportConflict(pending: PendingImport, busy: Boolean, resolve: (Boolean) -> Unit, cancel: () -> Unit) {
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
private fun SheetSectionMenu(sections: List<SheetSection>, select: (SheetSection) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        TextButton(onClick = { expanded = true }) { SheetText("Sections") }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            sections.forEach { section ->
                DropdownMenuItem(text = { SheetText(section.title) }, onClick = { expanded = false; select(section) })
            }
        }
    }
}

@Composable
private fun XpBadge(enabled: Boolean, available: Int, interactive: Boolean, toggle: () -> Unit) {
    val ink = if (available < 0) SheetColors.caution else SheetColors.accent
    Box(Modifier.heightIn(min = 48.dp).widthIn(min = 64.dp).clip(CircleShape)
        .clickable(enabled = interactive, role = Role.Switch, onClick = toggle)
        .clearAndSetSemantics {
            contentDescription = "XP Mode"
            stateDescription = if (enabled) "On, $available Experiences available" else "Off"
            role = Role.Switch
            if (interactive) onClick(label = "Toggle XP Mode") { toggle(); true }
        }, contentAlignment = Alignment.Center) {
        SheetText(if (enabled) "XP $available" else "XP Off",
            Modifier.border(1.dp, ink, CircleShape)
                .background(if (enabled) ink else Color.White, CircleShape).padding(horizontal = 8.dp, vertical = 3.dp),
            color = if (enabled) Color.White else ink,
            style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun Library(rows: List<LibraryRow>, model: SheetModel, importCharacter: () -> Unit, about: () -> Unit) {
    var confirmId by rememberSaveable { mutableStateOf<String?>(null) }
    LazyColumn(Modifier.fillMaxSize().pageEdges().testTag("character-library"), contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp)) {
        item { SectionBand("CHARACTERS") }
        if (rows.isEmpty()) item {
            SheetText("Start with a blank sheet or follow guided character creation.",
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
                    if (row.problem != null) SheetText(row.problem, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    else row.edited?.let {
                        SheetText("Edited " + DateUtils.getRelativeTimeSpanString((it * 1000).toLong() + 978_307_200_000L,
                            System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS),
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
        item {
            Row(Modifier.fillMaxWidth().background(Color.White).clickable(onClick = { model.create() }).padding(8.dp).heightIn(min = 48.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                SheetIcon(SheetSymbol.Add)
                SheetText("New blank sheet", style = MaterialTheme.typography.bodyMedium, color = SheetColors.accent)
            }
        }
        item { AddSheetRow("Guided character creation", true) { model.create(guided = true) } }
        item { AddSheetRow("Import Character", true, importCharacter) }
        item { TextButton(onClick = about) { SheetText("About this app") } }
    }
    val selected = rows.firstOrNull { it.id.toString() == confirmId }
    if (selected != null) AlertDialog(onDismissRequest = { confirmId = null },
        title = { SheetText("Delete character?") },
        text = { SheetText("“${selected.name.ifBlank { "Unnamed character" }}” will be removed from this device.") },
        confirmButton = { TextButton(onClick = { confirmId = null; model.delete(selected.id) }) { SheetText("Delete") } },
        dismissButton = { TextButton(onClick = { confirmId = null }) { SheetText("Cancel") } })
}
