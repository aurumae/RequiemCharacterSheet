package ie.requiem.sheet

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import ie.chronicles.ui.*
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class SharedFoundationUiTest {
    @get:Rule val ui = createComposeRule()

    @Test fun lateSectionIsVisibleOnOpenAtLargeTextAndXpKeepsItsSpokenAmount() {
        val sections = (1..25).map { "Example section $it" }
        ui.setContent {
            val density = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(density.density, 1.8f)) {
                SheetTheme {
                    Box(Modifier.width(320.dp)) {
                        SheetToolbar(sections, sections.last(), { it }, {}, false, false, {}, {}) {
                            XpBadge(true, 1, true) {}
                        }
                    }
                }
            }
        }
        ui.onNodeWithContentDescription("XP Mode").assertIsDisplayed().assert(hasStateDescription("On, 1 Experience available"))
        ui.onNodeWithText("Save").assertIsDisplayed()
        ui.onNodeWithTag("section-pill").performClick()
        ui.onNode(hasText(sections.last()) and hasAnyAncestor(isPopup())).assertIsDisplayed().assertIsSelected()
        ui.onNode(hasText(sections.first()) and hasAnyAncestor(isPopup())).performScrollTo().assertIsDisplayed()
    }

    @Test fun twoNameFieldsKeepTheirOwnDraftAndFocusWhileEditing() {
        var person by mutableStateOf("First")
        var totem by mutableStateOf("Second")
        ui.setContent {
            SheetTheme {
                SheetList(listOf("Character", "Character", "Totem"), null, {}, {}) {
                    item("character/name") { SheetFieldRow("character/name", "Name", "Character name", person, true) { person = it } }
                    item("middle") { Spacer(Modifier.height(900.dp)) }
                    item("totem/name") { SheetFieldRow("totem/name", "Name", "Totem name", totem, true) { totem = it } }
                }
            }
        }
        val sheet = ui.onNodeWithTag("character-sheet")
        sheet.performScrollToNode(hasContentDescription("Totem name"))
        val field = ui.onNodeWithContentDescription("Totem name")
        field.performClick().performTextReplacement("Changed")
        field.assertIsFocused().assertIsDisplayed().performImeAction()
        sheet.performScrollToNode(hasContentDescription("Character name"))
        ui.onNodeWithContentDescription("Character name").assertTextContains("First")
        ui.runOnIdle { assertEquals("Changed", totem) }
    }

    @Test fun watermarkKeepsItsInkPositionWhenTheBottomInsetGrows() {
        var covered by mutableStateOf(0.dp)
        ui.setContent {
            SheetTheme {
                // Supply the docked keyboard's inset deterministically, including on devices using a floating IME.
                Box(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets(bottom = covered))) {
                    Box(Modifier.fillMaxSize().sheetWatermark().background(Color.White).testTag("paper"))
                }
            }
        }
        val paper = ui.onNodeWithTag("paper")
        val before = paper.captureToImage().toPixelMap()
        ui.runOnIdle { covered = 225.dp }
        val after = paper.captureToImage().toPixelMap()
        assertTrue(after.height < before.height - 100)
        assertEquals(before.width, after.width)
        var ink = 0
        var changed = 0
        for (y in 0 until after.height - 4 step 3) for (x in 0 until after.width step 3) {
            if (before[x, y].green < .98f) ink++
            if (before[x, y] != after[x, y]) changed++
        }
        assertTrue("Expected faint ink in the common visible area", ink > 50)
        assertTrue("Keyboard displaced the watermark ($changed samples)", changed < 10)
    }
}
