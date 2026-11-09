package ie.requiem.sheet

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
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
internal fun RatingDot(filled: Boolean, bonus: Boolean = false, diameter: androidx.compose.ui.unit.Dp = 20.dp) {
    Canvas(Modifier.size(diameter)) {
        val radius = size.minDimension / 2 - 0.6.dp.toPx()
        drawCircle(if (!filled) Color.White else if (bonus) SheetColors.ink else SheetColors.accent, radius)
        drawCircle(SheetColors.ink, radius, style = Stroke(1.dp.toPx()))
    }
}

// Preserve the reference's 20 dp marks on a 24 dp pitch. Prevent invisible expanded
// hit regions from overlapping adjacent marks; the trait-name menu remains full-sized.
@Composable
internal fun CompactTargets(content: @Composable () -> Unit) {
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
    label: String, base: Int, bonus: Int, legal: IntRange, editable: Boolean,
    allowedValues: List<Int> = legal.toList(), reserveFiveDots: Boolean = false,
    onNameClick: (() -> Unit)? = null, visibleCap: Int = legal.last, note: String? = null, onConditions: (() -> Unit)? = null, onSelect: (Int) -> Unit,
) {
    var expanded by rememberSaveable(label) { mutableStateOf(false) }
    fun select(value: Int): Boolean {
        if (!editable || value !in legal || value < allowedValues.first()) return false
        val next = allowedValues.firstOrNull { it >= value } ?: return false
        onSelect(next)
        return true
    }
    BoxWithConstraints(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp)) {
        val stacked = maxWidth < 230.dp || LocalDensity.current.fontScale > 1.3f
        val dotsPerRow = (maxWidth / 24.dp).toInt().coerceIn(1, 5)
        @Composable fun dots() {
            CompactTargets {
                Column(if (reserveFiveDots) Modifier.width(minOf(maxWidth, 120.dp)) else Modifier) {
                    (1..maxOf(visibleCap, base + bonus).coerceAtMost(10)).chunked(dotsPerRow).forEach { values ->
                        Row {
                            values.forEach { value ->
                                Box(Modifier.size(24.dp, 24.dp).clickable(enabled = editable && value in allowedValues.first()..allowedValues.last()) {
                                    select(if (legal.first == 0 && base == 1 && value == 1) 0 else value)
                                }.alpha(if (value > allowedValues.last() && value > base + bonus) .35f else 1f), contentAlignment = Alignment.Center) { RatingDot(value <= base + bonus, value > base) }
                            }
                        }
                    }
                }
            }
        }
        @Composable fun name(modifier: Modifier) {
            Row(modifier, verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f).heightIn(min = 48.dp).clickable(enabled = editable || onNameClick != null) { if (onNameClick != null) onNameClick() else expanded = true },
                    contentAlignment = Alignment.CenterStart) {
                    Column(Modifier.padding(top = 8.dp, bottom = 8.dp, end = 4.dp)) {
                        SheetText(label, style = if (onNameClick != null) LocalSheetType.current.trait else LocalSheetType.current.label)
                        if (note != null) SheetText(note, style = MaterialTheme.typography.bodySmall, color = SheetColors.muted)
                    }
                }
                if (onConditions != null) ConditionIndicator(label, onConditions)
            }
        }
        Box(Modifier.fillMaxWidth().clearAndSetSemantics {
            contentDescription = label
            stateDescription = "$base base, $bonus bonus" + (if (onConditions != null) ", affected by Conditions" else "") + (note?.let { ", $it" } ?: "")
            if (editable || onNameClick != null) onClick(label = if (onNameClick != null) "Open $label" else "Choose $label rating") {
                if (onNameClick != null) onNameClick() else expanded = true; true
            }
            if (editable) {
                progressBarRangeInfo = ProgressBarRangeInfo(base.toFloat(), allowedValues.first().toFloat()..allowedValues.last().toFloat(),
                    (allowedValues.last() - allowedValues.first() - 1).coerceAtLeast(0))
                setProgress { select(Math.round(it).coerceIn(legal)) }
                customActions = buildList {
                    if (onConditions != null) add(CustomAccessibilityAction("Conditions affecting $label") { onConditions(); true })
                    add(CustomAccessibilityAction("Choose $label rating") { expanded = true; true })
                    allowedValues.firstOrNull { it > base }?.let { value -> add(CustomAccessibilityAction("Raise $label") { select(value) }) }
                    allowedValues.lastOrNull { it < base }?.let { value -> add(CustomAccessibilityAction("Lower $label") { select(value) }) }
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
            allowedValues.forEach { value ->
                DropdownMenuItem(text = { SheetText(value.toString()) }, modifier = Modifier.semantics { selected = value == base },
                    trailingIcon = { if (value == base) SheetText("✓", Modifier.clearAndSetSemantics {}) },
                    onClick = { select(value); expanded = false })
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun HealthTrack(c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit) {
    val total = c.health(catalog).coerceAtLeast(0)
    val scale = LocalDensity.current.fontScale.coerceAtLeast(1f)
    CompactTargets {
        FlowRow(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)) {
            repeat(total) { index ->
                val damage = c.healthTrack.getOrElse(index) { Damage.none }
                val mark = if (damage == Damage.none) "unmarked" else damage.name
                Column(Modifier.width(24.dp * scale).height(52.dp * scale)
                    .clickable(enabled = editable, role = Role.Button, onClickLabel = "Cycle damage") { edit(SheetEdit.Mark(index)) }
                    .semantics { contentDescription = "Health box ${index + 1} of $total"; stateDescription = mark },
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterVertically)) {
                    RatingDot(true, diameter = 20.dp * scale)
                    Canvas(Modifier.size(20.dp * scale)) {
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
