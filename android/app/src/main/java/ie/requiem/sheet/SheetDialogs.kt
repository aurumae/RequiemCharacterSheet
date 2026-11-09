package ie.requiem.sheet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import ie.requiem.rules.*
import java.util.UUID

/** Dialogs live outside the scrolling rows so keyboard/rotation cannot dispose an editor. */
@Composable
internal fun SheetDialogs(route: String?, c: CharacterSave, catalog: Catalog, edit: (SheetEdit) -> Unit, navigate: (String?) -> Unit) {
    if (route == null) return
    if (route.startsWith("condition")) { key(route) { ConditionDialogs(route, c, catalog, edit, navigate) }; return }
    if (route.startsWith("identity")) { key(route) { IdentityDialogs(route, c, catalog, edit, navigate) }; return }
    if (route.startsWith("specialty|")) { key(route) { SpecialtyDialog(route, c, catalog, edit) { navigate(null) } }; return }
    if (route.startsWith("creation|")) { CreationDialogs(route, c, catalog, edit, navigate); return }
    val parts = route.split('|'); val type = parts[0]
    fun close() = navigate(null)
    key(route) {
        val newId = rememberSaveable { UUID.randomUUID().toString() }
        when (type) {
            "pick", "mysteryPick" -> {
                val mystery = type == "mysteryPick"
                val kind = if (mystery) EntryKind.Coil else EntryKind.valueOf(parts[1])
                EntryPicker(kind, c, catalog, mystery, choose = { entry ->
                    if (mystery) { edit(SheetEdit.Mystery(entry.source(), coilId = UUID.fromString(newId))); close() }
                    else if (kind == EntryKind.Merit && entry.qualifierPrompt != null) navigate("qualifierAdd|${entry.id}")
                    else { edit(SheetEdit.AddEntry(kind, entry.source(), id = UUID.fromString(newId))); close() }
                }, custom = { navigate(if (mystery) "mysteryAdd" else "customAdd|${kind.name}") },
                    none = { edit(SheetEdit.Mystery(TraitSource(custom = ""))); close() }, dismiss = ::close)
            }
            "detail", "delete", "customEdit" -> {
                val kind = EntryKind.valueOf(parts[1]); val id = UUID.fromString(parts[2])
                val row = c.entryRows(kind, catalog).firstOrNull { it.id == id }
                if (row != null) when (type) {
                    "detail" -> catalog.entry(kind.catalogKind, row.source)?.let { entry -> EntryDetailSheet(c.bookDetail(entry, catalog, row.rating ?: 0, row.qualifier), ::close) }
                    "delete" -> ConfirmRemoval(row.name.ifBlank { kind.title }, { edit(SheetEdit.RemoveEntry(kind, id)); close() }, ::close)
                    else -> CustomEntryDialog(kind, row, c, catalog, onCommit = { name, discipline, dots, cost ->
                        if (kind == EntryKind.Coil && c.coils.any { it.id == id && c.isMysteryCoil(it) }) edit(SheetEdit.Mystery(catalog.source(CatalogKind.mysteries, name), rename = true))
                        else edit(SheetEdit.RenameEntry(kind, id, name))
                        if (kind == EntryKind.Ritual) edit(SheetEdit.CustomRitual(id, catalog.source(CatalogKind.disciplines, discipline), dots))
                        if (kind == EntryKind.Devotion) edit(SheetEdit.CustomDevotionCost(id, cost))
                        close()
                    }, dismiss = ::close)
                }
            }
            "customAdd" -> {
                val kind = EntryKind.valueOf(parts[1])
                CustomEntryDialog(kind, null, c, catalog, onCommit = { name, discipline, dots, cost ->
                    val (source, qualifier) = if (kind == EntryKind.Merit) catalog.parseMerit(name) else catalog.source(kind.catalogKind, name) to null
                    val entry = catalog.entry(kind.catalogKind, source)
                    if (kind == EntryKind.Merit && entry?.qualifierPrompt != null &&
                        (qualifier == null || (c.qualifierChoices(entry)?.let { qualifier !in it } == true))) navigate("qualifierAdd|${entry.id}")
                    else { edit(SheetEdit.AddEntry(kind, source, qualifier, catalog.source(CatalogKind.disciplines, discipline), dots, cost, UUID.fromString(newId))); close() }
                }, dismiss = ::close)
            }
            "qualifierAdd", "qualifierEdit" -> {
                val merit = if (type == "qualifierEdit") c.merits.firstOrNull { it.id.toString() == parts[1] } else null
                val entry = catalog.entry(CatalogKind.merits, if (merit != null) merit.source.catalog else parts[1])
                if (entry != null) QualifierDialog(entry, c, merit?.qualifier.orEmpty(), if (merit == null) "Add" else "Done", { text ->
                    if (merit == null) edit(SheetEdit.AddEntry(EntryKind.Merit, entry.source(), text.ifBlank { null }, id = UUID.fromString(newId)))
                    else edit(SheetEdit.MeritQualifier(merit.id, text))
                    close()
                }, ::close)
            }
            "mysteryAdd", "mysteryEdit" -> TextPrompt(if (type == "mysteryAdd") "Custom Mystery" else "Edit Mystery", "Mystery name",
                if (type == "mysteryEdit") catalog.name(CatalogKind.mysteries, c.mystery) else "", false, false, { text ->
                    edit(SheetEdit.Mystery(catalog.source(CatalogKind.mysteries, text), rename = type == "mysteryEdit", coilId = UUID.fromString(newId))); close()
                }, ::close)
            "aspAdd", "asp", "touch" -> {
                val aspiration = if (type == "asp") c.aspirations.firstOrNull { it.id.toString() == parts[1] } else null
                val touchstone = if (type == "touch") c.touchstones.firstOrNull { it.level.toString() == parts[1] } else null
                TextPrompt(if (type == "touch") "Touchstone at Humanity ${parts[1]}" else "Aspiration", if (type == "touch") "Touchstone" else "Aspiration",
                    aspiration?.text ?: touchstone?.text.orEmpty(), true, true, { text ->
                        when (type) {
                            "aspAdd" -> edit(SheetEdit.AddAspiration(text, UUID.fromString(newId)))
                            "asp" -> aspiration?.let { edit(SheetEdit.AspirationText(it.id, text)) }
                            "touch" -> touchstone?.let { edit(SheetEdit.TouchstoneText(it.level, text)) }
                        }; close()
                    }, ::close)
            }
            "deleteAsp" -> c.aspirations.firstOrNull { it.id.toString() == parts[1] }?.let { aspiration ->
                ConfirmRemoval(aspiration.text.ifBlank { "this Aspiration" }, { edit(SheetEdit.RemoveAspiration(aspiration.id)); close() }, ::close)
            }
            "number" -> {
                val field = NumberField.valueOf(parts[1])
                NumberPrompt(field.title, c.number(field), c.numberRange(field), { edit(SheetEdit.Number(field, it)); close() }, ::close)
            }
        }
    }
}

@Composable
internal fun TextPrompt(title: String, label: String, initial: String, multiline: Boolean, allowEmpty: Boolean,
    commit: (String) -> Unit, dismiss: () -> Unit) {
    var draft by rememberSaveable { mutableStateOf(initial) }
    val focus = remember { FocusRequester() }
    AlertDialog(onDismissRequest = dismiss, title = { SheetText(title) }, text = {
        OutlinedTextField(value = draft, onValueChange = { draft = it }, label = { SheetText(label) }, singleLine = !multiline,
            minLines = if (multiline) 3 else 1, maxLines = if (multiline) 8 else 1,
            modifier = Modifier.fillMaxWidth().focusRequester(focus).revealWhileEditing(draft).testTag("text-prompt"),
            keyboardOptions = KeyboardOptions(imeAction = if (multiline) ImeAction.Default else ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { if (allowEmpty || draft.isNotBlank()) commit(draft.trim()) }))
        LaunchedEffect(Unit) { focus.requestFocus() }
    }, confirmButton = { TextButton(onClick = { commit(draft.trim()) }, enabled = allowEmpty || draft.isNotBlank()) { SheetText("Done") } },
        dismissButton = { TextButton(onClick = dismiss) { SheetText("Cancel") } })
}

@Composable
private fun NumberPrompt(title: String, initial: Int, legal: IntRange, commit: (Int) -> Unit, dismiss: () -> Unit) {
    var draft by rememberSaveable { mutableStateOf(initial.toString()) }
    val value = draft.toIntOrNull()
    AlertDialog(onDismissRequest = dismiss, title = { SheetText(title) }, text = {
        OutlinedTextField(value = draft, onValueChange = { draft = it }, label = { SheetText(title) }, singleLine = true,
            isError = value == null || value !in legal, supportingText = { SheetText("${legal.first}–${legal.last}") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { if (value != null && value in legal) commit(value) }), modifier = Modifier.testTag("number-prompt"))
    }, confirmButton = { TextButton(onClick = { value?.let(commit) }, enabled = value != null && value in legal) { SheetText("Done") } },
        dismissButton = { TextButton(onClick = dismiss) { SheetText("Cancel") } })
}

@Composable
private fun QualifierDialog(entry: BookEntry, c: CharacterSave, initial: String, action: String, commit: (String) -> Unit, dismiss: () -> Unit) {
    var draft by rememberSaveable { mutableStateOf(initial) }
    val options = c.qualifierChoices(entry)
    AlertDialog(onDismissRequest = dismiss, title = { SheetText(entry.name) }, text = {
        Column(Modifier.verticalScroll(rememberScrollState())) {
            SheetText(entry.qualifierPrompt.orEmpty())
            if (options != null) options.forEach { option ->
                Row(Modifier.fillMaxWidth().clickable { draft = option }, verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    RadioButton(selected = draft == option, onClick = { draft = option }); SheetText(if (entry.qualifierFromSpecialties) c.specialtyChoices.firstOrNull { it.specialty == option }?.label ?: option else option)
                }
            } else OutlinedTextField(value = draft, onValueChange = { draft = it }, label = { SheetText(entry.qualifierPrompt ?: "Qualifier") }, singleLine = true,
                modifier = Modifier.fillMaxWidth().testTag("qualifier-input"))
        }
    }, confirmButton = { TextButton(onClick = { commit(draft.trim()) }, enabled = options == null || draft in options) { SheetText(action) } },
        dismissButton = { TextButton(onClick = dismiss) { SheetText("Cancel") } })
}

@Composable
private fun CustomEntryDialog(kind: EntryKind, row: SheetEntry?, c: CharacterSave, catalog: Catalog,
    onCommit: (String, String, Int, Int) -> Unit, dismiss: () -> Unit) {
    var name by rememberSaveable { mutableStateOf(row?.name.orEmpty()) }
    val ritual = c.rituals.firstOrNull { it.id == row?.id }
    val devotion = c.devotions.firstOrNull { it.id == row?.id }
    var discipline by rememberSaveable { mutableStateOf(ritual?.let { catalog.name(CatalogKind.disciplines, it.discipline(catalog)) }
        ?: c.ritualDisciplines(catalog).firstOrNull()?.name ?: "Crúac") }
    var dots by rememberSaveable { mutableIntStateOf(ritual?.customDots ?: 1) }
    var cost by rememberSaveable { mutableStateOf((devotion?.customExperienceCost ?: 1).toString()) }
    val legalCost = cost.toIntOrNull()?.takeIf { it in 1..20 }
    val source = if (kind == EntryKind.Merit) catalog.parseMerit(name).first else catalog.source(kind.catalogKind, name)
    val restriction = if (row == null && kind == EntryKind.Discipline) catalog.entry(CatalogKind.disciplines, source)?.let { c.reasonCantLearn(it, catalog) } else null
    val blocked = restriction ?: if (row == null) c.creationEntryRejection(SheetEdit.AddEntry(kind, source,
        ritualDiscipline = catalog.source(CatalogKind.disciplines, discipline), ritualDots = dots), catalog) else if (kind == EntryKind.Ritual && !c.creationAllowsEdit(
            SheetEdit.CustomRitual(row.id, catalog.source(CatalogKind.disciplines, discipline), dots), catalog))
        "The ritual must fit its Discipline's starting dots" else if (kind == EntryKind.Devotion && !c.creationAllowsEdit(
            SheetEdit.CustomDevotionCost(row.id, legalCost ?: 1), catalog)) "Devotions are learned with Experiences after creation" else null
    val focus = remember { FocusRequester() }
    AlertDialog(onDismissRequest = dismiss, title = { SheetText(if (row == null) "Custom ${kind.title}" else "Edit ${kind.title}") }, text = {
        Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(value = name, onValueChange = { name = it }, label = { SheetText(if (kind == EntryKind.Bane) "Describe the Bane" else "${kind.title} name") },
                singleLine = kind != EntryKind.Bane, minLines = if (kind == EntryKind.Bane) 3 else 1, maxLines = 6,
                modifier = Modifier.fillMaxWidth().focusRequester(focus).revealWhileEditing(name).testTag("custom-name"))
            if (kind == EntryKind.Ritual) {
                OutlinedTextField(value = discipline, onValueChange = { discipline = it }, label = { SheetText("Ritual Discipline") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                ChoiceMenu("Choose Discipline", discipline, catalog.bookEntries(CatalogKind.disciplines).filter { it.isRitualDiscipline }.map { it.name }) { discipline = it }
                val rank = c.disciplines.filter { it.source == catalog.source(CatalogKind.disciplines, discipline) }.maxOfOrNull { it.rating } ?: 0
                val maxDots = if (c.creation == null) 5 else maxOf(row?.rating ?: 1, rank).coerceAtMost(5)
                ChoiceMenu("Ritual dots", dots.toString(), (1..maxDots).map { it.toString() }) { dots = it.toInt() }
            }
            if (kind == EntryKind.Devotion) OutlinedTextField(value = cost, onValueChange = { cost = it }, label = { SheetText("Experience cost (1–20)") }, singleLine = true,
                isError = legalCost == null, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), modifier = Modifier.fillMaxWidth().testTag("devotion-cost"))
            blocked?.let { WarningText(it) }
            LaunchedEffect(Unit) { focus.requestFocus() }
        }
    }, confirmButton = { TextButton(onClick = { onCommit(name.trim(), discipline.trim(), dots, legalCost ?: 1) },
        enabled = blocked == null && name.isNotBlank() && (kind != EntryKind.Devotion || legalCost != null) && (kind != EntryKind.Ritual || discipline.isNotBlank())) { SheetText(if (row == null) "Add" else "Done") } },
        dismissButton = { TextButton(onClick = dismiss) { SheetText("Cancel") } })
}

@Composable
internal fun ChoiceMenu(label: String, value: String, choices: List<String>, choose: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        TextButton(onClick = { expanded = true }) { SheetText("$label: $value") }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            choices.forEach { choice -> DropdownMenuItem(text = { SheetText(choice) }, onClick = { expanded = false; choose(choice) }) }
        }
    }
}
@Composable
private fun ConfirmRemoval(name: String, remove: () -> Unit, dismiss: () -> Unit) {
    AlertDialog(onDismissRequest = dismiss, title = { SheetText("Remove entry?") }, text = { SheetText("Remove “$name” from this character?") },
        confirmButton = { TextButton(onClick = remove) { SheetText("Remove") } }, dismissButton = { TextButton(onClick = dismiss) { SheetText("Cancel") } })
}
