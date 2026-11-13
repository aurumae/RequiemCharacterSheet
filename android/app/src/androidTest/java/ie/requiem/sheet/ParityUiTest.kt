package ie.requiem.sheet

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import org.junit.Rule
import org.junit.Test
import java.util.UUID

class ParityUiTest {
    @get:Rule val ui = createAndroidComposeRule<MainActivity>()
    private fun library() {
        ui.onNodeWithTag("dark-pack-splash").performClick()
        ui.waitUntil(8000) { ui.onAllNodesWithTag("character-library").fetchSemanticsNodes().isNotEmpty() }
    }
    private fun sheet(matcher: SemanticsMatcher): SemanticsNodeInteraction {
        ui.onNodeWithTag("character-sheet").performScrollToNode(matcher)
        return ui.onNode(matcher)
    }
    private fun jump(name: String) {
        ui.onNodeWithContentDescription("Sections").performClick()
        ui.onNode(hasText(name) and hasAnyAncestor(isPopup())).performScrollTo().performClick()
    }
    private fun choose(field: String, id: String, search: String) {
        // At phone width the temporary XP notice can cover the Clan row. Like
        // CoreSheetUiTest, wait for that notice before testing a physical tap.
        ui.waitUntil(6_000) { ui.onAllNodesWithText("Your available Experiences are now below zero.").fetchSemanticsNodes().isEmpty() }
        sheet(hasContentDescription(field)).performClick()
        ui.onNodeWithTag("identity-search").performTextInput(search)
        ui.onNodeWithTag("identity-options").performScrollToNode(hasTestTag("identity-option-$id"))
        ui.onNodeWithTag("identity-option-$id").performClick()
    }
    @Test fun licencesAreReadableOfflineAndAboutSurvivesRotation() {
        library()
        ui.onNodeWithTag("character-library").performScrollToNode(hasText("About this app"))
        ui.onNodeWithText("About this app").performClick()
        ui.onNodeWithText("Version ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})").assertExists()
        for (font in listOf("IM Fell English", "Cinzel")) {
            ui.onNodeWithTag("about-content").performScrollToNode(hasText(font))
            ui.onNodeWithText(font).performClick()
            ui.onNodeWithTag("about-content").performScrollToNode(hasText("SIL OPEN FONT LICENSE", substring = true))
            ui.onNodeWithText("SIL OPEN FONT LICENSE", substring = true).assertIsDisplayed()
            ui.activityRule.scenario.recreate()
            ui.onNodeWithText(font).assertExists()
            ui.onNodeWithTag("about-content").performScrollToNode(hasText("TERMINATION"))
            ui.onNodeWithText("TERMINATION").assertIsDisplayed()
            ui.onNodeWithText("Back to About").performClick()
        }
        ui.onNodeWithTag("about-content").performScrollToNode(hasText("Dark Pack"))
        ui.onNodeWithText("Dark Pack").performClick()
        ui.onNodeWithText("This is unofficial Fan Content", substring = true).assertExists()
        ui.onNodeWithText("Done").performClick()
        ui.onNodeWithTag("character-library").assertExists()
    }
    @Test fun bloodlinePickerRestrictionsPricesAndBaneSurviveReopen() {
        library()
        ui.onNodeWithTag("character-library").performScrollToNode(hasText("New blank sheet"))
        ui.onNodeWithText("New blank sheet").performClick()
        ui.waitUntil(8000) { ui.onAllNodesWithTag("character-sheet").fetchSemanticsNodes().isNotEmpty() }
        val name = "Morbus " + UUID.randomUUID().toString().take(8)
        sheet(hasContentDescription("Character name")).performTextInput(name)
        ui.onNodeWithContentDescription("Character name").performImeAction()
        jump("Disciplines")
        sheet(hasText("Add Discipline")).performClick()
        ui.onAllNodesWithTag("catalog-search").onFirst().performTextInput("Cachexy")
        ui.onAllNodesWithTag("catalog-cachexy").onFirst().assertIsNotEnabled()
        ui.onNodeWithText("Only the Morbus bloodline can learn Cachexy").assertExists()
        ui.onNodeWithText("Cancel").performClick()
        jump("Character")
        choose("Clan", "mekhet", "Mekhet")
        choose("Bloodline", "morbus", "Morbus")
        ui.onNodeWithContentDescription("Bloodline").assert(hasStateDescription("Morbus"))
        ui.onNodeWithContentDescription("XP Mode").performClick()
        jump("Disciplines")
        sheet(hasText("Add Discipline")).performClick()
        ui.onAllNodesWithTag("catalog-search").onFirst().performTextInput("Cachexy")
        ui.onAllNodesWithTag("catalog-cachexy").onFirst().assertIsEnabled().performClick()
        ui.onNodeWithContentDescription("XP Mode").assert(hasStateDescription("On, -3 Experiences available"))
        jump("Banes")
        sheet(hasText("Morbus Bane: The Unclean Curse")).assertExists()
        jump("Character")
        choose("Clan", "ventrue", "Ventrue")
        sheet(hasContentDescription("Bloodline")).assert(hasStateDescription("Morbus"))
        ui.onNodeWithContentDescription("Back").performClick()
        ui.waitUntil(8000) { ui.onAllNodesWithTag("character-library").fetchSemanticsNodes().isNotEmpty() }
        ui.onNodeWithTag("character-library").performScrollToNode(hasText(name))
        ui.onNodeWithText(name).performClick()
        ui.waitUntil(8000) { ui.onAllNodesWithTag("character-sheet").fetchSemanticsNodes().isNotEmpty() }
        sheet(hasContentDescription("Bloodline")).assert(hasStateDescription("Morbus"))
        ui.onNodeWithContentDescription("XP Mode").assert(hasStateDescription("On, -3 Experiences available"))
        sheet(hasContentDescription("Bloodline")).performClick()
        ui.onNodeWithText("No Bloodline").performClick()
        sheet(hasContentDescription("Bloodline")).assert(hasStateDescription("Not chosen"))
        jump("Disciplines")
        sheet(hasContentDescription("Cachexy")).assertExists()
    }
}
