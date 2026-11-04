package ie.requiem.sheet

import android.graphics.Typeface
import android.graphics.fonts.Font as AndroidFont
import android.graphics.fonts.FontFamily as AndroidFontFamily
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.dp

// Match the shipped iOS Theme.requiem, including its accented-character fallback.
internal object SheetColors {
    val accent = Color(0xFF581A12)
    val ink = Color.Black
    val muted = Color(0xFF6D6D73)
    val band = Color(0xFFF2F2F7)
    val rule = Color(0xFFE7E7EA)
    val caution = Color(0xFF805D08)
}
internal data class SheetType(val display: FontFamily, val smallCaps: FontFamily) {
    val label get() = TextStyle(fontFamily = display, fontSize = 22.sp, lineHeight = 28.sp, color = SheetColors.accent)
    val trait get() = label.copy(fontSize = 20.sp, lineHeight = 26.sp)
    val section get() = label.copy(fontSize = 24.sp, lineHeight = 30.sp, color = SheetColors.muted)
    val subsection get() = TextStyle(fontFamily = smallCaps, fontSize = 20.sp, lineHeight = 25.sp,
        letterSpacing = 1.5.sp, color = SheetColors.accent)
}
internal val LocalSheetType = staticCompositionLocalOf { SheetType(FontFamily.Serif, FontFamily.Serif) }

@Composable
internal fun SheetTheme(content: @Composable () -> Unit) {
    val resources = LocalResources.current
    val type = remember(resources) {
        fun family(resource: Int) = AndroidFontFamily.Builder(AndroidFont.Builder(resources, resource).build()).build()
        val display = Typeface.CustomFallbackBuilder(family(R.font.caslon_antique))
            .addCustomFallback(family(R.font.mrs_eaves_roman)).setSystemFallback("serif").build()
        SheetType(FontFamily(display), FontFamily(Font(R.font.mrs_eaves_small_caps)))
    }
    CompositionLocalProvider(LocalSheetType provides type) {
        MaterialTheme(colorScheme = lightColorScheme(
            primary = SheetColors.accent, onPrimary = Color.White, primaryContainer = Color(0xFFF1DDDA),
            surface = Color.White, onSurface = SheetColors.ink, background = Color.White,
            onBackground = SheetColors.ink, surfaceContainer = SheetColors.band,
            onSurfaceVariant = SheetColors.muted, outline = SheetColors.muted, outlineVariant = SheetColors.rule
        ), typography = Typography(
            bodyMedium = Typography().bodyMedium.copy(fontSize = 16.sp, lineHeight = 22.sp),
            bodySmall = Typography().bodySmall.copy(fontSize = 14.sp, lineHeight = 20.sp),
            labelSmall = Typography().labelSmall.copy(fontSize = 12.sp, lineHeight = 16.sp)
        ), content = content)
    }
}

@Composable
internal fun PageBackground(content: @Composable BoxScope.() -> Unit) {
    val window = LocalWindowInfo.current.containerSize
    Box(Modifier.fillMaxSize().background(Color.White)) {
        Image(painterResource(R.drawable.page_border), null, Modifier.matchParentSize(), contentScale = ContentScale.Crop)
        if (window.width > window.height) {
            Box(Modifier.fillMaxWidth().windowInsetsTopHeight(WindowInsets.statusBars).background(Color.White.copy(alpha = .85f)))
        }
        content()
    }
}

@Composable
internal fun LogoHeader() {
    val density = LocalDensity.current
    val window = LocalWindowInfo.current.containerSize
    val compact = with(density) { window.height.toDp() < 500.dp } || WindowInsets.ime.getBottom(density) > 0
    Box(Modifier.fillMaxWidth().height(if (compact) 72.dp else 140.dp), contentAlignment = androidx.compose.ui.Alignment.Center) {
        Image(painterResource(R.drawable.requiem_logo), "Vampire: The Requiem, Second Edition",
            Modifier.width(if (compact) 110.dp else 184.dp).height(if (compact) 64.dp else 108.dp))
    }
}

@Composable
internal fun SectionBand(title: String) {
    Text(title, Modifier.fillMaxWidth().background(SheetColors.band).padding(horizontal = 8.dp, vertical = 8.dp)
        .semantics { heading() }, style = LocalSheetType.current.section)
}

@Composable
internal fun SubsectionLabel(title: String) {
    Text(title, Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp).semantics { heading() },
        style = LocalSheetType.current.subsection)
}

@Composable
internal fun SheetRule() {
    HorizontalDivider(Modifier.padding(horizontal = 8.dp), color = SheetColors.rule)
}
