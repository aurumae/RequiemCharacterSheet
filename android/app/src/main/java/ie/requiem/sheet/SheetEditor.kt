package ie.requiem.sheet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import ie.requiem.rules.*

@Composable
internal fun SheetEditor(c: CharacterSave, catalog: Catalog, busy: Boolean, edit: (SheetEdit) -> Unit) {
    val editable = c.creation == null && !busy
    var log by rememberSaveable { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        if (c.creation != null) {
            SectionBand("CHARACTER CREATION")
            Text("Guided creation · Read-only", Modifier.fillMaxWidth().background(Color.White).padding(8.dp),
                color = SheetColors.muted)
        }
        SectionBand("CHARACTER")
        NameRow(c.name, editable) { edit(SheetEdit.Rename(it)) }
        SheetRule()
        Spacer(Modifier.height(12.dp))
        SectionBand("ATTRIBUTES")
        SubsectionLabel("Physical")
        StaminaControl(c, catalog, editable, edit)
        SheetRule()
        Spacer(Modifier.height(16.dp))
        SectionBand("HEALTH")
        HealthTrack(c, catalog, editable, edit)
        Spacer(Modifier.height(16.dp))
        SectionBand("EXPERIENCE")
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
            Row(Modifier.fillMaxWidth().clickable { log = true }.heightIn(min = 56.dp).padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Text("Change Log", Modifier.weight(1f), style = LocalSheetType.current.trait)
                Text(c.changeLog.size.toString(), color = SheetColors.muted, style = MaterialTheme.typography.bodySmall)
                SheetIcon(SheetSymbol.Chevron, SheetColors.muted)
            }
        }
        Spacer(Modifier.height(16.dp))
    }
    if (log) ChangeLogSheet(c) { log = false }
}

@Composable
private fun NameRow(name: String, editable: Boolean, update: (String) -> Unit) {
    val focus = LocalFocusManager.current
    val stacked = LocalDensity.current.fontScale > 1.3f
    @Composable fun field(modifier: Modifier) {
        BasicTextField(value = name, onValueChange = update, readOnly = !editable, singleLine = true,
            textStyle = MaterialTheme.typography.bodyMedium.copy(color = SheetColors.ink, textAlign = if (stacked) TextAlign.Start else TextAlign.End),
            cursorBrush = SolidColor(SheetColors.accent),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }),
            modifier = modifier.heightIn(min = 48.dp).semantics { contentDescription = "Character name" },
            decorationBox = { text ->
                Box(Modifier.fillMaxWidth(), contentAlignment = if (stacked) Alignment.CenterStart else Alignment.CenterEnd) {
                    if (name.isBlank()) Text("Tap to edit", style = MaterialTheme.typography.bodyMedium, color = SheetColors.muted)
                    text()
                }
            })
    }
    if (stacked) Column(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp, vertical = 8.dp)) {
        Text("Name:", style = LocalSheetType.current.label)
        field(Modifier.fillMaxWidth())
    } else Row(Modifier.fillMaxWidth().background(Color.White).heightIn(min = 60.dp).padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("Name:", style = LocalSheetType.current.label)
        field(Modifier.weight(1f))
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
