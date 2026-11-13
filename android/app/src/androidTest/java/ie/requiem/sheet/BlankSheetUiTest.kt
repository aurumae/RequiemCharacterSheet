package ie.requiem.sheet

import ie.chronicles.ui.*

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID
import android.os.SystemClock

@RunWith(AndroidJUnit4::class)
class BlankSheetUiTest {
    @get:Rule val ui = createAndroidComposeRule<MainActivity>()
    @org.junit.Before fun portraitForRegression() {
        ui.activity.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        ui.waitForIdle()
    }

    @Test fun splashExpiresAfterFiveSecondsAndDoesNotRestartOnRotation() {
        ui.onNodeWithTag("dark-pack-splash").assertExists()
        ui.onNodeWithTag("character-library").assertDoesNotExist()
        SystemClock.sleep(2_000)
        ui.activityRule.scenario.recreate()
        ui.onNodeWithTag("dark-pack-splash").assertExists()
        ui.waitUntil(3_500) { ui.onAllNodesWithTag("dark-pack-splash").fetchSemanticsNodes().isEmpty() }
        ui.onNodeWithTag("character-library").assertExists()
    }

    private fun sheetNode(matcher: SemanticsMatcher): SemanticsNodeInteraction {
        ui.onNodeWithTag("character-sheet").performScrollToNode(matcher)
        return ui.onNode(matcher)
    }

    @Test fun playSaveReopenAndRefund() {
        val name = "Test " + UUID.randomUUID().toString().take(8)
        fun awaitText(value: String) = ui.waitUntil(8_000) { ui.onAllNodesWithText(value).fetchSemanticsNodes().isNotEmpty() }
        fun awaitLibrary() = ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-library").fetchSemanticsNodes().isNotEmpty() }
        fun tapStaminaDot(level: Int) {
            val cell = 24 * ui.activity.resources.displayMetrics.density
            sheetNode(hasContentDescription("Stamina")).performTouchInput {
                click(Offset(width - (5 - level + .5f) * cell, height / 2f))
            }
        }
        ui.onNodeWithTag("dark-pack-splash").performClick()
        ui.onNodeWithTag("dark-pack-splash").assertDoesNotExist()
        awaitLibrary()
        ui.onNodeWithTag("character-library").performScrollToNode(hasText("About this app"))
        ui.onNodeWithText("About this app").performClick()
        ui.onNodeWithText("Dark Pack").performClick()
        ui.onNodeWithText("This is unofficial Fan Content permitted under the Dark Pack. This app is not official World of Darkness material.").assertExists()
        ui.onNodeWithText("Done").performClick()
        ui.onNodeWithTag("character-library").performScrollToNode(hasText("New blank sheet"))
        ui.onNodeWithText("New blank sheet").performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithContentDescription("Character name").fetchSemanticsNodes().isNotEmpty() }
        ui.onNodeWithContentDescription("Character name").performTextInput(name)
        ui.onNodeWithContentDescription("Character name").performImeAction()
        tapStaminaDot(2)
        sheetNode(hasText("XP Mode")).performClick()
        sheetNode(hasContentDescription("Stamina")).performClick()
        ui.onNode(hasText("0") and hasAnyAncestor(hasTestTag("rating-menu"))).assertDoesNotExist()
        ui.onNode(hasText("6") and hasAnyAncestor(hasTestTag("rating-menu"))).assertDoesNotExist()
        ui.onNodeWithText("3").performClick()
        // Let the overdraft notice clear before tapping the bottom Health row.
        ui.waitUntil(6_000) {
            ui.onAllNodesWithText("Your available Experiences are now below zero.").fetchSemanticsNodes().isEmpty()
        }
        sheetNode(hasContentDescription("Health box 8 of 8")).performClick()
        ui.onNodeWithContentDescription("Health box 8 of 8").assert(hasStateDescription("bashing"))
        ui.onNodeWithContentDescription("Health box 7 of 8").assert(hasStateDescription("unmarked"))
        sheetNode(hasContentDescription("-4 XP available")).assertExists()
        ui.activityRule.scenario.recreate()
        sheetNode(hasContentDescription("Character name")).assertTextContains(name)
        ui.onNodeWithText("Save").performClick()
        awaitText("Saved")
        ui.onNodeWithContentDescription("Character name").assertExists()
        ui.onNodeWithContentDescription("Back").performClick()
        awaitLibrary()
        ui.onNodeWithTag("character-library").performScrollToNode(hasText(name))
        ui.onNodeWithText(name).performClick()
        awaitText(name)
        sheetNode(hasContentDescription("Health box 8 of 8")).assert(hasStateDescription("bashing"))
        sheetNode(hasText("Change Log")).performClick()
        ui.onNodeWithText("Spent 4").assertExists()
        ui.onNodeWithText("Free").assertExists()
        ui.onNodeWithText("Done").performClick()
        // The same row also supports TalkBack's adjustment action.
        sheetNode(hasContentDescription("Stamina"))
            .performSemanticsAction(SemanticsActions.SetProgress) { it(2f) }
        sheetNode(hasContentDescription("0 XP available")).assertExists()
        sheetNode(hasText("Change Log")).performClick()
        ui.onNodeWithText("Refunded 4").assertExists()
    }
}
