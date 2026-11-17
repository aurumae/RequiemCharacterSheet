package ie.chronicles.ui

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

/** Re-evaluate after IME/layout changes, including multiline growth. */
@Composable
fun Modifier.revealWhileEditing(value: String): Modifier {
    val requester = remember { BringIntoViewRequester() }
    var focused by remember { mutableStateOf(false) }
    var size by remember { mutableStateOf(IntSize.Zero) }
    val keyboard = WindowInsets.ime.getBottom(LocalDensity.current)
    LaunchedEffect(focused, value, keyboard, size) {
        if (focused) { withFrameNanos { }; requester.bringIntoView() }
    }
    return bringIntoViewRequester(requester).onFocusChanged { focused = it.hasFocus }.onSizeChanged { size = it }
}

/** Fade only the list edges; scroll padding lets every row move clear of the mask. */
fun Modifier.pageEdges(): Modifier = graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
    .drawWithContent {
        drawContent()
        if (size.height <= 0f) return@drawWithContent
        val top = 8.dp.toPx().coerceAtMost(size.height / 2)
        val bottom = 20.dp.toPx().coerceAtMost(size.height / 2)
        drawRect(Brush.verticalGradient(0f to Color.Transparent, (top / size.height) to Color.Black,
            (1f - bottom / size.height) to Color.Black, 1f to Color.Transparent), blendMode = BlendMode.DstIn)
    }

/** The full list frame stays fixed behind the keyboard. Draw after the opaque rows,
 * with no hit target or accessibility node. */
@Composable
fun Modifier.sheetWatermark(): Modifier {
    val resource = LocalSheetIdentity.current.watermark ?: return this
    val image = ImageBitmap.imageResource(resource)
    val ink = ColorFilter.tint(SheetColors.accent)
    var fullSize by remember { mutableStateOf(IntSize.Zero) }
    // Like the Swift sheet, a width change starts a new frame; losing height only clips it.
    return onSizeChanged { size ->
        if (size.width != fullSize.width || size.height > fullSize.height) fullSize = size
    }.drawWithCache {
        val height = fullSize.height.coerceAtLeast(size.height.roundToInt())
        val width = minOf(330.dp.toPx(), (size.width - 80.dp.toPx()).coerceAtLeast(0f))
        val scale = minOf(width / image.width, height.toFloat() / image.height)
        val drawn = IntSize((image.width * scale).roundToInt(), (image.height * scale).roundToInt())
        val origin = IntOffset(((size.width - drawn.width) / 2).roundToInt(), (height - drawn.height) / 2)
        onDrawWithContent {
            drawContent()
            if (drawn.width > 0 && drawn.height > 0) drawImage(image, dstOffset = origin,
                dstSize = drawn, alpha = .07f, colorFilter = ink, blendMode = BlendMode.Multiply)
        }
    }
}
