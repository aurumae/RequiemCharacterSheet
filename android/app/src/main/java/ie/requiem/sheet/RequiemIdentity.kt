package ie.requiem.sheet

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import ie.chronicles.ui.*

private val requiemIdentity = SheetIdentity(
    accent = Color(0xFF581A12),
    accentContainer = Color(0xFFF1DDDA),
    displayFont = R.font.im_fell_english,
    numeralFont = R.font.cinzel_medium,
    logo = R.drawable.requiem_logo,
    logoDescription = "Vampire: The Requiem, Second Edition",
    watermark = R.drawable.sheet_watermark,
    background = R.drawable.page_border,
)
@Composable internal fun SheetTheme(content: @Composable () -> Unit) = ChroniclesTheme(requiemIdentity, content)
