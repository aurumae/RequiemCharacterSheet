package ie.chronicles.ui

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

// Shared sheet styling. The app injects its fonts, artwork and accessible identity.
internal object SheetColors {
    val accent = Color(0xFF581A12)
    val ink = Color.Black
    val muted = Color(0xFF6C6C70)
    val band = Color(0xFFF2F2F7)
    val rule = Color(0xFFE7E7EA)
    val caution = Color(0xFF8C6408)
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
internal fun ChroniclesTheme(identity: SheetIdentity, content: @Composable () -> Unit) {
    val resources = LocalResources.current
    val type = remember(resources, identity) {
        SheetType(FontFamily(Font(identity.displayFont)),
            FontFamily(Font(identity.numeralFont, androidx.compose.ui.text.font.FontWeight.Medium)))
    }
    CompositionLocalProvider(LocalSheetType provides type, LocalSheetIdentity provides identity) {
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
        Image(painterResource(LocalSheetIdentity.current.background), null, Modifier.matchParentSize(), contentScale = ContentScale.Crop)
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
        Image(painterResource(LocalSheetIdentity.current.logo), LocalSheetIdentity.current.logoDescription,
            Modifier.width(if (compact) 110.dp else 184.dp).height(if (compact) 64.dp else 108.dp))
    }
}

@Composable
internal fun SectionBand(title: String) {
    SheetText(title, Modifier.fillMaxWidth().background(SheetColors.band).padding(horizontal = 8.dp, vertical = 8.dp)
        .semantics { heading() }, style = LocalSheetType.current.section)
}

@Composable
internal fun SubsectionLabel(title: String) {
    SheetText(title, Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp).semantics { heading() },
        style = LocalSheetType.current.subsection)
}

@Composable
internal fun SheetRule() {
    HorizontalDivider(Modifier.padding(horizontal = 8.dp), color = SheetColors.rule)
}

internal data class SheetIdentity(val displayFont: Int, val numeralFont: Int, val background: Int, val logo: Int, val logoDescription: String)
internal val LocalSheetIdentity = staticCompositionLocalOf<SheetIdentity> { error("The app must supply its sheet identity") }
