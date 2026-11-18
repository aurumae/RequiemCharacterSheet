package ie.chronicles.ui

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.*
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*
import androidx.compose.ui.window.*
import ie.chronicles.core.experiencesText
import kotlin.math.roundToInt

@Composable
fun <S> SheetToolbar(sections: List<S>, current: S, title: (S) -> String, select: (S) -> Unit,
    busy: Boolean, saved: Boolean, back: () -> Unit, save: () -> Unit, saveLabel: String = "Save", xp: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = back, enabled = !busy, modifier = Modifier.semantics { contentDescription = "Back" }) {
            SheetIcon(SheetSymbol.Back, SheetColors.ink)
        }
        // Measure XP and Save at their natural widths, then give the pill the space left.
        Box(Modifier.weight(1f)) { SectionMenu(sections, current, title, select) }
        xp()
        TextButton(onClick = save, enabled = !busy && !saved) { SheetText(if (saved) "Saved" else saveLabel, maxLines = 1) }
    }
}

private object BelowPill : PopupPositionProvider {
    override fun calculatePosition(anchorBounds: IntRect, windowSize: IntSize, layoutDirection: LayoutDirection,
        popupContentSize: IntSize): IntOffset {
        val x = if (layoutDirection == LayoutDirection.Ltr) anchorBounds.left else anchorBounds.right - popupContentSize.width
        return IntOffset(x.coerceIn(0, (windowSize.width - popupContentSize.width).coerceAtLeast(0)), anchorBounds.bottom)
    }
}

@Composable
private fun <S> SectionMenu(sections: List<S>, current: S, title: (S) -> String, select: (S) -> Unit) {
    var open by remember { mutableStateOf(false) }
    var anchorBottom by remember { mutableIntStateOf(0) }
    val density = LocalDensity.current
    val window = LocalWindowInfo.current.containerSize
    val bottom = WindowInsets.safeDrawing.getBottom(density)
    Box(Modifier.widthIn(max = 170.dp).onGloballyPositioned { anchorBottom = it.boundsInWindow().bottom.roundToInt() }) {
        Row(Modifier.heightIn(min = 48.dp).clip(CircleShape).clickable(role = Role.Button) { open = !open }
            .testTag("section-pill").semantics { contentDescription = "Sections"; stateDescription = title(current) },
            verticalAlignment = Alignment.CenterVertically) {
            Row(Modifier.background(SheetColors.accent, CircleShape).padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically) {
                val style = LocalSheetType.current.control
                BasicText(title(current), Modifier.weight(1f, fill = false), style = style.copy(color = Color.White),
                    autoSize = TextAutoSize.StepBased(style.fontSize * .8f, style.fontSize, .5.sp), maxLines = 1, overflow = TextOverflow.Ellipsis)
                SheetText(if (open) "⌃" else "⌄", Modifier.padding(start = 4.dp), color = Color.White, style = style)
            }
        }
        if (open) Popup(BelowPill, onDismissRequest = { open = false }, properties = PopupProperties(focusable = true)) {
            val available = with(density) { (window.height - anchorBottom - bottom).toDp() - 12.dp }
            val scroll = rememberScrollState()
            var middle by remember { mutableIntStateOf(-1) }
            var viewport by remember { mutableIntStateOf(0) }
            LaunchedEffect(middle, viewport, scroll.maxValue) {
                if (middle >= 0 && viewport > 0) scroll.scrollTo((middle - viewport / 2).coerceAtLeast(0))
            }
            Surface(modifier = Modifier.padding(top = 4.dp).width(230.dp).heightIn(max = available.coerceAtLeast(0.dp)),
                shape = RoundedCornerShape(14.dp), color = Color.White, border = BorderStroke(1.dp, SheetColors.accent.copy(alpha = .5f)),
                shadowElevation = 8.dp) {
                Column(Modifier.onSizeChanged { viewport = it.height }
                    .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }.drawWithContent {
                        drawContent()
                        if (scroll.canScrollForward) drawRect(Brush.verticalGradient(
                            .88f to Color.Black, 1f to Color.Black.copy(alpha = .1f)), blendMode = BlendMode.DstIn)
                    }.verticalScroll(scroll)) {
                    sections.forEach { section ->
                        val active = current == section
                        Row(Modifier.fillMaxWidth().onGloballyPositioned {
                            if (active) middle = it.positionInParent().y.roundToInt() + it.size.height / 2
                        }.background(if (active) SheetColors.accent else Color.White)
                            .clickable(role = Role.Button) { open = false; select(section) }.semantics { selected = active }
                            .heightIn(min = 48.dp).padding(horizontal = 14.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically) {
                            val ink = if (active) Color.White else SheetColors.accent
                            SheetText(title(section), Modifier.weight(1f), color = ink)
                            if (active) SheetText("✓", color = ink)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun XpBadge(enabled: Boolean, available: Int, interactive: Boolean, toggle: () -> Unit) {
    val ink = if (available < 0) SheetColors.caution else SheetColors.accent
    Box(Modifier.heightIn(min = 48.dp).widthIn(min = 64.dp).clip(CircleShape)
        .clickable(enabled = interactive, role = Role.Switch, onClick = toggle)
        .clearAndSetSemantics {
            contentDescription = "XP Mode"
            stateDescription = if (enabled) "On, ${experiencesText(available)} available" else "Off"
            role = Role.Switch
            if (interactive) onClick(label = "Toggle XP Mode") { toggle(); true }
        }, contentAlignment = Alignment.Center) {
        SheetText(if (enabled) "XP $available" else "XP Off",
            Modifier.border(1.dp, ink, CircleShape)
                .background(if (enabled) ink else Color.White, CircleShape).padding(horizontal = 8.dp, vertical = 3.dp),
            color = if (enabled) Color.White else ink,
            style = MaterialTheme.typography.labelSmall, maxLines = 1)
    }
}
