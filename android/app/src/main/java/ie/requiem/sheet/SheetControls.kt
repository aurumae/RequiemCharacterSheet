package ie.requiem.sheet

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import ie.requiem.rules.*

internal enum class SheetSymbol { Back, More, Add, Chevron }
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

@Composable
internal fun StaminaControl(c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit) {
    val base = c.stamina
    val bonus = c.staminaBonus(catalog)
    val cap = c.staminaCap
    fun select(value: Int): Boolean {
        val target = value.coerceIn(1, cap)
        if (!editable) return false
        edit(SheetEdit.StaminaRating(target))
        return true
    }
    BoxWithConstraints(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp)
        .clearAndSetSemantics {
            contentDescription = "Stamina"
            stateDescription = "$base base, $bonus bonus"
            if (editable) {
                progressBarRangeInfo = ProgressBarRangeInfo(base.toFloat(), 1f..cap.toFloat(), cap - 2)
                setProgress { select(Math.round(it)) }
                customActions = buildList {
                    if (base < cap) add(CustomAccessibilityAction("Raise Stamina") { select(base + 1) })
                    if (base > 1) add(CustomAccessibilityAction("Lower Stamina") { select(base - 1) })
                }
            }
        }) {
        val stacked = maxWidth < 350.dp || LocalDensity.current.fontScale > 1.3f
        val dotsPerRow = (maxWidth / 48.dp).toInt().coerceIn(1, 5)
        @Composable fun dots() {
            Column {
                (1..maxOf(cap, base + bonus)).chunked(dotsPerRow).forEach { values ->
                    Row {
                        values.forEach { value ->
                            Box(Modifier.size(48.dp).clickable(enabled = editable && value <= cap) { select(value) },
                                contentAlignment = Alignment.Center) { RatingDot(value <= base + bonus, value > base) }
                        }
                    }
                }
            }
        }
        if (stacked) Column(Modifier.padding(top = 8.dp)) {
            Text("Stamina", style = LocalSheetType.current.label)
            dots()
        } else Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text("Stamina", Modifier.weight(1f), style = LocalSheetType.current.label)
            dots()
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun HealthTrack(c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit) {
    val total = c.health(catalog).coerceAtLeast(0)
    FlowRow(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 8.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)) {
        repeat(total) { index ->
            val damage = c.healthTrack.getOrElse(index) { Damage.none }
            val mark = if (damage == Damage.none) "unmarked" else damage.name
            Column(Modifier.width(48.dp).height(64.dp)
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
