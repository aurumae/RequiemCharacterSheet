package ie.requiem.sheet

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.text.DateFormat
import java.util.Date

class MainActivity : ComponentActivity() {
    private val model: SheetModel by viewModels()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val colors = if (isSystemInDarkTheme()) darkColorScheme(
                primary = Color(0xFFFFB3BB), surface = Color(0xFF211B1C), background = Color(0xFF211B1C),
                surfaceContainer = Color(0xFF322A2B), onSurface = Color(0xFFF3E8E3)
            ) else lightColorScheme(
                primary = Color(0xFF782C3C), onPrimary = Color.White, surface = Color(0xFFFAF6EC),
                background = Color(0xFFFAF6EC), surfaceContainer = Color(0xFFF0E8D9), onSurface = Color(0xFF27201F),
                onSurfaceVariant = Color(0xFF584B49), outline = Color(0xFF806F6A)
            )
            MaterialTheme(colorScheme = colors) { Requiem(model) }
        }
    }
    override fun onStop() { super.onStop(); model.flush() }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Requiem(model: SheetModel) {
    val state by model.ui.collectAsStateWithLifecycle()
    var about by rememberSaveable { mutableStateOf(false) }
    val snack = remember { SnackbarHostState() }
    val c = state.character
    var announced by rememberSaveable(c?.id?.toString()) { mutableIntStateOf(0) }
    LaunchedEffect(state.overdraft) {
        if (state.overdraft > announced) {
            announced = state.overdraft
            snack.showSnackbar("Your available Experiences are now below zero.")
        }
    }
    BackHandler(enabled = c != null) { model.close() }
    Scaffold(topBar = {
        TopAppBar(title = { Text(if (c == null) "Requiem" else "Character sheet", fontFamily = FontFamily.Serif) },
            colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface),
            navigationIcon = { if (c != null) TextButton(onClick = model::close, enabled = !state.busy) { Text("Back") } },
            actions = {
                if (c == null) TextButton(onClick = { about = true }) { Text("About") }
                else if (c.creation == null) TextButton(onClick = model::close, enabled = !state.busy) { Text("Save") }
            })
    }, snackbarHost = { SnackbarHost(snack) }) { padding ->
        Column(Modifier.padding(padding).fillMaxSize().imePadding()) {
            state.error?.let {
                Surface(color = MaterialTheme.colorScheme.errorContainer) {
                    Column(Modifier.fillMaxWidth().padding(12.dp)) {
                        Text(it, Modifier.semantics { liveRegion = LiveRegionMode.Polite })
                        TextButton(onClick = { if (c == null) model.refresh() else model.flush() }) { Text("Retry") }
                    }
                }
            }
            when {
                c != null -> key(c.id) { SheetEditor(c, model.catalog, state.busy, model::edit) }
                state.busy -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                else -> Library(state.rows, model)
            }
        }
    }
    if (about) AlertDialog(onDismissRequest = { about = false }, title = { Text("About Requiem") }, text = {
        Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Image(painterResource(R.drawable.dark_pack), "Dark Pack", Modifier.size(72.dp))
            Text("This is unofficial Fan Content permitted under the Dark Pack. This app is not official World of Darkness material.")
            Text("Portions of the materials are the copyrights and trademarks of Paradox Interactive AB, and are used with permission. All rights reserved. For more information please visit worldofdarkness.com.")
        }
    }, confirmButton = { TextButton(onClick = { about = false }) { Text("Close") } })
}

@Composable
private fun Library(rows: List<LibraryRow>, model: SheetModel) {
    var confirmId by rememberSaveable { mutableStateOf<String?>(null) }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Image(painterResource(R.drawable.requiem_logo), "Vampire: The Requiem, Second Edition",
                    Modifier.width(158.dp).height(90.dp))
                SectionTitle("Characters")
                Text(if (rows.isEmpty()) "Create a blank sheet to start your chronicle." else "By last edit",
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                Button(onClick = model::create) { Text("New blank sheet") }
            }
        }
        items(rows, key = { it.id.toString() }) { row ->
            val title = row.name.ifBlank { if (row.problem == null) "Unnamed character" else "Unavailable character" }
            val description = row.problem ?: listOfNotNull(if (row.guided) "Guided · Read-only" else null,
                row.edited?.let { DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT)
                    .format(Date((it * 1000).toLong() + 978_307_200_000L)) }).joinToString("  ·  ")
            Surface(shape = RoundedCornerShape(12.dp), color = MaterialTheme.colorScheme.surfaceContainer) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f).clickable(enabled = row.problem == null, onClickLabel = "Open sheet") {
                        model.open(row.id)
                    }.padding(16.dp)) {
                        Text(title, style = MaterialTheme.typography.titleMedium)
                        Text(description, style = MaterialTheme.typography.bodySmall)
                    }
                    if (!row.guided && row.problem == null) TextButton(onClick = { confirmId = row.id.toString() }) { Text("Delete") }
                }
            }
        }
    }
    val selected = rows.firstOrNull { it.id.toString() == confirmId }
    if (selected != null) AlertDialog(onDismissRequest = { confirmId = null },
        title = { Text("Delete character?") },
        text = { Text("“${selected.name.ifBlank { "Unnamed character" }}” will be removed from this device.") },
        confirmButton = { TextButton(onClick = { confirmId = null; model.delete(selected.id) }) { Text("Delete") } },
        dismissButton = { TextButton(onClick = { confirmId = null }) { Text("Cancel") } })
}

@Composable
internal fun SectionTitle(text: String) {
    Text(text, Modifier.semantics { heading() }, style = MaterialTheme.typography.headlineSmall,
        fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold)
}
