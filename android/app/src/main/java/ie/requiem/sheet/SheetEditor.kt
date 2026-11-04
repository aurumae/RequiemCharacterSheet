package ie.requiem.sheet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import ie.requiem.rules.*

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun SheetEditor(c: CharacterSave, catalog: Catalog, busy: Boolean, edit: (SheetEdit) -> Unit) {
    val editable = c.creation == null && !busy
    val focus = LocalFocusManager.current
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (c.creation != null) {
            SectionTitle(c.name.ifBlank { "Unnamed character" })
            Text("Guided creation · Read-only", color = MaterialTheme.colorScheme.primary)
            Text("This character is still in guided creation. Its choices are preserved.")
        } else OutlinedTextField(value = c.name, onValueChange = { edit(SheetEdit.Rename(it)) },
            modifier = Modifier.fillMaxWidth(), label = { Text("Character name") }, singleLine = true,
            enabled = editable, keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }))
        HorizontalDivider()
        StaminaControl(c, catalog, editable, edit)
        val health = c.health(catalog).coerceAtLeast(0)
        SectionTitle("Health · $health")
        Text(if (c.creation == null) "Tap a box to cycle its damage." else "Damage marked on this sheet.", style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            repeat(health) { index ->
                val value = c.healthTrack.getOrElse(index) { Damage.none }
                val symbol = when (value) { Damage.none -> ""; Damage.bashing -> "/"; Damage.lethal -> "×"; Damage.aggravated -> "✳" }
                val mark = if (value == Damage.none) "unmarked" else value.name
                val label = "Health box ${index + 1} of $health"
                Box(Modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp)
                    .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(6.dp))
                    .clickable(enabled = editable, role = Role.Button, onClickLabel = "Cycle damage") { edit(SheetEdit.Mark(index)) }
                    .semantics { contentDescription = label; stateDescription = mark },
                    contentAlignment = Alignment.Center) {
                    Text(symbol, Modifier.clearAndSetSemantics {}, style = MaterialTheme.typography.titleLarge)
                }
            }
        }
        HorizontalDivider()
        SectionTitle("Experiences")
        Text("${c.experiencesAvailable} XP available", style = MaterialTheme.typography.titleMedium,
            color = if (c.experiencesAvailable < 0) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface)
        Row(Modifier.fillMaxWidth().toggleable(value = c.xpMode, enabled = editable, role = Role.Switch,
            onValueChange = { edit(SheetEdit.XpMode(it)) }).padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("XP Mode", fontWeight = FontWeight.Medium)
                Text(if (c.xpMode) "New Stamina dots cost 4 XP each." else "New dots are recorded for free.",
                    style = MaterialTheme.typography.bodySmall)
            }
            Switch(checked = c.xpMode, onCheckedChange = null, enabled = editable)
        }
        if (c.changeLog.isNotEmpty()) {
            SectionTitle("Change log")
            for (change in c.changeLog.asReversed()) {
                val cost = when {
                    change.experiences > 0 -> "${change.experiences} XP spent"
                    change.experiences < 0 -> "${-change.experiences} XP refunded"
                    else -> "Free"
                }
                Text("${change.name}  ${change.from} → ${change.to}  ·  $cost")
            }
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun StaminaControl(c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit) {
    val base = c.stamina
    val bonus = c.staminaBonus(catalog)
    val cap = c.staminaCap
    fun change(delta: Int): Boolean {
        if (!editable || base + delta !in 1..cap) return false
        edit(SheetEdit.Stamina(delta))
        return true
    }
    // Sighted players get two large tap targets. TalkBack encounters one adjustable trait.
    Column(Modifier.fillMaxWidth().clearAndSetSemantics {
        contentDescription = "Stamina"
        stateDescription = "$base base, $bonus bonus"
        if (editable) {
            progressBarRangeInfo = ProgressBarRangeInfo(base.toFloat(), 1f..cap.toFloat(), cap - 2)
            setProgress { target ->
                val to = Math.round(target).coerceIn(1, cap)
                repeat(kotlin.math.abs(to - base)) { edit(SheetEdit.Stamina(if (to > base) 1 else -1)) }
                to != base
            }
            customActions = buildList {
                if (base < cap) add(CustomAccessibilityAction("Raise Stamina") { change(1) })
                if (base > 1) add(CustomAccessibilityAction("Lower Stamina") { change(-1) })
            }
        }
    }) {
        SectionTitle("Stamina")
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedButton(onClick = { change(-1) }, enabled = editable && base > 1,
                contentPadding = PaddingValues(10.dp), modifier = Modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp)) { Text("−") }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("$base / $cap", style = MaterialTheme.typography.titleLarge)
                Text("●".repeat(base) + "○".repeat(cap - base), color = MaterialTheme.colorScheme.primary,
                    style = MaterialTheme.typography.labelSmall)
            }
            OutlinedButton(onClick = { change(1) }, enabled = editable && base < cap,
                contentPadding = PaddingValues(10.dp), modifier = Modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp)) { Text("+") }
        }
        if (bonus != 0) Text("Base $base · Bonus $bonus", style = MaterialTheme.typography.bodySmall)
    }
}
