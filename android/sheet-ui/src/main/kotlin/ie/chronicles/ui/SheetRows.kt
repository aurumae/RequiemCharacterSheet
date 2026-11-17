package ie.chronicles.ui

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import ie.chronicles.core.WillpowerMark

@Composable
fun AddSheetRow(title: String, enabled: Boolean, click: () -> Unit) {
    Row(Modifier.fillMaxWidth().background(Color.White).clickable(enabled = enabled, onClick = click).heightIn(min = 52.dp).padding(8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        SheetIcon(SheetSymbol.Add, if (enabled) SheetColors.accent else SheetColors.muted)
        SheetText(title, color = if (enabled) SheetColors.accent else SheetColors.muted)
    }
}

@Composable
fun WrittenRow(text: String, placeholder: String, editable: Boolean, description: String, open: () -> Unit, remove: () -> Unit) {
    var menu by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth().background(Color.White), verticalAlignment = Alignment.Top) {
        SheetText(text.ifBlank { placeholder }, Modifier.weight(1f).clickable(enabled = editable, onClick = open).heightIn(min = 56.dp).padding(8.dp)
            .semantics { contentDescription = description }, style = LocalSheetType.current.trait)
        if (editable) Box {
            IconButton(onClick = { menu = true }, modifier = Modifier.semantics { contentDescription = "Options for $description" }) { SheetIcon(SheetSymbol.More, SheetColors.muted) }
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                DropdownMenuItem(text = { SheetText("Edit") }, onClick = { menu = false; open() })
                DropdownMenuItem(text = { SheetText("Delete") }, onClick = { menu = false; remove() })
            }
        }
    }
    SheetRule()
}

@Composable
fun ValueRow(label: String, value: Int, description: String = "$label $value", caution: Boolean = false, onConditions: (() -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(8.dp).semantics(mergeDescendants = true) { contentDescription = description },
        verticalAlignment = Alignment.CenterVertically) {
        SheetText(label, Modifier.weight(1f), style = LocalSheetType.current.label)
        if (onConditions != null) ConditionIndicator(label, onConditions)
        SheetText(value.toString(), style = LocalSheetType.current.label, color = if (caution) SheetColors.caution else SheetColors.accent)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun WillpowerBoxes(track: List<WillpowerMark>, capacity: Int, editable: Boolean, toggle: (Int) -> Unit) {
    val scale = LocalDensity.current.fontScale.coerceAtLeast(1f)
    CompactTargets {
        FlowRow(Modifier.fillMaxWidth().background(Color.White).padding(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            repeat(capacity.coerceAtLeast(0)) { index ->
                val spent = track.getOrElse(index) { WillpowerMark.none } == WillpowerMark.spent
                Column(Modifier.width(24.dp * scale).height(52.dp * scale).clickable(enabled = editable, role = Role.Button) { toggle(index) }
                    .semantics { contentDescription = "Willpower box ${index + 1} of ${capacity}"; stateDescription = if (spent) "spent" else "available" },
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterVertically)) {
                    RatingDot(true, diameter = 20.dp * scale)
                    Canvas(Modifier.size(20.dp * scale)) {
                        drawRect(Color.White); val stroke = 1.dp.toPx(); val p = 4.dp.toPx()
                        drawRect(SheetColors.ink, style = Stroke(stroke))
                        if (spent) {
                            drawLine(SheetColors.ink, Offset(p, p), Offset(size.width - p, size.height - p), stroke)
                            drawLine(SheetColors.ink, Offset(size.width - p, p), Offset(p, size.height - p), stroke)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun CounterRow(title: String, value: Int, editable: Boolean, canDecrease: Boolean, canIncrease: Boolean,
    change: (Int) -> Unit, open: () -> Unit) {
    @Composable fun buttons() {
        IconButton(onClick = { change(-1) }, enabled = editable && canDecrease,
            modifier = Modifier.semantics { contentDescription = "Decrease $title" }) { SheetText("−", style = MaterialTheme.typography.titleLarge) }
        IconButton(onClick = { change(1) }, enabled = editable && canIncrease,
            modifier = Modifier.semantics { contentDescription = "Increase $title" }) { SheetText("+", style = MaterialTheme.typography.titleLarge) }
    }
    @Composable fun valueText(modifier: Modifier) {
        SheetText(value.toString(), modifier.clickable(enabled = editable, onClick = open).heightIn(min = 48.dp).padding(vertical = 10.dp)
            .semantics { contentDescription = "$title: $value" }, style = LocalSheetType.current.label)
    }
    if (LocalDensity.current.fontScale > 1.3f) Column(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp)) {
        SheetText("$title:", Modifier.clickable(enabled = editable, onClick = open).padding(top = 8.dp), style = LocalSheetType.current.label)
        Row(verticalAlignment = Alignment.CenterVertically) { valueText(Modifier.weight(1f)); buttons() }
    } else Row(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        SheetText("$title:", Modifier.weight(1f).clickable(enabled = editable, onClick = open).padding(vertical = 12.dp), style = LocalSheetType.current.label)
        valueText(Modifier.padding(horizontal = 8.dp)); buttons()
    }
    SheetRule()
}

@Composable fun CatalogSectionHeading(book: String?, title: String) {
    if (book != null) SheetText(book, Modifier.fillMaxWidth().padding(top = 20.dp, bottom = 6.dp).semantics { heading() },
        style = LocalSheetType.current.trait, color = SheetColors.accent)
    if (title.isNotBlank()) SubsectionLabel(title)
}

@Composable
fun ModalHeading(title: String, action: String, onAction: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        SheetText(title, Modifier.weight(1f).semantics { heading() }, style = LocalSheetType.current.section)
        TextButton(onClick = onAction) { SheetText(action) }
    }
}
