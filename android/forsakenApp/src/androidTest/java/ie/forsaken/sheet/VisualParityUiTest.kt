package ie.forsaken.sheet

import android.content.pm.ActivityInfo
import android.graphics.Bitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import ie.forsaken.rules.*
import ie.chronicles.core.*
import java.io.File
import java.util.UUID
import org.junit.*
import org.junit.rules.ExternalResource
import org.junit.rules.RuleChain

/** Synthetic visual examples derived from, without changing, the immutable iOS fixture. */
class VisualParityUiTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext
    private val ui = createAndroidComposeRule<MainActivity>()
    private val id = UUID.randomUUID()
    private val exampleName = "Mara — visual ${id.toString().take(4)}"
    private val profile get() = InstrumentationRegistry.getArguments().getString("visualProfile") ?: "normal"
    private val seed = object : ExternalResource() {
        override fun before() {
            val codec = ForsakenCodec()
            val source = instrumentation.context.assets.open("forsaken-v1-play.json").bufferedReader().use { codec.decode(it.readText()) }
            val c = codec.character(source.state.copy(id=id, name=exampleName, moonGift=null, moonFacets=emptyList(),
                extraMoonGifts=emptyList(), renownFacetCredits=emptyMap()))
            val store=forsakenStore(File(context.filesDir,"characters"))
            store.importCharacter(store.prepareImport(codec.encode(c).toByteArray()))
        }
        override fun after() { forsakenStore(File(context.filesDir,"characters")).delete(id) }
    }
    @get:Rule val rules: RuleChain = RuleChain.outerRule(seed).around(ui)
    private fun ready(tag: String) = ui.waitUntil(10_000) { ui.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }
    private fun capture(name: String) {
        ui.waitForIdle()
        // Compose idleness does not wait for the system IME/window surface animation.
        android.os.SystemClock.sleep(300)
        val directory=File(context.getExternalFilesDir(null),"visual-parity/$profile").apply { mkdirs() }
        val bitmap=requireNotNull(instrumentation.uiAutomation.takeScreenshot())
        File(directory,"$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG,100,it) }
        bitmap.recycle()
    }
    private fun section(title: String) {
        ui.onNodeWithTag("section-pill").performClick()
        ui.onNode(hasText(title) and hasAnyAncestor(isPopup())).performScrollTo().performClick()
        ui.onAllNodesWithContentDescription(title).onFirst().assertExists()
    }
    @Test fun referenceScreensKeepNavigationSelectionAndKeyboardEditingUsable() {
        ui.activity.requestedOrientation=if(profile=="landscape") ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE else ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        if(ui.onAllNodesWithTag("dark-pack-splash").fetchSemanticsNodes().isNotEmpty()) ui.onNodeWithTag("dark-pack-splash").performClick()
        ready("character-library")
        ui.onNodeWithTag("character-library").performScrollToNode(hasText(exampleName))
        capture("00-library")
        ui.onNodeWithText(exampleName).performClick(); ready("character-sheet")
        capture("01-character")
        for((title,file) in listOf("Attributes" to "02-attributes","Skills" to "03-skills","Merits" to "04-merits",
            "Form" to "05-form","Advantages" to "06-advantages","Renown" to "07-renown","Moon Gifts" to "08-moon",
            "Shadow Gifts" to "09-shadow","Wolf Gifts" to "10-wolf","Rites" to "11-rites","Primal Urge" to "12-primal-urge",
            "Harmony" to "13-harmony","Kuruth Triggers" to "14-kuruth","Lodge" to "15-lodge","Totem" to "16-totem","Experience" to "17-experience")) {
            section(title); capture(file)
        }
        section("Conditions"); capture("18-conditions")
        ui.onNodeWithTag("condition-carousel").performTouchInput { swipeLeft() }
        ui.onNodeWithTag("condition-position").assertTextEquals("2 of 2")
        ui.onNodeWithTag("condition-card-00000000-0000-4000-8000-000000000302").performClick()
        ready("condition-full-card"); capture("19-condition-full")
        ui.onNodeWithText("Done").performClick()
        section("Shadow Gifts")
        ui.onNodeWithTag("character-sheet").performScrollToNode(hasText("Add Shadow Facet"))
        ui.onNodeWithText("Add Shadow Facet").performClick(); capture("20-facet-picker")
        ui.onNodeWithTag("play-picker-search").performTextInput("Unchained")
        ui.onNodeWithTag("play-picker-options").performScrollToNode(hasText("Unchained"))
        ui.onNode(hasText("Unchained") and hasAnyAncestor(hasTestTag("play-picker-options"))).assertIsDisplayed()
        capture("21-picker-keyboard")
        ui.onNodeWithText("Cancel").performClick()
        section("Character")
        ui.onNodeWithContentDescription("Character Name").performClick().performTextReplacement("Mara — keyboard example")
        ui.onNodeWithContentDescription("Character Name").assertIsDisplayed()
        capture("22-field-keyboard")
        ui.onNodeWithContentDescription("Character Name").performImeAction()
    }
}
