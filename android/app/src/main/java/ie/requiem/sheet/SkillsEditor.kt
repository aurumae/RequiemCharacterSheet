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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import ie.requiem.rules.*

@Composable
internal fun SkillEditor(definition: TraitDefinition, skill: Skill, c: CharacterSave, editable: Boolean, catalog: Catalog, edit: (SheetEdit) -> Unit) {
    var editing by rememberSaveable { mutableStateOf<Int?>(null) }
    var previous by rememberSaveable { mutableStateOf("") }
    var draft by rememberSaveable { mutableStateOf("") }
    Column(Modifier.fillMaxWidth().background(Color.White)) {
        TraitRatingControl(definition.name, skill.rating, 0, legalRatings(RatingKind.Skill, c.bloodPotency), editable, allowedValues = c.skillChoices(skill.skill, catalog)) {
            edit(SheetEdit.SkillRating(skill.skill, it))
        }
        skill.specialties.forEachIndexed { index, specialty ->
            Text(specialty, Modifier.fillMaxWidth().heightIn(min = 48.dp)
                .clickable(enabled = editable) { previous = specialty; draft = specialty; editing = index }
                .padding(horizontal = 8.dp, vertical = 12.dp)
                .semantics { contentDescription = "${definition.name} specialty: $specialty" },
                style = MaterialTheme.typography.bodySmall)
        }
        Box(Modifier.fillMaxWidth().heightIn(min = 40.dp).clickable(enabled = editable && c.canAddSpecialty) { previous = ""; draft = ""; editing = -1 }
            .padding(horizontal = 8.dp, vertical = 8.dp)
            .semantics { contentDescription = "Add ${definition.name} specialty" }) {
            Text(if (c.canAddSpecialty) "Add Specialty" else "3 starting Specialties chosen", style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
        }
    }
    if (editing != null && editable) {
        val adding = editing == -1
        val focus = remember { FocusRequester() }
        fun commit(text: String) {
            val index = editing ?: return
            if (index < 0) edit(SheetEdit.AddSpecialty(skill.skill, text))
            else edit(SheetEdit.ReplaceSpecialty(skill.skill, index, previous, text))
            editing = null
        }
        AlertDialog(onDismissRequest = { editing = null },
            title = { Text(if (adding) "Add Specialty" else "Edit Specialty") },
            text = {
                Column {
                    Text(definition.name, Modifier.padding(bottom = 8.dp))
                    OutlinedTextField(value = draft, onValueChange = { draft = it }, singleLine = true, label = { Text("Specialty") },
                        modifier = Modifier.fillMaxWidth().focusRequester(focus).testTag("specialty-input"),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                        keyboardActions = KeyboardActions(onDone = { if (!adding || draft.isNotBlank()) commit(draft) }))
                    LaunchedEffect(Unit) { focus.requestFocus() }
                }
            }, confirmButton = { TextButton(onClick = { commit(draft) }, enabled = !adding || draft.isNotBlank()) { Text(if (adding) "Add" else "Save") } },
            dismissButton = {
                Row {
                    if (!adding) TextButton(onClick = { commit("") }) { Text("Delete") }
                    TextButton(onClick = { editing = null }) { Text("Cancel") }
                }
            })
    }
}
