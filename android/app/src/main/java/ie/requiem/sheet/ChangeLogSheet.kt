package ie.requiem.sheet

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import ie.requiem.rules.CharacterSave
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ChangeLogSheet(c: CharacterSave, dismiss: () -> Unit) {
    val zone = ZoneId.systemDefault()
    fun instant(seconds: Double) = Instant.ofEpochMilli((seconds * 1000).toLong() + 978_307_200_000L)
    val days = c.changeLog.groupBy { instant(it.date).atZone(zone).toLocalDate() }.toSortedMap(reverseOrder())
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = SheetColors.band) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("Change Log", Modifier.weight(1f).semantics { heading() }, style = MaterialTheme.typography.titleMedium)
            TextButton(onClick = dismiss) { Text("Done") }
        }
        LazyColumn(Modifier.fillMaxWidth(), contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item {
                Surface(shape = RoundedCornerShape(16.dp), color = Color.White) {
                    Column {
                        ValueRow("Spent in total:", c.experiences - c.experiencesAvailable)
                        SheetRule()
                        ValueRow("Available:", c.experiencesAvailable, caution = c.experiencesAvailable < 0)
                    }
                }
            }
            if (days.isEmpty()) item {
                Text("Changes to your character’s traits appear here.", Modifier.padding(vertical = 16.dp),
                    color = SheetColors.muted, style = MaterialTheme.typography.bodyMedium)
            }
            days.forEach { (day, changes) ->
                item { SubsectionLabel(day.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL))) }
                items(changes.sortedByDescending { it.date }, key = { it.id.toString() }) { change ->
                    val amount = when {
                        change.experiences > 0 -> "Spent ${change.experiences}"
                        change.experiences < 0 -> "Refunded ${-change.experiences}"
                        else -> "Free"
                    }
                    Surface(shape = RoundedCornerShape(16.dp), color = Color.White) {
                        Row(Modifier.fillMaxWidth().padding(12.dp).semantics(mergeDescendants = true) {},
                            verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Column(Modifier.weight(1f)) {
                                Text(change.name, style = LocalSheetType.current.trait)
                                Text("${change.from} → ${change.to}  · " +
                                    instant(change.date).atZone(zone).format(DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)),
                                    style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                            }
                            Text(amount, Modifier.widthIn(max = 112.dp), style = MaterialTheme.typography.bodySmall, color = SheetColors.accent)
                        }
                    }
                }
            }
        }
    }
}
