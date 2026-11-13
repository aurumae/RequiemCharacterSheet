package ie.requiem.sheet

import androidx.compose.ui.platform.LocalFocusManager

import androidx.compose.ui.text.input.ImeAction

import androidx.compose.foundation.text.KeyboardOptions

import androidx.compose.foundation.text.KeyboardActions

import ie.chronicles.ui.*

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ie.requiem.rules.*
import java.util.UUID

@Composable
internal fun ConditionsSection(c: CharacterSave, catalog: Catalog, editable: Boolean, navigate: (String) -> Unit) {
    Column(Modifier.fillMaxWidth().background(Color.White)) {
        if (c.conditions.isEmpty()) SheetText("No Conditions", Modifier.padding(12.dp), color = SheetColors.muted)
        else {
            val pager = rememberPagerState { c.conditions.size }
            LaunchedEffect(c.conditions.map { it.id }) {
                if (pager.currentPage >= c.conditions.size) pager.scrollToPage(c.conditions.lastIndex)
            }
            HorizontalPager(pager, key = { c.conditions[it].id.toString() }, contentPadding = PaddingValues(start = 8.dp, end = 64.dp),
                pageSpacing = 8.dp, modifier = Modifier.padding(top = 8.dp).testTag("condition-carousel")) { index ->
                val condition = c.conditions[index]; val info = condition.info(catalog)
                Column(Modifier.fillMaxWidth().height(300.dp * LocalDensity.current.fontScale.coerceAtLeast(1f))
                    .clip(RoundedCornerShape(8.dp)).border(1.dp, SheetColors.accent.copy(alpha = .35f), RoundedCornerShape(8.dp))
                    .clickable(role = Role.Button, onClickLabel = "Open full Condition card") { navigate("condition|${condition.id}") }
                    .semantics(mergeDescendants = true) {}.testTag("condition-card-${condition.id}")) {
                    ConditionTitle(info)
                    Column(Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        if (condition.note.isNotBlank()) Text("${info.notePrompt}: ${condition.note}", style = MaterialTheme.typography.bodySmall, color = SheetColors.muted, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(info.effect, style = MaterialTheme.typography.bodySmall, maxLines = 4, overflow = TextOverflow.Ellipsis)
                        Text("Resolution: ${info.resolution}", style = MaterialTheme.typography.bodySmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        Text("Beat: ${info.beat ?: "n/a"}", style = MaterialTheme.typography.bodySmall, color = SheetColors.muted, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        SheetText("Tap for the full card", style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    }
                }
            }
            val page = pager.currentPage.coerceIn(c.conditions.indices)
            SheetText("${page + 1} of ${c.conditions.size}" + if (page < c.conditions.lastIndex) " · swipe for more" else "",
                Modifier.align(Alignment.CenterHorizontally).padding(12.dp), style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
        }
        AddSheetRow("Add Condition", editable) { navigate("conditionPick") }
    }
}

@Composable private fun ConditionTitle(info: ConditionInfo) {
    FlowRow(Modifier.fillMaxWidth().background(SheetColors.accent).padding(10.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        SheetText(info.name.ifBlank { "Custom Condition" }.uppercase(), style = LocalSheetType.current.subsection.copy(fontSize = 18.sp, lineHeight = 24.sp, letterSpacing = 0.sp), color = Color.White)
        if (info.persistent) SheetText("PERSISTENT", Modifier.border(1.dp, Color.White, CircleShape).padding(horizontal = 6.dp, vertical = 2.dp),
            style = MaterialTheme.typography.labelSmall, color = Color.White)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ConditionDialogs(route: String, c: CharacterSave, catalog: Catalog, edit: (SheetEdit) -> Unit, navigate: (String?) -> Unit) {
    val parts = route.split('|')
    when (parts[0]) {
        "conditionPick" -> {
            val newId = rememberSaveable { UUID.randomUUID().toString() }
            ConditionPicker(c, catalog, { source ->
                val id = UUID.fromString(newId)
                edit(SheetEdit.AddCondition(source, id)); navigate("condition|$id")
            }, { navigate(null) })
        }
        "condition" -> {
            val condition = c.conditions.firstOrNull { it.id.toString() == parts[1] }
            if (condition == null) { LaunchedEffect(route) { navigate(null) }; return }
            val info = condition.info(catalog)
            ModalBottomSheet(onDismissRequest = { navigate(null) }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Color.White) {
                Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).imePadding()) {
                    ModalHeading("Condition", "Done") { navigate(null) }
                    Column(Modifier.verticalScroll(rememberScrollState()).padding(bottom = 24.dp).testTag("condition-full-card")) {
                        Column(Modifier.clip(RoundedCornerShape(8.dp)).border(1.dp, SheetColors.accent.copy(alpha = .4f), RoundedCornerShape(8.dp))) {
                            ConditionTitle(info)
                            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                @Composable fun field(label: String, value: String, key: ConditionField, multiline: Boolean = false) {
                                    OutlinedTextField(value, { edit(SheetEdit.ConditionText(condition.id, key, it)) }, label = { SheetText(label) }, singleLine = !multiline,
                                        minLines = if (multiline) 2 else 1, modifier = Modifier.fillMaxWidth().revealWhileEditing(value).testTag("condition-${key.name}"))
                                }
                                field(info.notePrompt, condition.note, ConditionField.Note)
                                if (info.hasCounter) Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                    SheetText("Penalty: −${condition.counter}", Modifier.weight(1f), style = LocalSheetType.current.label)
                                    TextButton(onClick = { edit(SheetEdit.ConditionCounter(condition.id, condition.counter - 1)) }, enabled = condition.counter > 1,
                                        modifier = Modifier.semantics { contentDescription = "Decrease Condition penalty" }) { SheetText("−") }
                                    TextButton(onClick = { edit(SheetEdit.ConditionCounter(condition.id, condition.counter + 1)) }, enabled = condition.counter < 20,
                                        modifier = Modifier.semantics { contentDescription = "Increase Condition penalty" }) { SheetText("+") }
                                }
                                if (info.custom) {
                                    field("Name", condition.source.custom.orEmpty(), ConditionField.Name)
                                    field("What it does", condition.customEffect, ConditionField.Effect, true)
                                    field("Resolution", condition.customResolution, ConditionField.Resolution, true)
                                    field("Beat (leave empty if none)", condition.customBeat, ConditionField.Beat, true)
                                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                        SheetText("Persistent", Modifier.weight(1f), style = LocalSheetType.current.label)
                                        Switch(condition.customPersistent, { edit(SheetEdit.ConditionPersistent(condition.id, it)) }, modifier = Modifier.semantics { contentDescription = "Persistent Condition" })
                                    }
                                } else {
                                    SheetText(info.effect)
                                    SheetText("Resolution: ${info.resolution}")
                                }
                                if (!info.custom || info.beat != null) {
                                    SheetText("Beat: ${info.beat ?: "n/a"}", style = MaterialTheme.typography.bodySmall)
                                    if (info.beat != null) FilledTonalButton(colors = ButtonDefaults.filledTonalButtonColors(containerColor = SheetColors.accent.copy(alpha = .14f), contentColor = SheetColors.accent), onClick = { edit(SheetEdit.ConditionAction(condition.id, ConditionEvent.beat)) },
                                        modifier = Modifier.align(Alignment.End).testTag("condition-take-beat")) { SheetText("+ Beat") }
                                }
                                info.possibleSources?.let { SheetText("Possible sources: $it", style = MaterialTheme.typography.bodySmall, color = SheetColors.muted) }
                                if (info.citation.isNotBlank()) SheetText(info.citation, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    FilledTonalButton(colors = ButtonDefaults.filledTonalButtonColors(containerColor = SheetColors.accent.copy(alpha = .14f), contentColor = SheetColors.accent), onClick = { edit(SheetEdit.ConditionAction(condition.id, ConditionEvent.ended)); navigate(null) }, modifier = Modifier.testTag("condition-end")) { SheetText("End") }
                                    Button(onClick = { edit(SheetEdit.ConditionAction(condition.id, ConditionEvent.resolved)); navigate(null) }, modifier = Modifier.testTag("condition-resolve")) {
                                        SheetText(if (info.beatOnResolve) "Resolve · +1 Beat" else "Resolve", color = Color.White)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        "conditionEffects" -> {
            val effects = c.conditionEffects(parts[1], catalog)
            AlertDialog(onDismissRequest = { navigate(null) }, title = { SheetText("Conditions") }, text = {
                Column(Modifier.verticalScroll(rememberScrollState())) {
                    effects.forEach { effect -> TextButton(onClick = { navigate("condition|${effect.condition.id}") }) {
                        Column(Modifier.fillMaxWidth()) {
                            SheetText(effect.condition.info(catalog).name, style = LocalSheetType.current.trait)
                            SheetText(effect.text, style = MaterialTheme.typography.bodyMedium)
                            SheetText("Open full card ›", style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                        }
                    } }
                }
            }, confirmButton = { TextButton(onClick = { navigate(null) }) { SheetText("Done") } })
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable private fun ConditionPicker(c: CharacterSave, catalog: Catalog, choose: (TraitSource) -> Unit, dismiss: () -> Unit) {
    val focus = LocalFocusManager.current
    var search by rememberSaveable { mutableStateOf("") }
    val options = catalog.bookEntries(CatalogKind.conditions).filter { (it.name + " " + it.summary + " " + it.bookName).contains(search.trim(), true) }
    val recent = c.recentConditionIDs(catalog).mapNotNull { id -> options.firstOrNull { it.id == id } }
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Color.White) {
        Column(Modifier.padding(horizontal = 16.dp).imePadding()) {
            ModalHeading("Add Condition", "Cancel", dismiss)
            OutlinedTextField(search, { search = it }, label = { SheetText("Search Conditions") }, singleLine = true, keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done), keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }), modifier = Modifier.fillMaxWidth().testTag("condition-search"))
            LazyColumn(Modifier.weight(1f, fill = false).testTag("condition-options"), contentPadding = PaddingValues(bottom = 24.dp)) {
                val groups = (if (recent.isEmpty()) emptyList() else listOf(CatalogSection("recent", null, "Recently used", recent))) + catalog.bookSections(options.sortedBy { it.name }, { it })
                groups.forEach { section ->
                    item("group-${section.id}") { CatalogSectionHeading(section.book, section.title) }
                    items(section.entries, key = { "${section.id}/${it.id}" }) { entry ->
                        val info = CharacterCondition(entry.source()).info(catalog)
                        val allowed = c.canAddCondition(entry)
                        Column(Modifier.fillMaxWidth().clickable(enabled = allowed, role = Role.Button) { choose(entry.source()) }.padding(vertical = 12.dp)
                            .semantics(mergeDescendants = true) { stateDescription = if (allowed) "" else "Already on the sheet" }) {
                            Row {
                                SheetText(entry.name, Modifier.weight(1f), style = LocalSheetType.current.trait)
                                if (!allowed) SheetText("✓", color = SheetColors.accent)
                            }
                            SheetText(info.effect, style = MaterialTheme.typography.bodySmall)
                            if (info.persistent) SheetText("Persistent", style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                            SheetText("Beat: ${info.beat ?: "n/a"}", style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                            SheetText(entry.citation, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                        }
                        SheetRule()
                    }
                }
                if (options.isEmpty()) item { SheetText("No matching Conditions", Modifier.padding(12.dp)) }
                item { AddSheetRow("Custom Condition", true) { choose(TraitSource(custom = "")) } }
            }
        }
    }
}
