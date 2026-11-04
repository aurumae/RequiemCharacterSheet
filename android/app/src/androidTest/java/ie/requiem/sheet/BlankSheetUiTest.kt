package ie.requiem.sheet

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class BlankSheetUiTest {
    @get:Rule val ui = createAndroidComposeRule<MainActivity>()

    @Test fun playSaveReopenAndRefund() {
        val name = "Test " + UUID.randomUUID().toString().take(8)
        fun awaitText(value: String) = ui.waitUntil(8_000) { ui.onAllNodesWithText(value).fetchSemanticsNodes().isNotEmpty() }
        fun awaitLibrary() = ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-library").fetchSemanticsNodes().isNotEmpty() }
        fun tapStaminaDot(level: Int) {
            val cell = 48 * ui.activity.resources.displayMetrics.density
            ui.onNodeWithContentDescription("Stamina").performScrollTo().performTouchInput {
                click(Offset(width - (5 - level + .5f) * cell, height / 2f))
            }
        }
        awaitLibrary()
        ui.onNodeWithTag("character-library").performScrollToNode(hasText("New blank sheet"))
        ui.onNodeWithText("New blank sheet").performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithContentDescription("Character name").fetchSemanticsNodes().isNotEmpty() }
        ui.onNodeWithContentDescription("Character name").performTextInput(name)
        ui.onNodeWithContentDescription("Character name").performImeAction()
        tapStaminaDot(2)
        ui.onNodeWithText("XP Mode").performScrollTo().performClick()
        tapStaminaDot(3)
        ui.onNodeWithContentDescription("Health box 8 of 8").performScrollTo().performClick()
        ui.onNodeWithContentDescription("-4 XP available").assertExists()
        ui.activityRule.scenario.recreate()
        awaitText(name)
        ui.onNodeWithText("Save").performClick()
        awaitText("Saved")
        ui.onNodeWithContentDescription("Character name").assertExists()
        ui.onNodeWithContentDescription("Back").performClick()
        awaitLibrary()
        ui.onNodeWithTag("character-library").performScrollToNode(hasText(name))
        ui.onNodeWithText(name).performClick()
        awaitText(name)
        ui.onNodeWithContentDescription("Health box 8 of 8").assert(hasStateDescription("bashing"))
        ui.onNodeWithText("Change Log").performScrollTo().performClick()
        ui.onNodeWithText("Spent 4").assertExists()
        ui.onNodeWithText("Free").assertExists()
        ui.onNodeWithText("Done").performClick()
        // The same row also supports TalkBack's adjustment action.
        ui.onNodeWithContentDescription("Stamina").performScrollTo()
            .performSemanticsAction(SemanticsActions.SetProgress) { it(2f) }
        ui.onNodeWithContentDescription("0 XP available").assertExists()
        ui.onNodeWithText("Change Log").performScrollTo().performClick()
        ui.onNodeWithText("Refunded 4").assertExists()
    }
}
