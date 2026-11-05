package ie.requiem.sheet

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
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
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import android.text.format.DateUtils
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    private val model: SheetModel by viewModels()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The reference is a light paper sheet, including when the device is in dark mode.
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT))
        val sheetModel = model
        setContent { SheetTheme { LaunchWithDarkPack { Requiem(sheetModel) } } }
    }
    override fun onStop() { super.onStop(); model.flush() }
}

@Composable
private fun Requiem(model: SheetModel) {
    val state by model.ui.collectAsStateWithLifecycle()
    var about by rememberSaveable { mutableStateOf(false) }
    val snack = remember { SnackbarHostState() }
    val focus = LocalFocusManager.current
    val c = state.character
    var requestedSection by rememberSaveable(c?.id?.toString()) { mutableStateOf<SheetSection?>(null) }
    val window = LocalWindowInfo.current.containerSize
    val sideInset = if (window.width > window.height) with(LocalDensity.current) { (window.width * .08f).toDp() } else 16.dp
    var announced by rememberSaveable(c?.id?.toString()) { mutableIntStateOf(0) }
    var saved by remember(c?.id) { mutableStateOf(false) }
    LaunchedEffect(state.overdraft) {
        if (state.overdraft > announced) {
            announced = state.overdraft
            snack.showSnackbar("Your available Experiences are now below zero.")
        }
    }
    LaunchedEffect(state.savedNotice) {
        if (state.savedNotice > 0) { saved = true; delay(1500); saved = false }
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
                    TextButton(onClick = { focus.clearFocus(); model.save() }, enabled = !state.busy && !saved) { Text(if (saved) "Saved" else "Save") }
                }
            }
            LogoHeader()
            state.error?.let {
                Surface(color = MaterialTheme.colorScheme.errorContainer) {
                    Column(Modifier.fillMaxWidth().padding(12.dp)) {
                        Text(it, Modifier.semantics { liveRegion = LiveRegionMode.Polite })
                        TextButton(onClick = { if (c == null) model.refresh() else model.flush() }) { Text("Retry") }
                    }
                }
            }
            when {
                c != null -> key(c.id) { SheetEditor(c, model.catalog, state.busy, model::edit, requestedSection) { requestedSection = null } }
                state.busy -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                else -> Library(state.rows, model) { about = true }
            }
        }
        SnackbarHost(snack, Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom = 32.dp))
    }
    if (about) AlertDialog(onDismissRequest = { about = false }, title = { Text("About this app") }, text = {
        Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Image(painterResource(R.drawable.dark_pack), "Dark Pack", Modifier.size(72.dp))
            Text(stringResource(R.string.dark_pack_copyright))
            Text(stringResource(R.string.dark_pack_disclaimer))
        }
    }, confirmButton = { TextButton(onClick = { about = false }) { Text("Close") } })
}

@Composable
private fun SheetSectionMenu(sections: List<SheetSection>, select: (SheetSection) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        TextButton(onClick = { expanded = true }) { Text("Sections") }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            sections.forEach { section ->
                DropdownMenuItem(text = { Text(section.title) }, onClick = { expanded = false; select(section) })
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
        Text(if (enabled) "XP $available" else "XP Off",
            Modifier.border(1.dp, ink, CircleShape)
                .background(if (enabled) ink else Color.White, CircleShape).padding(horizontal = 8.dp, vertical = 3.dp),
            color = if (enabled) Color.White else ink,
            style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun Library(rows: List<LibraryRow>, model: SheetModel, about: () -> Unit) {
    var confirmId by rememberSaveable { mutableStateOf<String?>(null) }
    LazyColumn(Modifier.fillMaxSize().testTag("character-library")) {
        item { SectionBand("CHARACTERS") }
        if (rows.isEmpty()) item {
            Text("Create a blank sheet to start your chronicle.",
                Modifier.fillMaxWidth().background(Color.White).padding(12.dp), color = SheetColors.muted)
        }
        items(rows, key = { it.id.toString() }) { row ->
            val title = row.name.ifBlank { if (row.problem == null) "Unnamed Character" else "Unavailable character" }
            var menu by remember { mutableStateOf(false) }
            Row(Modifier.fillMaxWidth().background(Color.White), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f).clickable(enabled = row.problem == null, onClickLabel = "Open sheet") {
                    model.open(row.id)
                }.padding(horizontal = 8.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(title, style = LocalSheetType.current.label)
                    if (row.details.isNotEmpty()) Text(row.details, style = MaterialTheme.typography.bodyMedium)
                    if (row.guided) Text("Guided · Read-only", style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    if (row.problem != null) Text(row.problem, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    else row.edited?.let {
                        Text("Edited " + DateUtils.getRelativeTimeSpanString((it * 1000).toLong() + 978_307_200_000L,
                            System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS),
                            style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    }
                }
                if (!row.guided && row.problem == null) Box {
                    IconButton(onClick = { menu = true }, modifier = Modifier.semantics { contentDescription = "Options for $title" }) {
                        SheetIcon(SheetSymbol.More, SheetColors.muted)
                    }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        DropdownMenuItem(text = { Text("Delete character") }, onClick = { menu = false; confirmId = row.id.toString() })
                    }
                }
            }
            SheetRule()
        }
        item {
            Row(Modifier.fillMaxWidth().background(Color.White).clickable(onClick = model::create).padding(8.dp).heightIn(min = 48.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                SheetIcon(SheetSymbol.Add)
                Text("New blank sheet", style = MaterialTheme.typography.bodyMedium, color = SheetColors.accent)
            }
        }
        item { TextButton(onClick = about) { Text("About this app") } }
    }
    val selected = rows.firstOrNull { it.id.toString() == confirmId }
    if (selected != null) AlertDialog(onDismissRequest = { confirmId = null },
        title = { Text("Delete character?") },
        text = { Text("“${selected.name.ifBlank { "Unnamed character" }}” will be removed from this device.") },
        confirmButton = { TextButton(onClick = { confirmId = null; model.delete(selected.id) }) { Text("Delete") } },
        dismissButton = { TextButton(onClick = { confirmId = null }) { Text("Cancel") } })
}
