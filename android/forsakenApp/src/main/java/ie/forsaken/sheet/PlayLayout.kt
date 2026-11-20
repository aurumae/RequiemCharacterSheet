package ie.forsaken.sheet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import ie.chronicles.ui.*
import ie.forsaken.rules.*

@Composable internal fun ForsakenLibraryHeading() {
    Row(Modifier.fillMaxWidth().padding(vertical = 14.dp).semantics { heading() },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        BrushLine("Characters-leading", true, Modifier.weight(1f).height(12.dp))
        SheetText("Characters", style = LocalSheetType.current.ratedTrait, color = SheetColors.accent)
        BrushLine("Characters-trailing", false, Modifier.weight(1f).height(12.dp))
    }
}

@Composable internal fun FormSelector(form: Form, editable: Boolean, select: (Form) -> Unit) {
    val scale = LocalDensity.current.fontScale.coerceAtLeast(1f)
    BoxWithConstraints(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp)) {
        val rowWidth=maxOf(maxWidth,320.dp*scale)
        Row(Modifier.horizontalScroll(rememberScrollState()).testTag("form-selector")) {
            Row(Modifier.width(rowWidth).background(SheetColors.band, CircleShape)
                .padding(3.dp).selectableGroup(), verticalAlignment = Alignment.CenterVertically) {
                Form.entries.forEach { item ->
                    Box(Modifier.weight(1f).heightIn(min = 48.dp)
                        .background(if (item == form) Color.White else Color.Transparent, CircleShape)
                        .selectable(item == form, enabled = editable, role = Role.RadioButton) { select(item) }
                        .semantics { contentDescription = "Form ${item.title}" }, contentAlignment = Alignment.Center) {
                        SheetText(item.title, style = MaterialTheme.typography.bodySmall.copy(fontWeight = if (item == form) FontWeight.Bold else FontWeight.Normal))
                    }
                }
            }
        }
    }
    SheetRule()
}

@Composable internal fun GiftHeading(name: String, count: String, open: (() -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().then(if (open == null) Modifier else Modifier.clickable(role = Role.Button, onClick = open))
        .padding(horizontal = 8.dp, vertical = 12.dp).semantics { heading() }, verticalAlignment = Alignment.CenterVertically) {
        SheetText(name, Modifier.weight(1f), style = LocalSheetType.current.subsection)
        SheetText(count, Modifier.padding(start = 8.dp), style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
    }
    SheetRule()
}

@Composable internal fun PlayEntryMenu(title: String, details: () -> Unit, edit: (() -> Unit)?, remove: () -> Unit) {
    var menu by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { menu = true }, modifier = Modifier.semantics { contentDescription = "Options for $title" }) { SheetIcon(SheetSymbol.More, SheetColors.muted) }
        DropdownMenu(menu, { menu = false }) {
            DropdownMenuItem(text = { SheetText("Details") }, onClick = { menu = false; details() })
            if (edit != null) DropdownMenuItem(text = { SheetText("Edit") }, onClick = { menu = false; edit() })
            DropdownMenuItem(text = { SheetText("Delete") }, onClick = { menu = false; remove() })
        }
    }
}

@Composable internal fun ChangeLogRow(count: Int, open: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = open).heightIn(min = 56.dp).padding(8.dp)
        .semantics(mergeDescendants = true) { contentDescription = "Change Log, $count entries" }, verticalAlignment = Alignment.CenterVertically) {
        SheetText("Change Log", Modifier.weight(1f), style = LocalSheetType.current.ratedTrait)
        SheetText(count.toString(), Modifier.padding(end = 8.dp), color = SheetColors.muted)
        SheetIcon(SheetSymbol.Chevron, SheetColors.muted)
    }
    SheetRule()
}
