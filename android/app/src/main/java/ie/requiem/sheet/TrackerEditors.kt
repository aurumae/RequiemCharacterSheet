package ie.requiem.sheet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import ie.chronicles.ui.*
import ie.requiem.rules.*

@Composable
internal fun WillpowerTrack(c: CharacterSave, editable: Boolean, edit: (SheetEdit) -> Unit) =
    WillpowerBoxes(c.willpowerTrack, c.willpower, editable) { edit(SheetEdit.Willpower(it)) }

@Composable
internal fun NumberCounter(c: CharacterSave, field: NumberField, editable: Boolean, edit: (SheetEdit) -> Unit, open: () -> Unit) {
    val value = c.number(field)
    val legal = c.numberRange(field)
    CounterRow(field.title, value, editable, value > legal.first, field == NumberField.Beats || value < legal.last,
        change = { edit(SheetEdit.Counter(field, it)) }, open = open)
}

@Composable
internal fun ClanBaneRow(c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit) {
    val bane = c.clanBane(catalog) ?: return
    Column(Modifier.fillMaxWidth().background(Color.White).padding(8.dp)) {
        SheetText("Clan Bane: ${bane.name}", style = LocalSheetType.current.trait)
        SheetText(bane.summary, style = MaterialTheme.typography.bodySmall)
        Row(Modifier.fillMaxWidth().toggleable(c.clanBaneActive, enabled = editable, role = Role.Switch, onValueChange = { edit(SheetEdit.ClanBane(it)) })
            .semantics { contentDescription = "${bane.name} in effect" }, verticalAlignment = Alignment.CenterVertically) {
            SheetText("In effect", Modifier.weight(1f)); Switch(c.clanBaneActive, onCheckedChange = null, enabled = editable)
        }
        SheetText(when {
            c.clanBaneActive && bane.extraBane -> "Record the extra Bane below; it counts toward the limit of 3."
            c.clanBaneActive -> "Stays in effect if Humanity rises again."
            c.humanity <= bane.threshold -> "Switched off. Turns on again if Humanity falls to ${bane.threshold} from above."
            else -> "Takes effect when Humanity falls to ${bane.threshold}."
        }, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
    }
    SheetRule()
}

@Composable
internal fun ElderBaneRow(c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit) {
    val bane = c.elderBane(catalog) ?: return
    Column(Modifier.fillMaxWidth().background(Color.White).padding(8.dp)) {
        SheetText("Elder Bane: ${bane.name}", style = LocalSheetType.current.trait)
        SheetText(bane.summary, style = MaterialTheme.typography.bodySmall)
        Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).toggleable(c.elderBaneActive, enabled = editable, role = Role.Switch,
            onValueChange = { edit(SheetEdit.ElderBane(it)) }).semantics { contentDescription = "${bane.name} in effect" }, verticalAlignment = Alignment.CenterVertically) {
            SheetText("In effect", Modifier.weight(1f)); Switch(c.elderBaneActive, onCheckedChange = null, enabled = editable)
        }
        SheetText(when {
            c.elderBaneActive -> "Stays in effect if Humanity rises again. Does not count toward the limit of 3 Banes."
            c.humanity <= bane.threshold -> "Switched off. Turns on again if Humanity falls to ${bane.threshold} from above."
            else -> "Takes effect when Humanity falls to ${bane.threshold}."
        }, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
        SheetText(bane.citation, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
    }
    SheetRule()
}

@Composable
internal fun HumanityRows(c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit, openTouchstone: (Int) -> Unit) {
    c.humanityCap(catalog)?.let { cap -> SheetText(cap.description, Modifier.fillMaxWidth().background(Color.White).padding(8.dp),
        style = MaterialTheme.typography.bodySmall, color = if (c.humanity > cap.limit) SheetColors.accent else SheetColors.muted) }
    c.touchstones.sortedByDescending { it.level }.forEach { touchstone ->
        Row(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            SheetText(touchstone.level.toString(), Modifier.widthIn(min = 32.dp), style = LocalSheetType.current.label)
            SheetText(touchstone.text.ifBlank { "Add Touchstone" }, Modifier.weight(1f).clickable(enabled = editable) { openTouchstone(touchstone.level) }
                .heightIn(min = 52.dp).padding(vertical = 14.dp, horizontal = 4.dp).semantics { contentDescription = "Touchstone at Humanity ${touchstone.level}" },
                style = MaterialTheme.typography.bodySmall, color = if (touchstone.text.isBlank()) SheetColors.muted else SheetColors.ink,
                textDecoration = if (touchstone.text.isNotBlank() && touchstone.level > c.humanity) TextDecoration.LineThrough else null)
            Box(Modifier.size(48.dp).clickable(enabled = editable && touchstone.level in 1..c.creationMaximum("humanity:humanity", 10, catalog)) { edit(SheetEdit.Number(NumberField.Humanity, touchstone.level)) }
                .semantics { contentDescription = "Humanity ${touchstone.level}"; stateDescription = if (touchstone.level <= c.humanity) "Reached" else "Not reached" },
                contentAlignment = Alignment.Center) { RatingDot(touchstone.level <= c.humanity) }
        }
        SheetRule()
    }
}

@Composable
internal fun Advantages(c: CharacterSave, catalog: Catalog, editable: Boolean, onConditions: (() -> Unit)? = null, number: (NumberField) -> Unit) {
    Column(Modifier.fillMaxWidth().background(Color.White)) {
        ValueRow("Size:", c.effectiveSize(catalog)); SheetRule()
        ValueRow("Speed:", c.speed(catalog)); SheetRule()
        ValueRow("Defense (Athletics):", c.defense(catalog), onConditions = onConditions); SheetRule()
        c.alternativeDefenseSkills(catalog).filter { it in listOf("brawl", "weaponry") }.forEach { skill ->
            ValueRow("Defense (${skillDefinitions.first { it.id == skill }.name}):", c.defense(catalog, skill), onConditions = onConditions); SheetRule()
        }
        Row(Modifier.fillMaxWidth().clickable(enabled = editable) { number(NumberField.Armor) }.padding(8.dp).heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
            SheetText("Armor:", Modifier.weight(1f), style = LocalSheetType.current.label)
            SheetText(c.armor.toString(), style = LocalSheetType.current.label)
        }
        SheetRule(); ValueRow("Initiative Mod:", c.initiative(catalog)); SheetRule()
        SubsectionLabel("Combat Dice Pools")
        for (skill in listOf("brawl", "firearms", "weaponry")) {
            ValueRow("${skillDefinitions.first { it.id == skill }.name} Pool:", c.combatPool(skill, catalog)); SheetRule()
        }
    }
}

@Composable
internal fun BloodlineBaneRow(c: CharacterSave, catalog: Catalog) {
    val bane = c.bloodlineBane(catalog) ?: return
    Column(Modifier.fillMaxWidth().background(Color.White).padding(8.dp).semantics(mergeDescendants = true) {}) {
        SheetText("${bane.bloodline} Bane: ${bane.name}", style = LocalSheetType.current.trait)
        SheetText(bane.summary, style = MaterialTheme.typography.bodySmall)
        SheetText(bane.citation, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
    }
    SheetRule()
}
