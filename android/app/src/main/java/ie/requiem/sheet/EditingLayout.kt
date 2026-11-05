package ie.requiem.sheet

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp

/** Re-evaluate after IME/layout changes, including multiline growth. */
@Composable
internal fun Modifier.revealWhileEditing(value: String): Modifier {
    val requester = remember { BringIntoViewRequester() }
    var focused by remember { mutableStateOf(false) }
    var size by remember { mutableStateOf(IntSize.Zero) }
    val keyboard = WindowInsets.ime.getBottom(LocalDensity.current)
    LaunchedEffect(focused, value, keyboard, size) {
        if (focused) { withFrameNanos { }; requester.bringIntoView() }
    }
    return bringIntoViewRequester(requester).onFocusChanged { focused = it.isFocused }.onSizeChanged { size = it }
}

/** Fade only the list edges; scroll padding lets every row move clear of the mask. */
internal fun Modifier.pageEdges(): Modifier = graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
    .drawWithContent {
        drawContent()
        if (size.height <= 0f) return@drawWithContent
        val top = 8.dp.toPx().coerceAtMost(size.height / 2)
        val bottom = 20.dp.toPx().coerceAtMost(size.height / 2)
        drawRect(Brush.verticalGradient(0f to Color.Transparent, (top / size.height) to Color.Black,
            (1f - bottom / size.height) to Color.Black, 1f to Color.Transparent), blendMode = BlendMode.DstIn)
    }
