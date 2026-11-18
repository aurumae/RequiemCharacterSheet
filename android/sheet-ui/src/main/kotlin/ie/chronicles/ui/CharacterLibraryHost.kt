package ie.chronicles.ui

import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ie.chronicles.core.StoredCharacter
import kotlinx.coroutines.delay

@Composable
fun <C : StoredCharacter, S : Any> CharacterLibraryHost(
    model: SheetLibraryModel<C>, activity: Class<*>, sections: (C) -> List<S>, title: (S) -> String,
    xp: @Composable (C, Boolean) -> Unit, aboutSheet: @Composable (() -> Unit) -> Unit,
    readOnly: Boolean = false, libraryNotice: String? = null,
    editor: @Composable (C, Boolean, S?, (S) -> Unit, () -> Unit) -> Unit,
) {
    val state by model.ui.collectAsStateWithLifecycle()
    var about by rememberSaveable { mutableStateOf(false) }
    val snack = remember { SnackbarHostState() }
    val focus = LocalFocusManager.current
    val context = LocalContext.current
    val importFile = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let(model::enqueueImport)
    }
    // A generic MIME type preserves the game extension; document providers append .json for application/json.
    val saveFile = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream"), model::saveExport)
    val c = state.character
    val available = c?.let(sections).orEmpty()
    var currentSection by rememberSaveable(c?.id?.toString()) { mutableStateOf<S?>(null) }
    var requestedSection by rememberSaveable(c?.id?.toString()) { mutableStateOf<S?>(null) }
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
                    ExportMode.Share -> context.startActivity(characterShareIntent(context, request, activity))
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
            if (c != null && available.isNotEmpty()) SheetToolbar(
                sections = available, current = currentSection?.takeIf { it in available } ?: available.first(), title = title,
                select = { focus.clearFocus(); requestedSection = it }, busy = state.busy, saved = saved,
                back = { focus.clearFocus(); model.close() }, save = {
                    focus.clearFocus()
                    if (readOnly) model.export(c.id, ExportMode.Save) else model.save()
                }, saveLabel = if (readOnly) "Save file" else "Save",
                xp = { xp(c, !state.busy) },
            )
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
                c != null -> key(c.id) { editor(c, state.busy, requestedSection, { currentSection = it }) { requestedSection = null } }
                state.busy -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                else -> Library(state.rows, model, importCharacter = { importFile.launch(arrayOf("*/*")) },
                    allowCreation = !readOnly, notice = libraryNotice, about = { about = true })
            }
        }
        SnackbarHost(snack, Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom = 32.dp))
    }
    if (about) aboutSheet { about = false }
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
