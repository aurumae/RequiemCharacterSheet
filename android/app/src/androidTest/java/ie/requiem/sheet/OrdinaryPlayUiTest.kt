package ie.requiem.sheet

import ie.chronicles.ui.*

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import org.junit.Rule
import org.junit.Test
import java.util.UUID

class OrdinaryPlayUiTest {
    @get:Rule val ui = createAndroidComposeRule<MainActivity>()
    @org.junit.Before fun portraitForRegression() {
        ui.activity.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        ui.waitForIdle()
    }
    private fun sheet(matcher: SemanticsMatcher): SemanticsNodeInteraction {
        ui.onNodeWithTag("character-sheet").performScrollToNode(matcher)
        return ui.onNode(matcher)
    }
    private fun jump(section: String) {
        ui.onNodeWithContentDescription("Sections").performClick()
        ui.onNode(hasText(section) and hasAnyAncestor(isPopup())).performScrollTo().performClick()
    }
    private fun choose(kind: String, id: String, search: String) {
        sheet(hasText("Add $kind")).performClick()
        ui.onAllNodesWithTag("catalog-search").onFirst().performTextInput(search)
        ui.onAllNodesWithTag("catalog-search").onFirst().performImeAction()
        ui.onAllNodesWithTag("catalog-options").onFirst().performScrollToNode(hasTestTag("catalog-$id"))
        ui.onAllNodesWithTag("catalog-$id").onFirst().performClick()
    }
    private fun rated(name: String, value: Int) {
        sheet(hasContentDescription("Options for $name")).performClick()
        ui.onNodeWithText("Set rating").performClick()
        ui.onNode(hasText(value.toString()) and hasAnyAncestor(isPopup())).performScrollTo().performClick()
    }
    private fun remove(name: String) {
        sheet(hasContentDescription("Options for $name")).performClick()
        ui.onNodeWithText("Delete").performClick()
        ui.onNodeWithText("Remove", substring = false).performClick()
    }
    private fun number(label: String, value: Int) {
        sheet(hasText("$label:")).performClick()
        ui.onNodeWithTag("number-prompt").performTextReplacement(value.toString())
        ui.onNode(hasText("Done") and hasAnyAncestor(isDialog())).performClick()
    }
    private fun xp(value: Int) { ui.onNodeWithContentDescription("XP Mode").assert(hasStateDescription("On, $value Experiences available")) }
    private fun begin(): String {
        val name = "Play " + UUID.randomUUID().toString().take(8)
        ui.onNodeWithTag("dark-pack-splash").performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-library").fetchSemanticsNodes().isNotEmpty() }
        ui.onNodeWithTag("character-library").performScrollToNode(hasText("New blank sheet"))
        ui.onNodeWithText("New blank sheet").performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-sheet").fetchSemanticsNodes().isNotEmpty() }
        sheet(hasContentDescription("Character name")).performTextInput(name)
        ui.onNodeWithContentDescription("Character name").performImeAction()
        jump("Experience"); number("Earned", 100)
        ui.onNodeWithContentDescription("XP Mode").performClick()
        return name
    }
    private fun reopen(name: String) {
        ui.onNodeWithContentDescription("Back").performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-library").fetchSemanticsNodes().isNotEmpty() }
        ui.onNodeWithTag("character-library").performScrollToNode(hasText(name))
        ui.onNodeWithText(name).performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-sheet").fetchSemanticsNodes().isNotEmpty() }
    }

    @Test fun powersMeritsBanesAndTrackersSurviveReopening() {
        val name = begin()
        jump("Character")
        sheet(hasContentDescription("Clan")).performClick()
        ui.onNodeWithTag("identity-search").performTextInput("Daeva")
        ui.onNodeWithTag("identity-search").performImeAction()
        ui.onNodeWithTag("identity-options").performScrollToNode(hasTestTag("identity-option-daeva"))
        ui.onNodeWithTag("identity-option-daeva").performClick()
        jump("Disciplines"); choose("Discipline", "celerity", "Celerity"); xp(97)
        sheet(hasContentDescription("Celerity")).performClick()
        ui.onNodeWithTag("entry-details").assertExists()
        ui.onNodeWithText("Done").performClick()
        rated("Celerity", 2); xp(94)
        jump("Merits"); choose("Merit", "iron-skin", "Iron Skin"); xp(92)
        sheet(hasContentDescription("Options for Iron Skin")).performClick()
        ui.onNodeWithText("Set rating").performClick()
        ui.onNode(hasText("3") and hasAnyAncestor(isPopup())).assertDoesNotExist()
        ui.onNode(hasText("4") and hasAnyAncestor(isPopup())).performClick(); xp(90)
        choose("Merit", "defensive-combat", "Defensive Combat")
        ui.onNodeWithText("Brawl").performClick()
        ui.onNode(hasText("Add") and hasAnyAncestor(isDialog())).performClick(); xp(89)
        choose("Merit", "giant", "Giant"); xp(86)
        jump("Aspirations")
        sheet(hasContentDescription("Aspiration 1")).performClick()
        ui.onNodeWithTag("text-prompt").performTextInput("Find the missing elder.\nKeep the coterie together.")
        ui.onNodeWithText("Done").performClick()
        jump("Banes"); choose("Bane", "bells", "Bells")
        repeat(2) { index ->
            sheet(hasText("Add Bane")).performClick()
            ui.onNodeWithText("Custom Bane").performClick()
            ui.onNodeWithTag("custom-name").performTextInput("Homebrew Bane $index")
            ui.onNode(hasText("Add") and hasAnyAncestor(isDialog())).performClick()
        }
        sheet(hasText("A vampire can have at most 3 Banes.")).assertExists()
        jump("Health"); sheet(hasContentDescription("Health box 7 of 7")).performClick()
        jump("Willpower"); sheet(hasContentDescription("Willpower box 2 of 2")).performClick()
        jump("Humanity"); sheet(hasContentDescription("Touchstone at Humanity 6")).performClick()
        ui.onNodeWithTag("text-prompt").performTextInput("My sister")
        ui.onNodeWithText("Done").performClick()
        sheet(hasContentDescription("Humanity 6")).performClick(); xp(86)
        jump("Banes"); sheet(hasContentDescription("The Wanton Curse in effect")).assertIsOn()
        jump("Blood Potency"); sheet(hasContentDescription("Blood Potency")).performClick()
        ui.onNode(hasText("2") and hasAnyAncestor(hasTestTag("rating-menu"))).performClick(); xp(81)
        jump("Vitae"); number("Current Vitae", 11)
        jump("Advantages"); number("Armor", 9)
        jump("Experience")
        repeat(5) { sheet(hasContentDescription("Increase Beats")).performClick() }; xp(82)
        ui.activityRule.scenario.recreate()
        xp(82); reopen(name); xp(82)
        jump("Health"); sheet(hasContentDescription("Health box 7 of 7")).assert(hasStateDescription("bashing"))
        jump("Willpower"); sheet(hasContentDescription("Willpower box 2 of 2")).assert(hasStateDescription("spent"))
        jump("Vitae"); sheet(hasContentDescription("Current Vitae: 11")).assertExists()
        jump("Humanity"); sheet(hasContentDescription("Touchstone at Humanity 6")).assertTextContains("My sister")
        jump("Aspirations"); sheet(hasContentDescription("Aspiration 1")).assertTextContains("Find the missing elder.\nKeep the coterie together.")
    }

    @Test fun sorceryDiscountsRefundsAndNonrefundableLosses() {
        val name = begin()
        jump("Disciplines"); choose("Discipline", "cruac", "Cruac"); xp(96)
        sheet(hasText("Learning rituals requires Circle of the Crone or Fir'awn Status 1")).assertExists()
        jump("Rituals"); choose("Ritual", "rigor-mortis", "Rigor Mortis"); xp(96)
        choose("Ritual", "pangs-of-proserpina", "Pangs"); xp(94)
        sheet(hasText("Rigor Mortis")).performClick()
        ui.onNodeWithTag("entry-details").performScrollToNode(hasText("1 Vitae"))
        ui.onNodeWithText("1 Vitae").assertExists(); ui.onNodeWithText("Done").performClick()
        jump("Devotions"); sheet(hasText("Add Devotion")).performClick()
        ui.onNodeWithText("Custom Devotion").performClick()
        ui.onNodeWithTag("custom-name").performTextInput("Moonless Step")
        ui.onNodeWithTag("devotion-cost").performTextReplacement("3")
        ui.onNode(hasText("Add") and hasAnyAncestor(isDialog())).performClick(); xp(91)
        sheet(hasText("Moonless Step")).performClick()
        ui.onNodeWithTag("devotion-cost").performTextReplacement("5")
        ui.onNodeWithText("Done").performClick(); xp(89)
        jump("Character"); sheet(hasContentDescription("Covenant")).performClick()
        ui.onNodeWithTag("identity-search").performTextInput("Ordo Dracul")
        ui.onNodeWithTag("identity-search").performImeAction()
        ui.onNodeWithTag("identity-options").performScrollToNode(hasTestTag("identity-option-ordo-dracul"))
        ui.onNodeWithTag("identity-option-ordo-dracul").performClick()
        jump("Coils of the Dragon"); sheet(hasText("Choose")).performClick()
        ui.onAllNodesWithTag("catalog-search").onFirst().performTextInput("Wyrm")
        ui.onAllNodesWithTag("catalog-search").onFirst().performImeAction()
        ui.onAllNodesWithTag("catalog-mystery-of-the-wyrm").onFirst().performClick()
        choose("Scale", "kindred-sense-endowment", "Kindred Sense"); xp(87)
        rated("Coil of the Wyrm", 2); xp(81)
        remove("Kindred Sense Endowment"); xp(83)
        choose("Scale", "kindred-sense-endowment", "Kindred Sense"); xp(82)
        jump("Humanity"); sheet(hasContentDescription("Humanity 8")).performClick(); xp(80)
        sheet(hasContentDescription("Humanity 5")).performClick(); xp(80)
        jump("Blood Potency"); sheet(hasContentDescription("Blood Potency")).performClick()
        ui.onNode(hasText("2") and hasAnyAncestor(hasTestTag("rating-menu"))).performClick(); xp(75)
        sheet(hasContentDescription("Blood Potency")).performClick()
        ui.onNode(hasText("1") and hasAnyAncestor(hasTestTag("rating-menu"))).performClick(); xp(75)
        jump("Rituals"); sheet(hasText("Add Ritual")).performClick()
        ui.onNodeWithText("Custom Ritual").performClick()
        ui.onNodeWithTag("custom-name").performTextInput("Homebrew Rite")
        ui.onNodeWithText("Ritual dots: 1").performClick()
        ui.onNode(hasText("2") and hasAnyAncestor(isPopup())).performClick()
        ui.onNode(hasText("Add") and hasAnyAncestor(isDialog())).performClick(); xp(73)
        sheet(hasText("Requires Crúac 2")).assertExists()
        rated("Homebrew Rite", 3); xp(73)
        reopen(name); xp(73)
        jump("Rituals"); sheet(hasText("Requires Crúac 3")).assertExists()
        jump("Coils of the Dragon"); sheet(hasContentDescription("Coil of the Wyrm")).assert(hasStateDescription("2 base, 0 bonus"))
    }
}
