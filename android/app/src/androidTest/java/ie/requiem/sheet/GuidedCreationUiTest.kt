package ie.requiem.sheet

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import ie.requiem.rules.*
import java.io.File
import java.util.UUID
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class GuidedCreationUiTest {
    @get:Rule val ui = createAndroidComposeRule<MainActivity>()
    private fun sheet(matcher: SemanticsMatcher): SemanticsNodeInteraction {
        ui.onNodeWithTag("character-sheet").performScrollToNode(matcher)
        return ui.onNode(matcher)
    }
    private fun jump(section: String) {
        ui.onNodeWithContentDescription("Sections").performClick()
        ui.onNode(hasText(section) and hasAnyAncestor(isPopup())).performScrollTo().performClick()
    }
    private fun rating(name: String, value: Int) {
        sheet(hasContentDescription(name)).performClick()
        ui.onNode(hasText(value.toString()) and hasAnyAncestor(hasTestTag("rating-menu"))).performScrollTo().performClick()
    }
    private fun priority(description: String, choice: String) {
        sheet(hasContentDescription(description)).performClick()
        ui.onNode(hasText(choice) and hasAnyAncestor(isPopup())).performClick()
    }
    private fun entryRating(name: String, value: Int) {
        sheet(hasContentDescription("Options for $name")).performClick()
        ui.onNodeWithText("Set rating").performClick()
        ui.onNode(hasText(value.toString()) and hasAnyAncestor(isPopup())).performClick()
    }
    private fun picker(kind: String, search: String) {
        sheet(hasText("Add $kind")).performClick()
        ui.onNodeWithTag("catalog-search").performTextInput(search)
    }
    private fun choose(id: String) {
        ui.onNodeWithTag("catalog-options").performScrollToNode(hasTestTag("catalog-$id"))
        ui.onNodeWithTag("catalog-$id").performClick()
    }
    private fun xp(value: Int) { ui.onNodeWithContentDescription("XP Mode").assert(hasStateDescription("On, $value Experiences available")) }
    private fun library() { ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-library").fetchSemanticsNodes().isNotEmpty() } }
    private fun enter() { ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-sheet").fetchSemanticsNodes().isNotEmpty() } }
    private fun start(): String {
        ui.onNodeWithTag("dark-pack-splash").performClick(); library()
        ui.onNodeWithTag("character-library").performScrollToNode(hasText("Guided character creation"))
        ui.onNodeWithText("Guided character creation").performClick(); enter()
        ui.onNodeWithContentDescription("XP Mode").assertDoesNotExist()
        val name = "Guided " + UUID.randomUUID().toString().take(8)
        jump("Character"); sheet(hasContentDescription("Character name")).performTextInput(name)
        ui.onNodeWithContentDescription("Character name").performImeAction()
        return name
    }
    private fun clan(name: String, favored: String) {
        jump("Character"); sheet(hasContentDescription("Clan")).performClick()
        ui.onNodeWithTag("identity-search").performTextInput(name)
        ui.onNodeWithTag("identity-option-${name.lowercase()}").performClick()
        ui.onNodeWithTag("favored-$favored").performClick()
    }
    private fun reopen(name: String) {
        ui.onNodeWithContentDescription("Back").performClick(); library()
        ui.onNodeWithTag("character-library").performScrollToNode(hasText(name))
        ui.onNodeWithText(name).performClick(); enter()
    }
    private fun finishAnyway() {
        jump("Character Creation"); sheet(hasTestTag("finish-creation")).performClick()
        ui.onNodeWithText("Some steps aren't done").assertExists()
        ui.onNodeWithText("Finish Anyway").performClick()
    }

    @Test fun prioritiesFavoredDotResumeAndFinishOnceWithRankExperiences() {
        val name = start(); clan("Ventrue", "presence")
        jump("Attributes")
        priority("Social Attribute priority", "Primary: 5 dots")
        sheet(hasContentDescription("Presence")).performClick()
        ui.onNode(hasText("1") and hasAnyAncestor(hasTestTag("rating-menu"))).assertDoesNotExist()
        ui.onNode(hasText("5") and hasAnyAncestor(hasTestTag("rating-menu"))).performClick()
        rating("Manipulation", 3)
        sheet(hasContentDescription("Composure")).performClick()
        ui.onNode(hasText("2") and hasAnyAncestor(hasTestTag("rating-menu"))).assertDoesNotExist()
        ui.onNode(hasText("1") and hasAnyAncestor(hasTestTag("rating-menu"))).performClick()
        priority("Social Attribute priority", "Tertiary: 3 dots")
        jump("Character Creation"); sheet(hasTestTag("finish-creation")).assertIsNotEnabled()
        sheet(hasText("More Social Attribute dots than its priority allows")).assertExists()
        jump("Attributes"); rating("Manipulation", 1)
        priority("Mental Attribute priority", "Secondary: 4 dots")
        priority("Physical Attribute priority", "Primary: 5 dots")
        ui.activityRule.scenario.recreate(); reopen(name)
        jump("Attributes")
        sheet(hasContentDescription("Social Attribute priority")).assert(hasStateDescription("Tertiary, 0 dots left"))
        sheet(hasContentDescription("Presence")).assert(hasStateDescription("5 base, 0 bonus, Includes the Ventrue dot"))
        jump("Humanity"); sheet(hasContentDescription("Touchstone at Humanity 7")).performClick()
        ui.onNodeWithTag("text-prompt").performTextInput("The family estate")
        ui.onNodeWithText("Done").performClick()
        jump("Character Creation"); sheet(hasTestTag("creation-step-5")).assert(hasText("Touchstone on Humanity 7", substring = true).not())
        sheet(hasTestTag("finish-creation")).performClick()
        ui.onNodeWithText("Keep Going").performClick()
        ui.onNodeWithContentDescription("XP Mode").assertDoesNotExist()
        finishAnyway()
        ui.onNodeWithTag("creation-ranks").performScrollToNode(hasTestTag("creation-rank-15"))
        ui.onNodeWithTag("creation-rank-15").performClick()
        ui.activityRule.scenario.recreate()
        ui.onNodeWithTag("creation-rank-15").assertIsSelected()
        ui.onNodeWithText("Cancel").performClick()
        finishAnyway()
        ui.onNodeWithTag("creation-ranks").performScrollToNode(hasTestTag("creation-rank-15"))
        ui.onNodeWithTag("creation-rank-15").assertIsSelected()
        ui.onNodeWithTag("confirm-finish-creation").performClick(); xp(15)
        jump("Attributes"); rating("Presence", 4); xp(15)
        rating("Presence", 5); xp(11)
        rating("Presence", 4); xp(15)
        reopen(name); xp(15)
        jump("Experience"); sheet(hasText("Change Log")).performClick()
        ui.onNodeWithText("Refunded 4").assertExists()
    }

    @Test fun creationPickersEnforcePrerequisitesRitualSlotsAndLeaveKeepsTheSheet() {
        val name = start(); clan("Daeva", "dexterity")
        jump("Disciplines"); picker("Discipline", "Cruac")
        ui.onNodeWithTag("catalog-cruac").assertIsNotEnabled()
        ui.onNodeWithText("Cancel").performClick()
        jump("Merits"); picker("Merit", "Telepathy")
        ui.onNodeWithTag("catalog-telepathy").assertIsNotEnabled()
        ui.onNodeWithText("Cancel").performClick()
        picker("Merit", "Covenant Status"); choose("covenant-status")
        ui.onNodeWithText("Circle of the Crone").performClick()
        ui.onNode(hasText("Add") and hasAnyAncestor(isDialog())).performClick()
        picker("Merit", "Resources"); choose("resources"); entryRating("Resources", 4)
        jump("Disciplines"); picker("Discipline", "Celerity"); choose("celerity"); entryRating("Celerity", 2)
        picker("Discipline", "Cruac"); choose("cruac")
        jump("Rituals"); picker("Ritual", "Rigor Mortis"); choose("rigor-mortis")
        picker("Ritual", "Pangs"); ui.onNodeWithTag("catalog-pangs-of-proserpina").assertIsNotEnabled()
        ui.onNodeWithText("Cancel").performClick()
        jump("Blood Potency"); rating("Blood Potency", 2)
        sheet(hasContentDescription("Blood Potency")).performClick()
        ui.onNode(hasText("3") and hasAnyAncestor(hasTestTag("rating-menu"))).assertDoesNotExist()
        ui.onNode(hasText("2") and hasAnyAncestor(hasTestTag("rating-menu"))).performClick()
        jump("Humanity"); sheet(hasContentDescription("Humanity 8")).assertIsNotEnabled()
        jump("Skills")
        for (text in listOf("Grappling", "Biting", "Street brawls")) {
            sheet(hasContentDescription("Add Brawl specialty")).performClick()
            ui.onNodeWithTag("specialty-input").performTextInput(text)
            ui.onNode(hasText("Add") and hasAnyAncestor(isDialog())).performClick()
        }
        sheet(hasContentDescription("Add Brawl specialty")).assertIsNotEnabled()
        jump("Merits"); entryRating("Covenant Status (Circle of the Crone)", 0)
        jump("Character Creation"); sheet(hasTestTag("finish-creation")).assertIsNotEnabled()
        sheet(hasText("Crúac needs Circle of the Crone Status")).assertExists()
        sheet(hasText("Leave Guided Creation")).performClick()
        ui.onNodeWithText("Cancel").performClick()
        sheet(hasText("Leave Guided Creation")).performClick()
        ui.onNode(hasText("Leave Guided Creation") and hasAnyAncestor(isDialog())).performClick()
        ui.onNodeWithContentDescription("XP Mode").assert(hasStateDescription("Off"))
        reopen(name)
        jump("Attributes"); sheet(hasContentDescription("Dexterity")).assert(hasStateDescription("2 base, 0 bonus"))
        jump("Disciplines"); sheet(hasContentDescription("Crúac")).assertExists()
        jump("Experience"); sheet(hasContentDescription("0 XP available")).assertExists()
    }

    @Test fun aCompleteSavedCharacterFinishesWithoutTheUnfinishedReminder() {
        ui.onNodeWithTag("dark-pack-splash").performClick(); library()
        val catalog = Catalog.bundled()
        val initial = CharacterSave()
        val c = initial.copy(name = "Ready " + UUID.randomUUID().toString().take(8), concept = "Night archivist", mask = "Authoritarian", dirge = "Conspirator",
            clan = TraitSource(catalog = "ventrue"), bloodPotency = 2,
            creation = CreationState(favoredAttribute = "presence", attributePriorities = mapOf("mental" to 1, "physical" to 2, "social" to 0),
                skillPriorities = mapOf("mental" to 0, "physical" to 1, "social" to 2)),
            attributes = initial.attributes.map { it.copy(rating = mapOf("intelligence" to 2, "wits" to 4, "strength" to 3, "dexterity" to 2, "presence" to 5, "manipulation" to 3)[it.attribute] ?: 1) },
            skills = initial.skills.map { it.copy(rating = mapOf("academics" to 5, "occult" to 5, "politics" to 1, "athletics" to 4, "brawl" to 3, "persuasion" to 4)[it.skill] ?: 0,
                specialties = if (it.skill in listOf("academics", "occult", "brawl")) listOf("Specialty") else emptyList()) },
            disciplines = listOf(Discipline(TraitSource(catalog = "dominate"), 2), Discipline(TraitSource(catalog = "cruac"), 1)),
            merits = listOf(Merit(TraitSource(catalog = "resources"), rating = 4), Merit(TraitSource(catalog = "covenant-status"), "Circle of the Crone", 1)),
            aspirations = listOf(Aspiration("Find the folio"), Aspiration("Protect the coterie"), Aspiration("Reconnect with family")),
            touchstones = initial.touchstones.map { if (it.level == 7) it.copy(text = "The family estate") else it })
        assertTrue(c.creationSteps(catalog).all { it.status == CreationStepStatus.Done })
        val directory = File(InstrumentationRegistry.getInstrumentation().targetContext.filesDir, "Characters").apply { mkdirs() }
        File(directory, "${c.id}.json").writeText(CharacterCodec(catalog).encode(c))
        // Closing a new sheet refreshes the library, just as after an ordinary save.
        ui.onNodeWithTag("character-library").performScrollToNode(hasText("New blank sheet"))
        ui.onNodeWithText("New blank sheet").performClick(); enter()
        ui.onNodeWithContentDescription("Back").performClick(); library()
        ui.onNodeWithTag("character-library").performScrollToNode(hasText(c.name)); ui.onNodeWithText(c.name).performClick(); enter()
        sheet(hasText("7 of 7 steps done")).assertExists()
        sheet(hasTestTag("finish-creation")).performClick()
        ui.onNodeWithText("Some steps aren't done").assertDoesNotExist()
        ui.onNodeWithTag("creation-ranks").performScrollToNode(hasTestTag("creation-rank-25"))
        ui.onNodeWithTag("creation-rank-25").performClick()
        ui.onNodeWithTag("confirm-finish-creation").performClick(); xp(25)
        reopen(c.name); xp(25)
    }
}
