package ie.requiem.sheet

import androidx.compose.runtime.Composable
import ie.chronicles.ui.*

private val requiemIdentity = SheetIdentity(R.font.im_fell_english, R.font.cinzel_medium,
    R.drawable.page_border, R.drawable.requiem_logo, "Vampire: The Requiem, Second Edition")
@Composable internal fun SheetTheme(content: @Composable () -> Unit) = ChroniclesTheme(requiemIdentity, content)
