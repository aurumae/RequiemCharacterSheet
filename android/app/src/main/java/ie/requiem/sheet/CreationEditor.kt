package ie.requiem.sheet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.selectable
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import ie.requiem.rules.*

@Composable
internal fun CreationPanel(c: CharacterSave, catalog: Catalog, editable: Boolean, navigate: (String) -> Unit, jump: (SheetSection) -> Unit) {
    val steps = c.creationSteps(catalog)
    val report = c.creationReport(catalog)
    SectionBand("CHARACTER CREATION")
    Column(Modifier.fillMaxWidth().background(Color.White).padding(8.dp)) {
        val done = steps.count { it.status == CreationStepStatus.Done }
        Text("$done of 7 steps done", style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
        LinearProgressIndicator(progress = { done / 7f }, modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
            color = SheetColors.accent, trackColor = Color(0xFFE5E5EA), gapSize = 0.dp, drawStopIndicator = {})
    }
    steps.forEach { step ->
        val target = when (step.number) {
            1, 5 -> SheetSection.Character
            2 -> SheetSection.Attributes
            3, 4 -> SheetSection.Skills
            6 -> SheetSection.Merits
            else -> SheetSection.Advantages
        }
        Row(Modifier.fillMaxWidth().background(Color.White).clickable { jump(target) }.padding(8.dp)
            .semantics(mergeDescendants = true) { stateDescription = step.status.title }.testTag("creation-step-${step.number}"),
            verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.width(24.dp).padding(top = 3.dp)) { CreationStepMark(step.status) }
            Column {
                Text("${step.number}. ${step.title}", style = LocalSheetType.current.trait)
                Text(step.detail, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
            }
        }
        SheetRule()
    }
    if (c.favoredAttributes(catalog).isNotEmpty()) Row(Modifier.fillMaxWidth().background(Color.White)
        .clickable(enabled = editable) { navigate("creation|favored") }.padding(8.dp).heightIn(min = 48.dp)
        .semantics { contentDescription = "Choose the clan's favoured Attribute" }, verticalAlignment = Alignment.CenterVertically) {
        Text("${catalog.name(CatalogKind.clans, c.clan)} dot", Modifier.weight(1f), style = LocalSheetType.current.trait)
        Text(c.creation?.favoredAttribute?.let(::traitName) ?: "Choose", color = SheetColors.accent)
        SheetIcon(SheetSymbol.Chevron)
    }
    Column(Modifier.fillMaxWidth().background(Color.White).padding(8.dp)) {
        report.problems.sortedBy { it.description }.forEach { WarningText(it.description) }
        Button(enabled = editable && report.withinLimits, onClick = {
            navigate(if (steps.all { it.status == CreationStepStatus.Done }) "creation|finish" else "creation|reminder")
        }, modifier = Modifier.fillMaxWidth().testTag("finish-creation")) { Text("Finish Creation") }
        TextButton(onClick = { navigate("creation|leave") }, enabled = editable, modifier = Modifier.align(Alignment.CenterHorizontally)) { Text("Leave Guided Creation") }
    }
}

@Composable
private fun CreationStepMark(status: CreationStepStatus) {
    Canvas(Modifier.size(20.dp).clearAndSetSemantics {}) {
        val middle = size.width / 2
        val stroke = 1.5.dp.toPx()
        val radius = middle - stroke / 2
        if (status == CreationStepStatus.InProgress) drawCircle(SheetColors.muted, radius, style = Stroke(stroke))
        else {
            drawCircle(if (status == CreationStepStatus.Done) SheetColors.accent else SheetColors.caution, radius)
            if (status == CreationStepStatus.Done) {
                drawLine(Color.White, Offset(middle * .5f, middle), Offset(middle * .85f, middle * 1.4f), stroke, StrokeCap.Round)
                drawLine(Color.White, Offset(middle * .85f, middle * 1.4f), Offset(middle * 1.5f, middle * .6f), stroke, StrokeCap.Round)
            } else {
                drawLine(Color.White, Offset(middle, middle * .5f), Offset(middle, middle * 1.1f), stroke, StrokeCap.Round)
                drawCircle(Color.White, stroke / 2, Offset(middle, middle * 1.5f))
            }
        }
    }
}

@Composable
internal fun CategoryHeader(category: TraitCategory, skills: Boolean, c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit) {
    if (c.creation == null) { SubsectionLabel(category.title); return }
    var expanded by remember { mutableStateOf(false) }
    val report = c.creationReport(catalog)
    val budget = (if (skills) report.skills else report.attributes).getValue(category)
    val allotments = if (skills) CreationRules.skillDots else CreationRules.attributeDots
    val description = "${category.title} ${if (skills) "Skill" else "Attribute"} priority"
    @Composable fun menu() {
        Box {
            TextButton(onClick = { expanded = true }, enabled = editable,
                modifier = Modifier.semantics {
                    contentDescription = description
                    stateDescription = budget.priority?.let { "${it.title}, ${budget.remaining} dots left" } ?: "Not chosen"
                }) {
                Text(budget.priority?.let { "${it.title} · ${if (budget.remaining < 0) "${-budget.remaining} over" else "${budget.remaining} left"}" } ?: "Choose priority",
                    color = if (budget.remaining < 0) SheetColors.caution else SheetColors.accent)
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                CreationPriority.entries.forEach { priority ->
                    DropdownMenuItem(text = { Text("${priority.title}: ${allotments[priority.ordinal]} dots") },
                        modifier = Modifier.semantics { selected = budget.priority == priority },
                        onClick = { expanded = false; edit(SheetEdit.Priority(category, priority, skills)) })
                }
            }
        }
    }
    if (LocalDensity.current.fontScale > 1.3f) Column(Modifier.fillMaxWidth().background(Color.White)) { SubsectionLabel(category.title); menu() }
    else Row(Modifier.fillMaxWidth().background(Color.White), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.weight(1f)) { SubsectionLabel(category.title) }; menu()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun CreationDialogs(route: String, c: CharacterSave, catalog: Catalog, edit: (SheetEdit) -> Unit, navigate: (String?) -> Unit) {
    val state = c.creation ?: return
    val parts = route.split('|')
    when (parts[1]) {
        "favored" -> AlertDialog(onDismissRequest = { navigate(null) }, title = { Text("${catalog.name(CatalogKind.clans, c.clan)} Favoured Attribute") }, text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                Text("The clan gives one free dot to one of these. It doesn't count against your 5, 4 and 3 Attribute dots.")
                c.favoredAttributes(catalog).forEach { id ->
                    TextButton(onClick = { edit(SheetEdit.FavoredAttribute(id)); navigate(null) }, modifier = Modifier.fillMaxWidth().testTag("favored-$id")) { Text(traitName(id)) }
                }
            }
        }, confirmButton = { TextButton(onClick = { navigate(null) }) { Text("Not Now") } })
        "leave" -> AlertDialog(onDismissRequest = { navigate(null) }, title = { Text("Leave guided creation?") },
            text = { Text("The character keeps everything so far, without the starting-dot limits, as if made with a blank sheet. No bonus Experiences are awarded.") },
            confirmButton = { TextButton(onClick = { edit(SheetEdit.LeaveCreation); navigate(null) }) { Text("Leave Guided Creation") } },
            dismissButton = { TextButton(onClick = { navigate(null) }) { Text("Cancel") } })
        "reminder" -> AlertDialog(onDismissRequest = { navigate(null) }, title = { Text("Some steps aren't done") }, text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                c.creationSteps(catalog).filter { it.status != CreationStepStatus.Done }.forEach { step ->
                    Text("${step.title}: ${step.detail}", Modifier.padding(bottom = 8.dp))
                }
            }
        }, confirmButton = { TextButton(onClick = { navigate("creation|finish|anyway") }, enabled = c.creationReport(catalog).withinLimits) { Text("Finish Anyway") } },
            dismissButton = { TextButton(onClick = { navigate(null) }) { Text("Keep Going") } })
        "finish" -> ModalBottomSheet(onDismissRequest = { navigate(null) },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Color.White) {
            Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                ModalHeading("Finish Creation", "Cancel") { navigate(null) }
                LazyColumn(Modifier.weight(1f, fill = false).testTag("creation-ranks")) {
                    item { Text("If your Storyteller allows a more experienced vampire, choose how experienced. The bonus Experiences are added when you finish, and XP Mode turns on.", Modifier.padding(vertical = 12.dp)) }
                    item { SubsectionLabel("Experienced Kindred") }
                    items(CreationRules.ranks) { (name, bonus) ->
                        Row(Modifier.fillMaxWidth().selectable(selected = state.bonusExperiences == bonus, role = Role.RadioButton,
                            onClick = { edit(SheetEdit.CreationBonus(bonus)) }).testTag("creation-rank-$bonus").padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically) {
                            RadioButton(selected = state.bonusExperiences == bonus, onClick = null)
                            Text(name, Modifier.weight(1f).padding(horizontal = 8.dp), style = LocalSheetType.current.trait)
                            if (bonus > 0) Text("+$bonus", color = SheetColors.muted)
                        }
                    }
                }
                Button(onClick = { edit(SheetEdit.FinishCreation(allowIncomplete = parts.getOrNull(2) == "anyway")); navigate(null) },
                    enabled = c.creationReport(catalog).withinLimits && CreationRules.ranks.any { it.second == state.bonusExperiences },
                    modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp).testTag("confirm-finish-creation")) { Text("Finish") }
            }
        }
    }
}
