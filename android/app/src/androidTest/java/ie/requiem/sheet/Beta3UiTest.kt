package ie.requiem.sheet

import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import ie.requiem.rules.*
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class Beta3UiTest {
    @get:Rule val ui = createComposeRule()
    private val catalog = Catalog.bundled()

    @Test fun repeatedDisciplineRowsInClanAndBookRemainSelectable() {
        val c = CharacterSave(clan = TraitSource(catalog = "ventrue"), bloodline = TraitSource(catalog = "bron"))
        var chosen: String? = null
        ui.setContent { SheetTheme { EntryPicker(EntryKind.Discipline, c, catalog, false, { chosen = it.id }, {}, {}, {}) } }
        ui.onAllNodesWithTag("catalog-search").onFirst().performTextInput("Crochan")
        ui.onAllNodesWithTag("catalog-search").onFirst().performImeAction()
        ui.onNodeWithText("In-clan for Bron").assertExists()
        ui.onAllNodesWithTag("catalog-crochan").assertCountEquals(2)
        ui.onAllNodesWithTag("catalog-crochan")[0].performClick()
        ui.runOnIdle { assertEquals("crochan", chosen); chosen = null }
        ui.onAllNodesWithTag("catalog-crochan")[1].performScrollTo().performClick()
        ui.runOnIdle { assertEquals("crochan", chosen) }
    }

    @Test fun blankRequiredQualifierCannotBeAddedOrCommittedAfterEditing() {
        var c by mutableStateOf(CharacterSave())
        var route by mutableStateOf<String?>("qualifierAdd|language")
        ui.setContent { SheetTheme { SheetDialogs(route, c, catalog, { c = c.edit(it, catalog) }, { route = it }) } }
        ui.onNodeWithText("Add").assertIsNotEnabled()
        ui.onNodeWithTag("qualifier-input").performTextInput("   ")
        ui.onNodeWithText("Add").assertIsNotEnabled()
        ui.onNodeWithTag("qualifier-input").performTextReplacement("Irish")
        ui.onNodeWithText("Add").performClick()
        ui.runOnIdle {
            assertEquals("Irish", c.merits.single().qualifier)
            route = "qualifierEdit|${c.merits.single().id}"
        }
        ui.onNodeWithTag("qualifier-input").performTextReplacement(" ")
        ui.onNodeWithText("Done").assertIsNotEnabled()
        ui.runOnIdle { assertEquals("Irish", c.merits.single().qualifier) }
    }

    @Test fun elderBaneToggleShowsItsSourceAndPersistsItsState() {
        var c by mutableStateOf(CharacterSave(clan = TraitSource(catalog = "daeva"), humanity = 3, elderBaneActive = true))
        ui.setContent { SheetTheme { ElderBaneRow(c, catalog, true) { c = c.edit(it, catalog) } } }
        ui.onNodeWithText("Elder Bane: The Captivating Curse").assertExists()
        ui.onNodeWithText("Thousand Years of Night", substring = true).assertExists()
        ui.onNodeWithContentDescription("The Captivating Curse in effect").assertIsOn().performClick().assertIsOff()
        ui.runOnIdle {
            assertFalse(c.elderBaneActive)
            c = CharacterCodec(catalog).decode(CharacterCodec(catalog).encode(c))
        }
        ui.onNodeWithContentDescription("The Captivating Curse in effect").assertIsOff()
        ui.onNodeWithText("Switched off.", substring = true).assertExists()
    }

    @Test fun carouselRemovalKeepsValidPageAndOnlyHintsWhenMoreCardsFollow() {
        var c by mutableStateOf(CharacterSave(conditions = listOf("charmed", "broken", "tempted").map { CharacterCondition(TraitSource(catalog = it)) }))
        ui.setContent { SheetTheme { ConditionsSection(c, catalog, true) {} } }
        ui.onNodeWithText("1 of 3 · swipe for more").assertExists()
        ui.onNodeWithTag("condition-carousel").performScrollToIndex(1)
        ui.onNodeWithText("2 of 3 · swipe for more").assertExists()
        ui.runOnIdle { c = c.copy(conditions = c.conditions.drop(1)) }
        ui.onNodeWithTag("condition-carousel").performScrollToIndex(1)
        ui.onNodeWithText("2 of 2").assertExists()
        ui.runOnIdle { c = c.copy(conditions = c.conditions.dropLast(1)) }
        ui.onNodeWithText("1 of 1").assertExists()
        ui.runOnIdle { c = c.copy(conditions = emptyList()) }
        ui.onNodeWithText("No Conditions").assertExists()
    }
}
