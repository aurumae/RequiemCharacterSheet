package ie.requiem.sheet

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import org.junit.Rule
import org.junit.Test
import java.util.UUID

@OptIn(ExperimentalTestApi::class)
class Beta2UiTest {
    @get:Rule val ui = createAndroidComposeRule<MainActivity>()
    private fun sheet(matcher: SemanticsMatcher): SemanticsNodeInteraction {
        ui.onNodeWithTag("character-sheet").performScrollToNode(matcher)
        return ui.onNode(matcher)
    }
    private fun jump(name: String) {
        ui.onNodeWithTag("section-pill").performClick()
        ui.onNode(hasText(name) and hasAnyAncestor(isPopup())).performScrollTo().performClick()
        ui.onNodeWithTag("section-pill").assert(hasStateDescription(name))
    }
    private fun begin(): String {
        ui.onNodeWithTag("dark-pack-splash").performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-library").fetchSemanticsNodes().isNotEmpty() }
        ui.onNodeWithTag("character-library").performScrollToNode(hasText("New blank sheet"))
        ui.onNodeWithText("New blank sheet").performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-sheet").fetchSemanticsNodes().isNotEmpty() }
        val name = "Beta two " + UUID.randomUUID().toString().take(8)
        sheet(hasContentDescription("Character name")).performTextInput(name)
        ui.onNodeWithContentDescription("Character name").performImeAction()
        return name
    }
    private fun addCondition(name: String) {
        jump("Conditions")
        sheet(hasText("Add Condition")).performClick()
        ui.onNodeWithTag("condition-search").performTextInput(name)
        ui.onNodeWithTag("condition-options").performScrollToNode(hasText(name))
        ui.onNode(hasText(name) and hasAnyAncestor(hasTestTag("condition-options"))).performClick()
        ui.onNodeWithTag("condition-full-card").assertExists()
    }
    @Test fun conditionNoteCounterBeatResolutionAndCustomCardSurviveRecreation() {
        begin()
        addCondition("Charmed")
        ui.onNodeWithTag("condition-Note").performTextInput("Lady Ysolde")
        ui.activityRule.scenario.recreate()
        ui.onNodeWithTag("condition-Note").assertTextContains("Lady Ysolde")
        ui.onNodeWithTag("condition-take-beat").performScrollTo().performClick()
        ui.onNodeWithTag("condition-full-card").assertExists()
        ui.onNodeWithTag("condition-resolve").performScrollTo().performClick()
        sheet(hasText("No Conditions")).assertExists()
        addCondition("Tempted")
        ui.onNodeWithContentDescription("Increase Condition penalty").performClick()
        ui.onNodeWithText("Penalty: −2").assertExists()
        ui.onNodeWithText("Done").performClick()
        jump("Conditions")
        sheet(hasText("Add Condition")).performClick()
        ui.onNodeWithTag("condition-search").performTextInput("Not a book entry")
        ui.onNodeWithText("Custom Condition").performClick()
        ui.onNodeWithTag("condition-Name").performScrollTo().performTextInput("Haunted")
        ui.onNodeWithTag("condition-Effect").performScrollTo().performTextInput("Shadows whisper")
        ui.onNodeWithContentDescription("Persistent Condition").performScrollTo().performClick()
        ui.activityRule.scenario.recreate()
        ui.onNodeWithTag("condition-Name").performScrollTo().assertTextContains("Haunted")
        ui.onNodeWithTag("condition-Effect").performScrollTo().assertTextContains("Shadows whisper")
        ui.onNodeWithContentDescription("Persistent Condition").performScrollTo().assertIsOn()
        ui.onNodeWithText("Done").performClick()
        jump("Experience")
        sheet(hasText("Change Log")).performClick()
        ui.onAllNodesWithText("Charmed (Lady Ysolde)").assertCountEquals(3)
        ui.onAllNodesWithText("+1 Beat").assertCountEquals(2)
    }
    @Test fun identityDetailsSpecialtyLinkedMeritAndConditionIndicators() {
        begin()
        sheet(hasContentDescription("Mask")).performClick()
        ui.onNodeWithTag("identity-search").performTextInput("Authoritarian")
        ui.onNodeWithTag("identity-option-authoritarian").performClick()
        sheet(hasContentDescription("Mask details")).performClick()
        ui.onNodeWithTag("entry-details").performScrollToNode(hasText("Single Willpower"))
        ui.onNodeWithText("Single Willpower").assertExists()
        ui.onNodeWithText("Done").performClick()
        jump("Skills")
        sheet(hasContentDescription("Add Firearms specialty")).performClick()
        ui.onNodeWithTag("specialty-input").performTextInput("Rifles")
        ui.activityRule.scenario.recreate()
        ui.onNodeWithTag("specialty-input").assertTextContains("Rifles")
        ui.onNodeWithText("Add").performClick()
        jump("Merits")
        sheet(hasText("Add Merit")).performClick()
        ui.onNodeWithTag("catalog-search").performTextInput("Area of Expertise")
        ui.onNodeWithTag("catalog-area-of-expertise").performClick()
        ui.onNodeWithText("Rifles (Firearms)").performClick()
        ui.onNodeWithText("Add").performClick()
        jump("Skills")
        sheet(hasContentDescription("Firearms specialty: Rifles")).performClick()
        ui.onNodeWithText("Used by Area of Expertise (Rifles)", substring = true).assertExists()
        ui.onNodeWithTag("specialty-input").performTextReplacement("Pistols")
        ui.onNode(hasText("Save") and hasAnyAncestor(isDialog())).performClick()
        jump("Merits")
        sheet(hasContentDescription("Area of Expertise (Pistols)")).assertExists()
        addCondition("Broken")
        ui.onNodeWithText("Done").performClick()
        jump("Attributes")
        sheet(hasContentDescription("Resolve")).performCustomAccessibilityActionWithLabel("Conditions affecting Resolve")
        ui.onNodeWithText("Broken: −2 to rolls involving Resolve").performClick()
        ui.onNodeWithTag("condition-full-card").assertExists()
    }
}
