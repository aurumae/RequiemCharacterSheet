package ie.requiem.sheet

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import org.junit.Rule
import org.junit.Test
import java.util.UUID

class CoreSheetUiTest {
    @get:Rule val ui = createAndroidComposeRule<MainActivity>()

    private fun sheetNode(matcher: SemanticsMatcher): SemanticsNodeInteraction {
        ui.onNodeWithTag("character-sheet").performScrollToNode(matcher)
        return ui.onNode(matcher)
    }
    private fun jump(section: String) {
        ui.onNodeWithText("Sections").performClick()
        ui.onNodeWithText(section).performClick()
    }
    private fun rating(name: String, value: Int) {
        sheetNode(hasContentDescription(name)).performClick()
        ui.onNode(hasText(value.toString()) and hasAnyAncestor(hasTestTag("rating-menu"))).performClick()
    }

    @Test fun enterExistingCharacterThenBuyRenameCancelAndRefundSpecialties() {
        val name = "Core " + UUID.randomUUID().toString().take(8)
        ui.onNodeWithTag("dark-pack-splash").performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-library").fetchSemanticsNodes().isNotEmpty() }
        ui.onNodeWithTag("character-library").performScrollToNode(hasText("New blank sheet"))
        ui.onNodeWithText("New blank sheet").performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-sheet").fetchSemanticsNodes().isNotEmpty() }
        sheetNode(hasContentDescription("Character name")).performTextInput(name)
        ui.onNodeWithContentDescription("Character name").performImeAction()
        sheetNode(hasContentDescription("Player")).performTextInput("Sam")
        ui.onNodeWithContentDescription("Player").performImeAction()
        sheetNode(hasContentDescription("Clan")).performTextInput("ventrue")
        ui.onNodeWithContentDescription("Clan").performImeAction()
        ui.onNodeWithContentDescription("Clan").assertTextContains("Ventrue")
        sheetNode(hasContentDescription("Choose Mask")).performClick()
        ui.onNodeWithText("Search Mask").performTextInput("Author")
        ui.onNodeWithText("Authoritarian").performClick()
        sheetNode(hasContentDescription("Mask")).assertTextContains("Authoritarian")
        sheetNode(hasContentDescription("Covenant")).performTextInput("Our custom covenant")
        ui.onNodeWithContentDescription("Covenant").performImeAction()
        jump("Attributes")
        rating("Wits", 3)
        rating("Composure", 2)
        jump("Skills")
        rating("Occult", 2)
        // Use the pinned badge so the XP balance stays reachable on the long sheet.
        ui.onNodeWithContentDescription("XP Mode").performClick()
        sheetNode(hasContentDescription("Add Occult specialty")).performClick()
        ui.onNodeWithTag("specialty-input").performTextInput("Ghosts")
        ui.onNodeWithText("Add", substring = false).performClick()
        ui.onNodeWithContentDescription("XP Mode").assert(hasStateDescription("On, -1 Experiences available"))
        // The overdraft snackbar temporarily covers the bottom row. Wait for the notice
        // to leave before testing a real touch on that row.
        ui.waitUntil(6_000) { ui.onAllNodesWithText("Your available Experiences are now below zero.").fetchSemanticsNodes().isEmpty() }
        sheetNode(hasContentDescription("Occult specialty: Ghosts")).assertIsDisplayed().performClick()
        ui.onNodeWithTag("specialty-input").performTextReplacement("Spirits")
        ui.onNode(hasText("Save") and hasAnyAncestor(isDialog())).performClick()
        ui.onNodeWithContentDescription("XP Mode").assert(hasStateDescription("On, -1 Experiences available"))
        sheetNode(hasContentDescription("Add Occult specialty")).performClick()
        ui.onNodeWithTag("specialty-input").performTextInput("Do not save")
        ui.onNodeWithText("Cancel").performClick()
        ui.onNodeWithContentDescription("Occult specialty: Do not save").assertDoesNotExist()
        ui.activityRule.scenario.recreate()
        sheetNode(hasContentDescription("Occult specialty: Spirits")).assertExists()
        ui.onNodeWithContentDescription("Back").performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-library").fetchSemanticsNodes().isNotEmpty() }
        ui.onNodeWithTag("character-library").performScrollToNode(hasText(name))
        ui.onNodeWithText(name).performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-sheet").fetchSemanticsNodes().isNotEmpty() }
        sheetNode(hasContentDescription("Covenant")).assertTextContains("Our custom covenant")
        sheetNode(hasContentDescription("Wits")).assert(hasStateDescription("3 base, 0 bonus"))
        sheetNode(hasContentDescription("Occult")).assert(hasStateDescription("2 base, 0 bonus"))
        sheetNode(hasContentDescription("Occult specialty: Spirits")).performClick()
        ui.onNodeWithText("Delete").performClick()
        ui.onNodeWithContentDescription("XP Mode").assert(hasStateDescription("On, 0 Experiences available"))
        jump("Experience")
        sheetNode(hasText("Change Log")).performClick()
        ui.onNodeWithText("Spent 1").assertExists()
        ui.onNodeWithText("Refunded 1").assertExists()
    }
}
