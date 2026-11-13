package ie.requiem.sheet

import ie.chronicles.ui.*

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
internal fun SkillEditor(definition: TraitDefinition, skill: Skill, c: CharacterSave, editable: Boolean, catalog: Catalog, edit: (SheetEdit) -> Unit, navigate: (String) -> Unit) {
    Column(Modifier.fillMaxWidth().background(Color.White)) {
        TraitRatingControl(definition.name, skill.rating, 0, legalRatings(RatingKind.Skill, c.bloodPotency), editable, allowedValues = c.skillChoices(skill.skill, catalog),
            onConditions = if (c.conditionEffects("skill:${skill.skill}", catalog).isEmpty()) null else ({ navigate("conditionEffects|skill:${skill.skill}") })) {
            edit(SheetEdit.SkillRating(skill.skill, it))
        }
        skill.specialties.forEachIndexed { index, specialty ->
            SheetText(specialty, Modifier.fillMaxWidth().heightIn(min = 48.dp)
                .clickable(enabled = editable) { navigate("specialty|${skill.skill}|$index") }
                .padding(horizontal = 8.dp, vertical = 12.dp)
                .semantics { contentDescription = "${definition.name} specialty: $specialty" },
                style = MaterialTheme.typography.bodySmall)
        }
        Box(Modifier.fillMaxWidth().heightIn(min = 40.dp).clickable(enabled = editable && c.canAddSpecialty) { navigate("specialty|${skill.skill}|-1") }
            .padding(horizontal = 8.dp, vertical = 8.dp)
            .semantics { contentDescription = "Add ${definition.name} specialty" }) {
            SheetText(if (c.canAddSpecialty) "Add Specialty" else "3 starting Specialties chosen", style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
        }
    }
}

@Composable
internal fun SpecialtyDialog(route: String, c: CharacterSave, catalog: Catalog, edit: (SheetEdit) -> Unit, dismiss: () -> Unit) {
    val parts = route.split('|'); val skill = c.skills.firstOrNull { it.skill == parts[1] } ?: return
    val index = parts[2].toInt(); val adding = index < 0
    val previous = rememberSaveable { skill.specialties.getOrNull(index).orEmpty() }
    var draft by rememberSaveable { mutableStateOf(previous) }
    val focus = remember { FocusRequester() }
    fun commit(text: String) {
        if (adding) edit(SheetEdit.AddSpecialty(skill.skill, text))
        else edit(SheetEdit.ReplaceSpecialty(skill.skill, index, previous, text))
        dismiss()
    }
    AlertDialog(onDismissRequest = dismiss,
        title = { SheetText(if (adding) "Add Specialty" else "Edit Specialty") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                SheetText(traitName(skill.skill), Modifier.padding(bottom = 8.dp))
                OutlinedTextField(draft, { draft = it }, singleLine = true, label = { SheetText("Specialty") },
                    modifier = Modifier.fillMaxWidth().focusRequester(focus).testTag("specialty-input"),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { if (!adding || draft.isNotBlank()) commit(draft) }))
                val following = if (adding) emptyList() else c.meritsFollowing(previous, catalog)
                if (following.isNotEmpty()) SheetText("Used by " + following.joinToString { it.displayName(catalog) } +
                    ". Renaming the last Specialty with this name updates these Merits. Deleting it removes them and refunds paid dots when XP Mode is on.",
                    Modifier.padding(top = 12.dp), style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                LaunchedEffect(Unit) { focus.requestFocus() }
            }
        }, confirmButton = { TextButton(onClick = { commit(draft) }, enabled = !adding || draft.isNotBlank()) { SheetText(if (adding) "Add" else "Save") } },
        dismissButton = { Row {
            if (!adding) TextButton(onClick = { commit("") }) { SheetText("Delete") }
            TextButton(onClick = dismiss) { SheetText("Cancel") }
        } })
}
