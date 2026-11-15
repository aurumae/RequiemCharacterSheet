package ie.requiem.sheet

import ie.chronicles.ui.*

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
import ie.requiem.rules.*
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ChangeLogSheet(c: CharacterSave, catalog: Catalog, dismiss: () -> Unit) {
    val zone = ZoneId.systemDefault()
    fun instant(seconds: Double) = Instant.ofEpochMilli((seconds * 1000).toLong() + 978_307_200_000L)
    val days = c.changeLog.groupBy { instant(it.date).atZone(zone).toLocalDate() }.toSortedMap(reverseOrder())
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = SheetColors.band) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            SheetText("Change Log", Modifier.weight(1f).semantics { heading() }, style = MaterialTheme.typography.titleMedium)
            TextButton(onClick = dismiss) { SheetText("Done") }
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
                SheetText("Changes to your character’s traits appear here.", Modifier.padding(vertical = 16.dp),
                    color = SheetColors.muted, style = MaterialTheme.typography.bodyMedium)
            }
            days.forEach { (day, changes) ->
                item { SubsectionLabel(day.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL))) }
                items(changes.sortedByDescending { it.date }, key = { it.id.toString() }) { change ->
                    val amount = when {
                        (change.beats ?: 0) > 0 -> "+${change.beats} Beat"
                        change.trait.startsWith("condition:") -> ""
                        change.duringCreation == true -> "Creation"
                        change.experiences > 0 -> "Spent ${change.experiences}"
                        change.experiences < 0 -> "Refunded ${-change.experiences}"
                        change.xpMode -> "No cost"
                        else -> "Free"
                    }
                    val changeText = when (change.trait.substringBefore(':')) {
                        "condition" -> change.event?.name?.replaceFirstChar { it.uppercaseChar() } ?: if (change.to > change.from) "Added" else "Ended"
                        "ritual", "scale" -> if (change.to > change.from) "Learned" else "Removed"
                        "devotion" -> when {
                            change.from == 0 -> "Learned"
                            change.to == 0 -> "Removed"
                            else -> "Cost ${change.from} → ${change.to}"
                        }
                        else -> "${change.from} → ${change.to}"
                    }
                    Surface(shape = RoundedCornerShape(16.dp), color = Color.White) {
                        Row(Modifier.fillMaxWidth().padding(12.dp).semantics(mergeDescendants = true) {},
                            verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Column(Modifier.weight(1f)) {
                                SheetText(c.changeName(change, catalog), style = LocalSheetType.current.trait)
                                SheetText("$changeText  · " +
                                    instant(change.date).atZone(zone).format(DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)),
                                    style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                            }
                            Column(Modifier.widthIn(max = 112.dp), horizontalAlignment = Alignment.End) {
                                SheetText(amount, style = MaterialTheme.typography.bodySmall,
                                    color = if (change.experiences == 0) SheetColors.muted else SheetColors.accent)
                                if (!change.xpMode && change.duringCreation != true) SheetText("XP Mode off",
                                    style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                            }
                        }
                    }
                }
            }
        }
    }
}
