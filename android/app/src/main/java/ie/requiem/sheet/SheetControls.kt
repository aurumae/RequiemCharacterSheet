package ie.requiem.sheet

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.platform.ViewConfiguration
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.DpSize
import ie.requiem.rules.*

internal enum class SheetSymbol { Back, More, Add, Chevron, Choose }
@Composable
internal fun SheetIcon(symbol: SheetSymbol, color: Color = SheetColors.accent) {
    Canvas(Modifier.size(22.dp)) {
        val w = size.width; val h = size.height; val stroke = 1.6.dp.toPx()
        when (symbol) {
            SheetSymbol.Back -> {
                drawLine(color, Offset(w * .65f, h * .18f), Offset(w * .32f, h * .5f), stroke)
                drawLine(color, Offset(w * .32f, h * .5f), Offset(w * .65f, h * .82f), stroke)
            }
            SheetSymbol.Chevron -> {
                drawLine(color, Offset(w * .35f, h * .25f), Offset(w * .6f, h * .5f), stroke)
                drawLine(color, Offset(w * .6f, h * .5f), Offset(w * .35f, h * .75f), stroke)
            }
            SheetSymbol.Choose -> for (y in listOf(.25f, .5f, .75f)) {
                drawCircle(color, 1.dp.toPx(), Offset(w * .15f, h * y))
                drawLine(color, Offset(w * .35f, h * y), Offset(w * .85f, h * y), stroke)
            }
            SheetSymbol.More -> for (y in listOf(.2f, .5f, .8f)) drawCircle(color, 1.7.dp.toPx(), Offset(w / 2, h * y))
            SheetSymbol.Add -> {
                drawCircle(color, w * .43f, style = Stroke(stroke))
                drawLine(color, Offset(w * .25f, h * .5f), Offset(w * .75f, h * .5f), stroke)
                drawLine(color, Offset(w * .5f, h * .25f), Offset(w * .5f, h * .75f), stroke)
            }
        }
    }
}

@Composable
internal fun RatingDot(filled: Boolean, bonus: Boolean = false) {
    Canvas(Modifier.size(20.dp)) {
        val radius = size.minDimension / 2 - 0.6.dp.toPx()
        drawCircle(if (!filled) Color.White else if (bonus) SheetColors.ink else SheetColors.accent, radius)
        drawCircle(SheetColors.ink, radius, style = Stroke(1.dp.toPx()))
    }
}

// Preserve the reference's 20 dp marks on a 24 dp pitch. Prevent invisible expanded
// hit regions from overlapping adjacent marks; the trait-name menu remains full-sized.
@Composable
private fun CompactTargets(content: @Composable () -> Unit) {
    val original = LocalViewConfiguration.current
    val compact = remember(original) {
        object : ViewConfiguration by original {
            override val minimumTouchTargetSize = DpSize.Zero
        }
    }
    CompositionLocalProvider(LocalViewConfiguration provides compact, content = content)
}

@Composable
internal fun StaminaControl(c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit) {
    TraitRatingControl("Stamina", c.stamina, c.staminaBonus(catalog),
        legalRatings(RatingKind.Attribute, c.bloodPotency), editable) { edit(SheetEdit.StaminaRating(it)) }
}

/** Shared by attributes and skills, with only legal base ratings in the name menu. */
@Composable
internal fun TraitRatingControl(
    label: String, base: Int, bonus: Int, legal: IntRange, editable: Boolean, onSelect: (Int) -> Unit,
) {
    var expanded by rememberSaveable(label) { mutableStateOf(false) }
    fun select(value: Int): Boolean {
        if (!editable || value !in legal) return false
        onSelect(value)
        return true
    }
    BoxWithConstraints(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp)) {
        val stacked = maxWidth < 230.dp || LocalDensity.current.fontScale > 1.3f
        val dotsPerRow = (maxWidth / 24.dp).toInt().coerceIn(1, 5)
        @Composable fun dots() {
            CompactTargets {
                Column {
                    (1..maxOf(legal.last, base + bonus)).chunked(dotsPerRow).forEach { values ->
                        Row {
                            values.forEach { value ->
                                Box(Modifier.size(24.dp, 48.dp).clickable(enabled = editable && value <= legal.last) {
                                    select(if (legal.first == 0 && base == 1 && value == 1) 0 else value)
                                }, contentAlignment = Alignment.Center) { RatingDot(value <= base + bonus, value > base) }
                            }
                        }
                    }
                }
            }
        }
        @Composable fun name(modifier: Modifier) {
            Box(modifier.heightIn(min = 48.dp).clickable(enabled = editable) { expanded = true },
                contentAlignment = Alignment.CenterStart) {
                Text(label, style = LocalSheetType.current.label)
            }
        }
        Box(Modifier.fillMaxWidth().clearAndSetSemantics {
            contentDescription = label
            stateDescription = "$base base, $bonus bonus"
            if (editable) {
                onClick(label = "Choose $label rating") { expanded = true; true }
                progressBarRangeInfo = ProgressBarRangeInfo(base.toFloat(), legal.first.toFloat()..legal.last.toFloat(),
                    (legal.last - legal.first - 1).coerceAtLeast(0))
                setProgress { select(Math.round(it).coerceIn(legal)) }
                customActions = buildList {
                    if (base < legal.last) add(CustomAccessibilityAction("Raise $label") { select(base + 1) })
                    if (base > legal.first) add(CustomAccessibilityAction("Lower $label") { select(base - 1) })
                }
            }
        }) {
            if (stacked) Column {
                name(Modifier.fillMaxWidth())
                dots()
            } else Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                name(Modifier.weight(1f))
                dots()
            }
        }
        DropdownMenu(expanded = expanded && editable, onDismissRequest = { expanded = false },
            modifier = Modifier.widthIn(min = 144.dp).testTag("rating-menu")) {
            legal.forEach { value ->
                DropdownMenuItem(text = { Text(value.toString()) }, modifier = Modifier.semantics { selected = value == base },
                    trailingIcon = { if (value == base) Text("✓", Modifier.clearAndSetSemantics {}) },
                    onClick = { select(value); expanded = false })
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun HealthTrack(c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit) {
    val total = c.health(catalog).coerceAtLeast(0)
    CompactTargets {
        FlowRow(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)) {
            repeat(total) { index ->
                val damage = c.healthTrack.getOrElse(index) { Damage.none }
                val mark = if (damage == Damage.none) "unmarked" else damage.name
                Column(Modifier.width(24.dp).height(52.dp)
                    .clickable(enabled = editable, role = Role.Button, onClickLabel = "Cycle damage") { edit(SheetEdit.Mark(index)) }
                    .semantics { contentDescription = "Health box ${index + 1} of $total"; stateDescription = mark },
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterVertically)) {
                    RatingDot(true)
                    Canvas(Modifier.size(20.dp)) {
                        val stroke = 1.dp.toPx()
                        drawRect(Color.White)
                        drawRect(SheetColors.ink, style = Stroke(stroke))
                        val p = 4.dp.toPx(); val w = size.width; val h = size.height
                        if (damage != Damage.none) drawLine(SheetColors.ink, Offset(w - p, p), Offset(p, h - p), stroke)
                        if (damage == Damage.lethal || damage == Damage.aggravated)
                            drawLine(SheetColors.ink, Offset(p, p), Offset(w - p, h - p), stroke)
                        if (damage == Damage.aggravated)
                            drawLine(SheetColors.ink, Offset(w / 2, p), Offset(w / 2, h - p), stroke)
                    }
                }
            }
        }
    }
}
