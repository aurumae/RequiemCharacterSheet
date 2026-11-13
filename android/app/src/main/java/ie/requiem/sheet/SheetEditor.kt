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

internal enum class SheetSection(val title: String, val itemKey: String) {
    Creation("Character Creation", "creation"), Character("Character", "character"), Attributes("Attributes", "attributes"), Skills("Skills", "skills-Mental"),
    Disciplines("Disciplines", "disciplines"), Devotions("Devotions", "devotions"), Rituals("Rituals", "rituals"),
    Coils("Coils of the Dragon", "coils"), Merits("Merits", "merits"), Aspirations("Aspirations", "aspirations"), Banes("Banes", "banes"),
    Health("Health", "health"), Willpower("Willpower", "willpower"), BloodPotency("Blood Potency", "blood-potency"),
    Vitae("Vitae", "vitae"), Humanity("Humanity", "humanity"), Advantages("Advantages", "advantages"), Experience("Experience", "experience"), Conditions("Conditions", "conditions");
    companion object {
        fun available(c: CharacterSave, catalog: Catalog): List<SheetSection> = entries.filter {
            (it != Creation || c.creation != null) && (it != Rituals || c.showsRituals(catalog)) && (it != Coils || c.showsCoils)
        }
    }
}

@Composable
internal fun SheetEditor(c: CharacterSave, catalog: Catalog, busy: Boolean, edit: (SheetEdit) -> Unit,
    section: SheetSection?, onCurrentSection: (SheetSection) -> Unit, onSectionHandled: () -> Unit) {
    val editable = !busy
    var log by rememberSaveable { mutableStateOf(false) }
    var overlay by rememberSaveable { mutableStateOf<String?>(null) }
    val list = rememberLazyListState()
    var jumping by remember { mutableStateOf(false) }
    var localSection by rememberSaveable { mutableStateOf<SheetSection?>(null) }
    val lineage = "${c.clan}/${c.bloodline}"
    var previousLineage by rememberSaveable { mutableStateOf(lineage) }
    LaunchedEffect(lineage) {
        if (lineage != previousLineage && c.needsFavoredAttribute(catalog)) overlay = "creation|favored"
        previousLineage = lineage
    }
    val keys = SheetSection.available(c, catalog).flatMap { if (it == SheetSection.Skills) TraitCategory.entries.map { category -> "skills-${category.name}" } else listOf(it.itemKey) }
    val reportSection by rememberUpdatedState(onCurrentSection)
    LaunchedEffect(list, keys) {
        snapshotFlow { Triple(list.firstVisibleItemIndex, list.firstVisibleItemScrollOffset, list.isScrollInProgress) }.collect { (index, _, scrolling) ->
            if (scrolling && !jumping) {
                val key = keys.getOrNull(index)
                SheetSection.available(c, catalog).firstOrNull { it.itemKey == key || (it == SheetSection.Skills && key?.startsWith("skills-") == true) }?.let(reportSection)
            }
        }
    }
    fun conditionAction(target: String): (() -> Unit)? = if (c.conditionEffects(target, catalog).isEmpty()) null else ({ overlay = "conditionEffects|$target" })
    @Composable fun category(category: TraitCategory, skills: Boolean) {
        Row(Modifier.fillMaxWidth().background(Color.White), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f)) { CategoryHeader(category, skills, c, catalog, editable, edit) }
            conditionAction("${if (skills) "skillCategory" else "attributeCategory"}:${category.name.lowercase()}")?.let { ConditionIndicator(category.title, it) }
        }
    }
    @Composable fun entries(kind: EntryKind) {
        val rows = c.entryRows(kind, catalog)
        @Composable fun row(item: SheetEntry) {
            PowerEntryRow(kind, item, editable, edit,
                open = { overlay = "${if (item.known) "detail" else "customEdit"}|${kind.name}|${item.id}" },
                editQualifier = if (kind == EntryKind.Merit && catalog.entry(CatalogKind.merits, item.source)?.qualifierPrompt != null)
                    ({ overlay = "qualifierEdit|${item.id}" }) else null,
                remove = { overlay = "delete|${kind.name}|${item.id}" })
        }
        if (kind == EntryKind.Ritual) {
            val groups = (c.ritualDisciplines(catalog).map { it.source() } + c.rituals.map { it.discipline(catalog) }).distinct()
            groups.forEach { discipline ->
                val group = c.rituals.filter { it.discipline(catalog) == discipline }.sortedBy { it.dots(catalog) }
                val title = catalog.name(CatalogKind.disciplines, discipline).ifBlank { "Other Rituals" }
                SubsectionLabel(title)
                val rank = discipline.catalog?.let { c.disciplineRating(it) } ?: 0
                if (rank > 0) SheetText("Known: ${group.size} · Free with $title dots: $rank", Modifier.fillMaxWidth().background(Color.White).padding(8.dp),
                    style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                group.forEach { ritual -> rows.firstOrNull { it.id == ritual.id }?.let { key(it.id) { row(it) } } }
            }
        } else rows.forEach { key(it.id) { row(it) } }
        if (kind == EntryKind.Bane && c.banes.size >= 3) SheetText("A vampire can have at most 3 Banes.", Modifier.fillMaxWidth().background(Color.White).padding(8.dp),
            style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
        else if (c.creation != null && kind in listOf(EntryKind.Devotion, EntryKind.Scale, EntryKind.Coil)) SheetText(
            if (kind == EntryKind.Coil) "Choose your Mystery above to add its Coil." else "Learn ${kind.title}s with Experiences after creation.",
            Modifier.fillMaxWidth().background(Color.White).padding(8.dp), style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
        else AddSheetRow("Add ${kind.title}", editable) { overlay = "pick|${kind.name}" }
    }
    @Composable fun band(title: String) { Spacer(Modifier.height(16.dp)); SectionBand(title) }
    LaunchedEffect(section, localSection) {
        val target = localSection ?: section
        if (target != null) {
            jumping = true
            try { keys.indexOf(target.itemKey).takeIf { it >= 0 }?.let { list.scrollToItem(it); reportSection(target) } }
            finally { jumping = false; localSection = null; onSectionHandled() }
        }
    }
    Column(Modifier.fillMaxSize()) {
        LazyColumn(state = list, modifier = Modifier.weight(1f).pageEdges().testTag("character-sheet"), contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp)) {
            if (c.creation != null) item("creation") {
                CreationPanel(c, catalog, editable, navigate = { overlay = it }, jump = { localSection = it })
                Spacer(Modifier.height(16.dp))
            }
            item("character") {
                SectionBand("CHARACTER")
                CharacterDetail.entries.forEach { field ->
                    key(field) { CharacterDetailRow(field, c, catalog, editable, edit) { overlay = it } }
                    SheetRule()
                }
                Spacer(Modifier.height(12.dp))
            }
            item("attributes") {
                SectionBand("ATTRIBUTES")
                TraitCategory.entries.forEach { category ->
                    category(category, false)
                    attributeDefinitions.filter { it.category == category }.forEach { definition ->
                        val attribute = c.attributes.first { it.attribute == definition.id }
                        key(definition.id) {
                            TraitRatingControl(definition.name, attribute.rating, c.attributeBonus(definition.id, catalog) + c.rollBonus(definition.id, catalog),
                                legalRatings(RatingKind.Attribute, c.bloodPotency), editable, allowedValues = c.attributeChoices(definition.id, catalog),
                                onConditions = conditionAction("attribute:${definition.id}"),
                                note = if (c.creation?.favoredAttribute == definition.id) "Includes the ${c.favoredAttributeGiver(catalog)?.name.orEmpty()} dot" else null) { edit(SheetEdit.AttributeRating(definition.id, it)) }
                        }
                        SheetRule()
                    }
                }
                Spacer(Modifier.height(16.dp))
            }
            TraitCategory.entries.forEach { category ->
                item("skills-${category.name}") {
                    if (category == TraitCategory.Mental) SectionBand("SKILLS")
                    category(category, true)
                    SheetText("(${category.unskilledPenalty} unskilled)", Modifier.fillMaxWidth().background(Color.White).padding(start = 8.dp, bottom = 4.dp),
                        style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    skillDefinitions.filter { it.category == category }.forEach { definition ->
                        key(definition.id) { SkillEditor(definition, c.skills.first { it.skill == definition.id }, c, editable, catalog, edit) { overlay = it } }
                        SheetRule()
                    }
                }
            }
            item("disciplines") { band("DISCIPLINES"); entries(EntryKind.Discipline) }
            item("devotions") { band("DEVOTIONS"); entries(EntryKind.Devotion) }
            if (c.showsRituals(catalog)) item("rituals") { band("RITUALS"); entries(EntryKind.Ritual) }
            if (c.showsCoils) item("coils") {
                band("COILS OF THE DRAGON")
                Row(Modifier.fillMaxWidth().background(Color.White).padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    SheetText("Mystery", Modifier.weight(1f), style = LocalSheetType.current.label)
                    TextButton(onClick = { overlay = "mysteryPick" }, enabled = editable) { SheetText(catalog.name(CatalogKind.mysteries, c.mystery).ifBlank { "Choose" }) }
                }
                if (!c.mystery.custom.isNullOrBlank()) TextButton(onClick = { overlay = "mysteryEdit" }, enabled = editable) { SheetText("Edit Mystery name") }
                entries(EntryKind.Coil)
                SubsectionLabel("Scales"); entries(EntryKind.Scale)
            }
            item("merits") { band("MERITS"); entries(EntryKind.Merit) }
            item("aspirations") {
                band("ASPIRATIONS")
                c.aspirations.forEachIndexed { index, aspiration -> key(aspiration.id) {
                    WrittenRow(aspiration.text, "Tap to write an Aspiration", editable, "Aspiration ${index + 1}",
                        open = { overlay = "asp|${aspiration.id}" }, remove = { overlay = "deleteAsp|${aspiration.id}" })
                } }
                AddSheetRow("Add Aspiration", editable) { overlay = "aspAdd" }
            }
            item("banes") { band("BANES"); ClanBaneRow(c, catalog, editable, edit); ElderBaneRow(c, catalog, editable, edit); BloodlineBaneRow(c, catalog); entries(EntryKind.Bane) }
            item("health") {
                Spacer(Modifier.height(16.dp))
                SectionBand("HEALTH")
                HealthTrack(c, catalog, editable, edit)
                Spacer(Modifier.height(16.dp))
            }
            item("willpower") { band("WILLPOWER"); WillpowerTrack(c, editable, edit) }
            item("blood-potency") {
                band("BLOOD POTENCY")
                TraitRatingControl("Blood Potency", c.bloodPotency, 0, 0..10, editable, allowedValues = (0..c.creationMaximum("bloodPotency:bloodPotency", 10, catalog)).toList()) { edit(SheetEdit.Number(NumberField.BloodPotency, it)) }
            }
            item("vitae") {
                band("VITAE")
                Column(Modifier.background(Color.White)) {
                    ValueRow("Vitae Per Turn:", c.vitaePerTurn); SheetRule(); ValueRow("Max Vitae:", c.maxVitae); SheetRule()
                    NumberCounter(c, NumberField.Vitae, editable, edit) { overlay = "number|Vitae" }
                }
            }
            item("humanity") { band("HUMANITY"); HumanityRows(c, catalog, editable, edit) { overlay = "touch|$it" } }
            item("advantages") { band("ADVANTAGES"); Advantages(c, catalog, editable, conditionAction("defense")) { overlay = "number|${it.name}" } }
            item("experience") {
                SectionBand("EXPERIENCE")
                ExperienceSection(c, editable, edit, number = { overlay = "number|${it.name}" }) { log = true }
                Spacer(Modifier.height(16.dp))
            }
            item("conditions") { SectionBand("CONDITIONS"); ConditionsSection(c, catalog, editable) { overlay = it } }
        }
    }
    if (log) ChangeLogSheet(c, catalog) { log = false }
    SheetDialogs(overlay, c, catalog, edit) { overlay = it }
}

@Composable
private fun ExperienceSection(c: CharacterSave, editable: Boolean, edit: (SheetEdit) -> Unit, number: (NumberField) -> Unit, showLog: () -> Unit) {
        val xpEnabled = c.xpMode && c.creation == null
        Column(Modifier.background(Color.White)) {
            Row(Modifier.fillMaxWidth().toggleable(value = xpEnabled, enabled = editable && c.creation == null, role = Role.Switch,
                onValueChange = { edit(SheetEdit.XpMode(it)) }).padding(8.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    SheetText("XP Mode", style = LocalSheetType.current.label)
                    SheetText(if (c.creation != null) "Starting dots are free." else if (c.xpMode)
                        "Raising a trait spends Experiences. Lowering a paid trait refunds it, except Humanity and Blood Potency."
                        else "Changes are free, e.g. Storyteller awards or entering an existing character.",
                        style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                }
                Switch(checked = xpEnabled, onCheckedChange = null, enabled = editable && c.creation == null)
            }
            SheetRule()
            NumberCounter(c, NumberField.Beats, editable, edit) { number(NumberField.Beats) }
            NumberCounter(c, NumberField.Experiences, editable, edit) { number(NumberField.Experiences) }
            ValueRow("Spent:", c.experiences - c.experiencesAvailable, description = "${c.experiences - c.experiencesAvailable} Experiences spent")
            SheetRule()
            ValueRow("Available:", c.experiencesAvailable, description = "${c.experiencesAvailable} XP available",
                caution = c.experiencesAvailable < 0)
            SheetRule()
            Row(Modifier.fillMaxWidth().clickable { showLog() }.heightIn(min = 56.dp).padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically) {
                SheetText("Change Log", Modifier.weight(1f), style = LocalSheetType.current.trait)
                SheetText(c.changeLog.size.toString(), color = SheetColors.muted, style = MaterialTheme.typography.bodySmall)
                SheetIcon(SheetSymbol.Chevron, SheetColors.muted)
            }
        }

}

@Composable
internal fun ValueRow(label: String, value: Int, description: String = "$label $value", caution: Boolean = false, onConditions: (() -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(8.dp).semantics(mergeDescendants = true) { contentDescription = description },
        verticalAlignment = Alignment.CenterVertically) {
        SheetText(label, Modifier.weight(1f), style = LocalSheetType.current.label)
        if (onConditions != null) ConditionIndicator(label, onConditions)
        SheetText(value.toString(), style = LocalSheetType.current.label, color = if (caution) SheetColors.caution else SheetColors.accent)
    }
}
