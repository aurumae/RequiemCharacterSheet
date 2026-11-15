package ie.chronicles.ui

import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import ie.chronicles.core.spokenForScreenReader

/** Keep the visible notation while speaking dot counts and ranges naturally. */
@Composable
internal fun SheetText(text: String, modifier: Modifier = Modifier, color: Color = Color.Unspecified,
    style: TextStyle = LocalTextStyle.current, textAlign: TextAlign? = null, textDecoration: TextDecoration? = null, maxLines: Int = Int.MAX_VALUE, overflow: TextOverflow = TextOverflow.Clip) {
    val type = LocalSheetType.current
    val display = style.fontFamily == type.display
    val formatted = remember(text, display, type.smallCaps) {
        buildAnnotatedString {
            append(text)
            if (display) text.forEachIndexed { index, c ->
                if (c in '0'..'9') addStyle(SpanStyle(fontFamily = type.smallCaps, fontWeight = FontWeight.Medium), index, index + 1)
            }
        }
    }
    val spoken = remember(text) { text.spokenForScreenReader() }
    Text(formatted, if (spoken == text) modifier else modifier.semantics { contentDescription = spoken },
        color = color, style = style, textAlign = textAlign, textDecoration = textDecoration, maxLines = maxLines, overflow = overflow)
}
