package ie.forsaken.sheet

import android.annotation.SuppressLint
import android.content.res.Resources
import android.util.Xml
import org.xmlpull.v1.XmlPullParser
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import ie.chronicles.ui.*
import kotlinx.serialization.json.*
import kotlin.math.*

internal data class HeadingArt(val vector: ImageVector?, val width: Float, val height: Float)

// The licensed generator owns both the names and dimensions. No font or hand-edited outlines are used.
@SuppressLint("DiscouragedApi")
internal fun readHeadingArt(resources: Resources): Map<String, HeadingArt> = resources.openRawResource(R.raw.headings).bufferedReader().use { reader ->
    Json.parseToJsonElement(reader.readText()).jsonObject.getValue("headings").jsonArray.associate { element ->
        val values = element.jsonObject
        val name = values.getValue("drawable").jsonPrimitive.content
        values.getValue("heading").jsonPrimitive.content to HeadingArt(readVector(resources, resources.getIdentifier(name, "raw", resources.getResourcePackageName(R.raw.headings))),
            values.getValue("width").jsonPrimitive.float, values.getValue("height").jsonPrimitive.float)
    }
}

/** AAPT truncates pathData above 32,767 bytes. Load the original vector XML as raw data, without splitting contours. */
internal fun readVector(resources: Resources, resource: Int): ImageVector? {
    if (resource == 0) return null
    return resources.openRawResource(resource).use { stream ->
        val parser = Xml.newPullParser().apply { setInput(stream, "UTF-8") }
        val namespace = "http://schemas.android.com/apk/res/android"
        var builder: ImageVector.Builder? = null
        while (parser.next() != XmlPullParser.END_DOCUMENT) {
            if (parser.eventType != XmlPullParser.START_TAG) continue
            fun value(name: String) = parser.getAttributeValue(namespace, name)
            when (parser.name) {
                "vector" -> builder = ImageVector.Builder(defaultWidth = value("width").removeSuffix("dp").toFloat().dp,
                    defaultHeight = value("height").removeSuffix("dp").toFloat().dp,
                    viewportWidth = value("viewportWidth").toFloat(), viewportHeight = value("viewportHeight").toFloat())
                "path" -> requireNotNull(builder).addPath(PathParser().parsePathString(value("pathData")).toNodes(),
                    fill = SolidColor(Color(android.graphics.Color.parseColor(value("fillColor")))),
                    pathFillType = if (value("fillType") == "evenOdd") PathFillType.EvenOdd else PathFillType.NonZero)
                else -> error("Unsupported heading element ${parser.name}")
            }
        }
        requireNotNull(builder).build()
    }
}

@Composable internal fun rememberHeadingArt(): Map<String, HeadingArt> {
    val resources = LocalResources.current
    return remember(resources) { readHeadingArt(resources) }
}

@Composable
internal fun ForsakenHeading(title: String, art: HeadingArt?) {
    val scale = LocalDensity.current.fontScale
    val ink = SheetColors.accent
    BoxWithConstraints(Modifier.fillMaxWidth().padding(vertical = 14.dp).clearAndSetSemantics { contentDescription = title; heading() }) {
        val availableWidth = maxWidth
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            BrushLine(title + "-leading", true, Modifier.weight(1f).height(12.dp))
            if (art != null && art.vector != null) Image(rememberVectorPainter(art.vector), null,
                Modifier.width(minOf(art.width.dp * scale, (availableWidth - 64.dp).coerceAtLeast(1.dp))).height(art.height.dp * scale),
                colorFilter = ColorFilter.tint(ink))
            else SheetText(title, Modifier.weight(5f), style = LocalSheetType.current.section, color = ink)
            BrushLine(title + "-trailing", false, Modifier.weight(1f).height(12.dp))
        }
    }
}

/** Chronicles/UI/BrushLine.swift's FNV-1a seed and SplitMix64 stroke in logical points. */
@Composable
internal fun BrushLine(seed: String, solidTrailing: Boolean, modifier: Modifier) {
    val ink = SheetColors.accent
    Canvas(modifier) {
        val random = StrokeRandom(seed)
        val length = size.width / density
        val middle = size.height / density / 2
        fun place(x: Double, y: Double) = Offset(((if (solidTrailing) length - x else x) * density).toFloat(), (y * density).toFloat())
        var distance = 0.0
        while (distance < length) {
            val progress = distance / length
            val segment = mix(80.0, 5.0, progress.pow(.7)) * random.next(.45, 1.5)
            val thickness = mix(4.6, 1.8, progress) * random.next(.75, 1.2)
            val end = min(distance + segment, length.toDouble())
            val drift = random.next(-.9, .9)
            val top = mutableListOf<Offset>(); val bottom = mutableListOf<Offset>()
            val steps = max(2, ((end - distance) / 2.5).toInt())
            for (step in 0..steps) {
                val t = step.toDouble() / steps
                val x = distance + t * (end - distance)
                val taper = sin(PI * t.coerceIn(.04, .96)).pow(.35)
                val y = middle + drift + sin(x / 41) * .9
                top.add(place(x, y - thickness / 2 * taper * random.next(.55, 1.3)))
                bottom.add(place(x, y + thickness / 2 * taper * random.next(.55, 1.3)))
            }
            val path = Path().apply {
                moveTo(top.first().x, top.first().y)
                (top.drop(1) + bottom.reversed()).forEach { lineTo(it.x, it.y) }; close()
            }
            drawPath(path, ink)
            if (progress > .35 && random.next(0.0, 1.0) < .35) {
                val radius = random.next(.6, 1.4)
                drawCircle(ink, (radius * density).toFloat(), place(end + random.next(1.0, 4.0), middle + random.next(-3.5, 3.5)))
            }
            distance = end + mix(.6, 9.0, progress) * random.next(.3, 1.7)
        }
    }
}
private fun mix(a: Double, b: Double, t: Double) = a + (b - a) * t
private class StrokeRandom(seed: String) {
    private var state = seed.toByteArray(Charsets.UTF_8).fold(0xcbf29ce484222325uL) { hash, byte -> (hash xor byte.toUByte().toULong()) * 0x100000001b3uL }
    fun next(low: Double, high: Double): Double {
        state += 0x9E3779B97F4A7C15uL
        var z = state
        z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9uL
        z = (z xor (z shr 27)) * 0x94D049BB133111EBuL
        return low + (high - low) * (z xor (z shr 31)).toDouble() / ULong.MAX_VALUE.toDouble()
    }
}
