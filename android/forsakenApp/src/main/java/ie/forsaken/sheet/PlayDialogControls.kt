package ie.forsaken.sheet

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import ie.chronicles.ui.*

internal data class DraftField(val label: String, val initial: String = "", val numeric: Boolean = false, val multiline: Boolean = false,
    val toggle: Boolean = false)

@Composable internal fun DraftDialog(title: String, fields: List<DraftField>, dismiss: () -> Unit,
    valid: (List<String>) -> Boolean = { it.firstOrNull()?.isNotBlank() == true }, supportingText: String? = null, save: (List<String>) -> Unit) {
    var values by rememberSaveable { mutableStateOf(fields.map { it.initial }) }
    AlertDialog(onDismissRequest=dismiss, title={SheetText(title)}, text={
        LazyColumn(verticalArrangement=Arrangement.spacedBy(8.dp)) {
            if(supportingText!=null) item { PlayNote(supportingText) }
            items(fields.indices.toList(),key={it}) { index ->
                val field=fields[index]
                if(field.toggle) PlaySwitch(field.label,values[index]=="yes",true) { checked -> values=values.toMutableList().also { it[index]=if(checked) "yes" else "no" } }
                else OutlinedTextField(values[index], { text -> values=values.toMutableList().also { it[index]=text } },
                    label={Text(field.label)}, singleLine=!field.multiline, modifier=Modifier.fillMaxWidth().testTag("play-input-$index"),
                    keyboardOptions=KeyboardOptions(keyboardType=if(field.numeric) KeyboardType.Number else KeyboardType.Text))
            }
        }
    }, confirmButton={TextButton(enabled=valid(values),onClick={save(values);dismiss()}) { SheetText("Save") }},
        dismissButton={TextButton(onClick=dismiss) { SheetText("Cancel") }})
}

internal data class PlayOption(val id: String, val title: String, val detail: String = "")

@Composable internal fun ChoiceDialog(title: String, options: List<PlayOption>, selected: String?, dismiss: () -> Unit, choose: (String) -> Unit) {
    AlertDialog(onDismissRequest=dismiss,title={SheetText(title)},text={
        LazyColumn {
            items(options,key={it.id}) { option ->
                Column(Modifier.fillMaxWidth().clickable(role=Role.RadioButton) { choose(option.id) }
                    .semantics(mergeDescendants=true) { this.selected=option.id==selected }.padding(vertical=12.dp)) {
                    SheetText(option.title,style=MaterialTheme.typography.titleMedium)
                    if(option.detail.isNotBlank()) SheetText(option.detail,style=MaterialTheme.typography.bodySmall)
                }
                SheetRule()
            }
        }
    },confirmButton={TextButton(onClick=dismiss) { SheetText("Cancel") }})
}

@Composable internal fun PlayConfirm(title: String, message: String, label: String, dismiss: () -> Unit, confirm: () -> Unit) {
    AlertDialog(onDismissRequest=dismiss,title={SheetText(title)},text={SheetText(message)},
        confirmButton={TextButton(onClick={confirm();dismiss()}) { SheetText(label) }},
        dismissButton={TextButton(onClick=dismiss) { SheetText("Cancel") }})
}

@Composable internal fun PlayInformationDialog(title: String, lines: List<Pair<String,String>>, dismiss: () -> Unit) {
    AlertDialog(onDismissRequest=dismiss,title={SheetText(title)},text={
        LazyColumn { items(lines) { (name,text) -> PlayInfo(name,text) } }
    },confirmButton={TextButton(onClick=dismiss) { SheetText("Done") }})
}
