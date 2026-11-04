package ie.requiem.sheet

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
        fun stamina(level: Int) {
            ui.onNodeWithContentDescription("Stamina").performScrollTo()
                .performSemanticsAction(SemanticsActions.SetProgress) { it(level.toFloat()) }
        }
        awaitText("New blank sheet")
        ui.onNodeWithText("New blank sheet").performClick()
        awaitText("Character name")
        ui.onNodeWithText("Character name").performTextInput(name)
        ui.onNodeWithText("Character name").performImeAction()
        stamina(2)
        ui.onNodeWithText("XP Mode").performScrollTo().performClick()
        stamina(3)
        ui.onNodeWithContentDescription("Health box 8 of 8").performScrollTo().performClick()
        ui.onNodeWithText("-4 XP available").assertExists()
        ui.activityRule.scenario.recreate()
        awaitText(name)
        ui.onNodeWithText("Save").performClick()
        awaitText("New blank sheet")
        ui.onNodeWithText(name).performClick()
        awaitText("Character name")
        ui.onNodeWithContentDescription("Health box 8 of 8").assert(hasStateDescription("bashing"))
        ui.onNodeWithText("Stamina  2 → 3  ·  4 XP spent").assertExists()
        stamina(2)
        ui.onNodeWithText("0 XP available").assertExists()
        ui.onNodeWithText("Stamina  3 → 2  ·  4 XP refunded").assertExists()
    }
}
