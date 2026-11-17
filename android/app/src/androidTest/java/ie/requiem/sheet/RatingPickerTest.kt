package ie.requiem.sheet

import ie.chronicles.ui.*

import androidx.compose.runtime.*
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import ie.requiem.rules.*
import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class RatingPickerTest {
    @get:Rule val ui = createComposeRule()

    @Test fun attributeNameOffersOnlyLegalValuesIncludingHighBloodPotency() {
        var potency by mutableIntStateOf(5)
        var value by mutableIntStateOf(1)
        ui.setContent { SheetTheme {
            TraitRatingControl("Stamina", value, 2, legalRatings(RatingKind.Attribute, potency), true) { value = it }
        } }
        for (cap in listOf(5, 6, 10)) {
            ui.runOnIdle { potency = cap }
            ui.onNodeWithContentDescription("Stamina").performClick()
            ui.onNodeWithTag("rating-menu").assertExists()
            ui.onNodeWithText("0").assertDoesNotExist()
            ui.onNodeWithText((cap + 1).toString()).assertDoesNotExist()
            for (rating in 1..cap) ui.onNodeWithText(rating.toString()).assertExists()
            ui.onNodeWithText(cap.toString()).performScrollTo().performClick()
            ui.runOnIdle { assertEquals(cap, value) }
            ui.onNodeWithTag("rating-menu").assertDoesNotExist()
        }
    }

    @Test fun skillNameOffersZeroButNotValuesBeyondTheCap() {
        var value by mutableIntStateOf(3)
        ui.setContent { SheetTheme {
            TraitRatingControl("Athletics", value, 0, legalRatings(RatingKind.Skill, 1), true) { value = it }
        } }
        ui.onNodeWithContentDescription("Athletics").performClick()
        for (rating in 0..5) ui.onNodeWithText(rating.toString()).assertExists()
        ui.onNodeWithText("6").assertDoesNotExist()
        ui.onNodeWithText("0").performClick()
        ui.runOnIdle { assertEquals(0, value) }
    }

    @Test fun dotsPastTheCountedLimitRemainVisibleAndKeepTheirBaseEditRange() {
        var base by mutableIntStateOf(4)
        var limit by mutableIntStateOf(5)
        ui.setContent { SheetTheme {
            TraitRatingControl("Strength", base, 3, 1..5, true, countedRating = limit) { base = it }
        } }
        val trait = ui.onNodeWithContentDescription("Strength")
        trait.assert(hasStateDescription("4 base, 3 bonus, 5 counted, 2 past the limit"))
        val faded = trait.captureToImage().toPixelMap()
        ui.runOnIdle { limit = 7 }
        trait.assert(hasStateDescription("4 base, 3 bonus"))
        val full = trait.captureToImage().toPixelMap()
        // The two over-limit filled dots are lighter than the same dots at full ink.
        assertTrue((0 until full.height).any { y ->
            (0 until full.width).any { x -> full[x, y].red < 0.1f && faded[x, y].red > 0.5f }
        })
        trait.performClick()
        ui.onNodeWithText("6").assertDoesNotExist()
        ui.onNodeWithText("5").performClick()
        ui.runOnIdle { assertEquals(5, base) }
    }

    @Test fun readOnlyTraitsDoNotOpenAnEditingMenu() {
        ui.setContent { SheetTheme {
            TraitRatingControl("Stamina", 2, 0, 1..5, false) { error("Read-only trait edited") }
        } }
        ui.onNodeWithContentDescription("Stamina").assertHasNoClickAction()
        ui.onNodeWithTag("rating-menu").assertDoesNotExist()
    }
}
