package ie.chronicles.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// Shared sheet styling. The app injects its fonts, artwork and accessible identity.
object SheetColors {
    val accent: Color @Composable get() = MaterialTheme.colorScheme.primary
    val ink = Color.Black
    val muted = Color(0xFF6C6C70)
    val band = Color(0xFFF2F2F7)
    val rule = Color(0xFFE7E7EA)
    val caution = Color(0xFF8C6408)
}
data class SheetType(val display: FontFamily, val smallCaps: FontFamily, private val accent: Color,
    private val labels: FontFamily = display, private val options: SheetTypography = SheetTypography()) {
    val label get() = TextStyle(fontFamily = labels, fontSize = options.labelSize.sp, lineHeight = (options.labelSize + 6).sp, color = accent)
    val trait get() = TextStyle(fontFamily = display, fontSize = options.traitSize.sp, lineHeight = (options.traitSize + 6).sp,
        color = if (options.traitNamesInAccent) accent else SheetColors.ink)
    val section get() = TextStyle(fontFamily = display, fontSize = 24.sp, lineHeight = 30.sp, color = SheetColors.muted)
    val subsection get() = TextStyle(fontFamily = smallCaps, fontSize = options.subheadingSize.sp, lineHeight = (options.subheadingSize + 5).sp,
        letterSpacing = options.subheadingSpacing.sp, color = accent)
    val control get() = TextStyle(fontFamily = if (options.controlUsesDisplay) display else smallCaps,
        fontSize = options.controlSize.sp, lineHeight = (options.controlSize + 4).sp, letterSpacing = 0.sp)
    val libraryAbout get() = if (options.libraryAboutUsesLabel) label else TextStyle.Default
}
data class SheetTypography(
    val labelFont: Int? = null, val labelSize: Int = 22, val traitSize: Int = 20, val subheadingSize: Int = 20,
    val subheadingSpacing: Float = 1.5f, val traitNamesInAccent: Boolean = true,
    val controlUsesDisplay: Boolean = false, val controlSize: Int = 14,
    val libraryAboutUsesLabel: Boolean = false,
)
val LocalSheetType = staticCompositionLocalOf<SheetType> { error("The app must supply sheet typography") }

@Composable
fun ChroniclesTheme(identity: SheetIdentity, content: @Composable () -> Unit) {
    val resources = LocalResources.current
    val type = remember(resources, identity) {
        SheetType(FontFamily(Font(identity.displayFont)),
            FontFamily(Font(identity.numeralFont, androidx.compose.ui.text.font.FontWeight.Medium)), identity.accent,
            FontFamily(Font(identity.typography.labelFont ?: identity.displayFont)), identity.typography)
    }
    CompositionLocalProvider(LocalSheetType provides type, LocalSheetIdentity provides identity) {
        MaterialTheme(colorScheme = lightColorScheme(
            primary = identity.accent, onPrimary = Color.White, primaryContainer = identity.accentContainer,
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
fun PageBackground(content: @Composable BoxScope.() -> Unit) {
    val window = LocalWindowInfo.current.containerSize
    Box(Modifier.fillMaxSize().background(Color.White)) {
        LocalSheetIdentity.current.background?.let {
            Image(painterResource(it), null, Modifier.matchParentSize(), contentScale = ContentScale.Crop)
        }
        if (window.width > window.height) {
            Box(Modifier.fillMaxWidth().windowInsetsTopHeight(WindowInsets.statusBars).background(Color.White.copy(alpha = .85f)))
        }
        content()
    }
}

@Composable
fun LogoHeader() {
    val density = LocalDensity.current
    val window = LocalWindowInfo.current.containerSize
    val compact = with(density) { window.height.toDp() < 500.dp }
    Box(Modifier.fillMaxWidth().height(if (compact) 72.dp else 140.dp), contentAlignment = androidx.compose.ui.Alignment.Center) {
        Image(painterResource(LocalSheetIdentity.current.logo), LocalSheetIdentity.current.logoDescription,
            Modifier.width(if (compact) 110.dp else 184.dp).height(if (compact) 64.dp else 108.dp))
    }
}

@Composable
fun SectionBand(title: String) {
    SheetText(title, Modifier.fillMaxWidth().background(SheetColors.band).padding(horizontal = 8.dp, vertical = 8.dp)
        .semantics { heading() }, style = LocalSheetType.current.section)
}

@Composable
fun SubsectionLabel(title: String) {
    SheetText(title, Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp).semantics { heading() },
        style = LocalSheetType.current.subsection)
}

@Composable
fun SheetRule() {
    HorizontalDivider(Modifier.padding(horizontal = 8.dp), color = SheetColors.rule)
}

data class SheetIdentity(
    val accent: Color,
    val accentContainer: Color,
    val displayFont: Int,
    val numeralFont: Int,
    val logo: Int,
    val logoDescription: String,
    val background: Int? = null,
    val watermark: Int? = null,
    val typography: SheetTypography = SheetTypography(),
)

internal val LocalSheetIdentity = staticCompositionLocalOf<SheetIdentity> { error("The app must supply its sheet identity") }
