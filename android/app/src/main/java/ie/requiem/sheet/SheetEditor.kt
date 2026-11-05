package ie.requiem.sheet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import ie.requiem.rules.*

internal enum class SheetSection(val title: String, val itemIndex: Int) {
    Character("Character", 0), Attributes("Attributes", 1), Skills("Skills", 2), Health("Health", 5), Experience("Experience", 6)
}

@Composable
internal fun SheetEditor(c: CharacterSave, catalog: Catalog, busy: Boolean, edit: (SheetEdit) -> Unit,
    section: SheetSection?, onSectionHandled: () -> Unit) {
    val editable = c.creation == null && !busy
    var log by rememberSaveable { mutableStateOf(false) }
    val list = rememberLazyListState()
    LaunchedEffect(section) {
        if (section != null) { list.scrollToItem(section.itemIndex); onSectionHandled() }
    }
    Column(Modifier.fillMaxSize()) {
        if (c.creation != null) Text("Guided creation · Read-only", Modifier.fillMaxWidth().background(Color.White).padding(8.dp),
            color = SheetColors.muted)
        LazyColumn(state = list, modifier = Modifier.weight(1f).testTag("character-sheet")) {
            item("character") {
                SectionBand("CHARACTER")
                CharacterDetail.entries.forEach { field ->
                    key(field) { CharacterDetailRow(field, c, catalog, editable, edit) }
                    SheetRule()
                }
                Spacer(Modifier.height(12.dp))
            }
            item("attributes") {
                SectionBand("ATTRIBUTES")
                TraitCategory.entries.forEach { category ->
                    SubsectionLabel(category.title)
                    attributeDefinitions.filter { it.category == category }.forEach { definition ->
                        val attribute = c.attributes.first { it.attribute == definition.id }
                        key(definition.id) {
                            TraitRatingControl(definition.name, attribute.rating, c.attributeBonus(definition.id, catalog),
                                legalRatings(RatingKind.Attribute, c.bloodPotency), editable) { edit(SheetEdit.AttributeRating(definition.id, it)) }
                        }
                        SheetRule()
                    }
                }
                Spacer(Modifier.height(16.dp))
            }
            TraitCategory.entries.forEach { category ->
                item("skills-${category.name}") {
                    if (category == TraitCategory.Mental) SectionBand("SKILLS")
                    SubsectionLabel(category.title)
                    Text("(${category.unskilledPenalty} unskilled)", Modifier.fillMaxWidth().background(Color.White).padding(start = 8.dp, bottom = 4.dp),
                        style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    skillDefinitions.filter { it.category == category }.forEach { definition ->
                        key(definition.id) { SkillEditor(definition, c.skills.first { it.skill == definition.id }, c, editable, edit) }
                        SheetRule()
                    }
                }
            }
            item("health") {
                Spacer(Modifier.height(16.dp))
                SectionBand("HEALTH")
                HealthTrack(c, catalog, editable, edit)
                Spacer(Modifier.height(16.dp))
            }
            item("experience") {
                SectionBand("EXPERIENCE")
                ExperienceSection(c, editable, edit) { log = true }
                Spacer(Modifier.height(16.dp))
            }
        }
    }
    if (log) ChangeLogSheet(c) { log = false }
}

@Composable
private fun ExperienceSection(c: CharacterSave, editable: Boolean, edit: (SheetEdit) -> Unit, showLog: () -> Unit) {
        Column(Modifier.background(Color.White)) {
            Row(Modifier.fillMaxWidth().toggleable(value = c.xpMode, enabled = editable, role = Role.Switch,
                onValueChange = { edit(SheetEdit.XpMode(it)) }).padding(8.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("XP Mode", style = LocalSheetType.current.label)
                    Text(if (c.creation != null) "Starting dots are free." else if (c.xpMode)
                        "Raising a trait spends Experiences; lowering it refunds what it cost."
                        else "Changes are free, e.g. Storyteller awards or entering an existing character.",
                        style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                }
                Switch(checked = c.xpMode, onCheckedChange = null, enabled = editable)
            }
            SheetRule()
            ValueRow("Earned:", c.experiences, description = "${c.experiences} Experiences earned")
            SheetRule()
            ValueRow("Spent:", c.experiences - c.experiencesAvailable, description = "${c.experiences - c.experiencesAvailable} Experiences spent")
            SheetRule()
            ValueRow("Available:", c.experiencesAvailable, description = "${c.experiencesAvailable} XP available",
                caution = c.experiencesAvailable < 0)
            SheetRule()
            Row(Modifier.fillMaxWidth().clickable { showLog() }.heightIn(min = 56.dp).padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Text("Change Log", Modifier.weight(1f), style = LocalSheetType.current.trait)
                Text(c.changeLog.size.toString(), color = SheetColors.muted, style = MaterialTheme.typography.bodySmall)
                SheetIcon(SheetSymbol.Chevron, SheetColors.muted)
            }
        }

}

@Composable
internal fun ValueRow(label: String, value: Int, description: String = "$label $value", caution: Boolean = false) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(8.dp).clearAndSetSemantics { contentDescription = description },
        verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f), style = LocalSheetType.current.label)
        Text(value.toString(), style = LocalSheetType.current.label, color = if (caution) SheetColors.caution else SheetColors.accent)
    }
}
