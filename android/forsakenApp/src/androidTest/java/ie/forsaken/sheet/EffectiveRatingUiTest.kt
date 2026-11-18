package ie.forsaken.sheet

import androidx.compose.runtime.*
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import ie.chronicles.ui.TraitRatingControl
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class EffectiveRatingUiTest {
    @get:Rule val ui=createComposeRule()

    @Test fun effectiveDotsAboveTenStayVisibleAndOnlyBaseDotsAreEditableAtLargeText() {
        var bonus by mutableIntStateOf(2)
        var counted by mutableIntStateOf(11)
        ui.setContent {
            val density=LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(density.density,1.5f)) {
                ForsakenTheme { TraitRatingControl("Strength",10,bonus,1..10,true,countedRating=counted) {} }
            }
        }
        val trait=ui.onNodeWithContentDescription("Strength")
        trait.assert(hasStateDescription("10 base, 2 bonus, 11 counted, 1 past the limit"))
        val faded=trait.captureToImage().toPixelMap()
        ui.runOnIdle { bonus=0 }
        val ten=trait.captureToImage().toPixelMap()
        assertTrue("The twelfth dot needs a visible third row",faded.height>ten.height)
        ui.runOnIdle { bonus=2; counted=12 }
        val full=trait.captureToImage().toPixelMap()
        assertTrue((ten.height until full.height).any { y -> (0 until full.width).any { x ->
            full[x,y].red<.1f && faded[x,y].red>.5f
        } })
        trait.performSemanticsAction(SemanticsActions.OnClick) { it() }
        ui.onNodeWithText("11").assertDoesNotExist()
        ui.onNodeWithText("10").performScrollTo().assertIsDisplayed()
    }
}
