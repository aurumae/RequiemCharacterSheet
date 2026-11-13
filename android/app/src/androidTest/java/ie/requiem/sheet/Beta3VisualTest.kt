package ie.requiem.sheet

import android.graphics.Bitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import ie.requiem.rules.*
import java.io.File
import java.util.UUID
import org.junit.Rule
import org.junit.Test
import org.junit.rules.ExternalResource
import org.junit.rules.RuleChain

/** Repeat with normal/large font and landscape; images are local test artifacts. */
class Beta3VisualTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext
    private val catalog = Catalog.bundled()
    private val ids = listOf(UUID.randomUUID(), UUID.randomUUID())
    private val ui = createAndroidComposeRule<MainActivity>()
    private val seed = object : ExternalResource() {
        override fun before() {
            val codec = CharacterCodec(catalog)
            val fixture = instrumentation.context.assets.open("characters/v12-elder-bane.json").bufferedReader().use { it.readText() }
            val base = codec.decode(fixture)
            val now = CharacterSave().createdAt
            val c = base.copy(id = ids[0], name = "Lucius Avelorn", clan = TraitSource(catalog = "ventrue"), bloodline = TraitSource(catalog = "bron"),
                covenant = TraitSource(catalog = "lancea-et-sanctum"), humanity = 7, elderBaneActive = false, xpMode = false,
                createdAt = now, modifiedAt = now, player = "Oisín", chronicle = "Dublin by Night",
                disciplines = listOf("animalism", "dominate", "resilience").map { Discipline(TraitSource(catalog = it), rating = 2) },
                conditions = listOf(CharacterCondition(TraitSource(catalog = "swooning"), note = "Cordelia"), CharacterCondition(TraitSource(catalog = "tempted"), counter = 2)))
            val store = CharacterFiles(File(context.filesDir, "Characters"), catalog)
            store.importCharacter(store.prepareImport(codec.encode(c).toByteArray()))
            store.importCharacter(store.prepareImport(codec.encode(c.copy(id = ids[1], name = "Cordelia", clan = TraitSource(catalog = "daeva"),
                bloodline = TraitSource(custom = ""), modifiedAt = now - 90)).toByteArray()))
        }
        override fun after() {
            val store = CharacterFiles(File(context.filesDir, "Characters"), catalog)
            ids.forEach { runCatching { store.delete(it) } }
        }
    }
    @get:Rule val rules: RuleChain = RuleChain.outerRule(seed).around(ui)
    private fun capture(name: String) {
        ui.waitForIdle()
        val profile = InstrumentationRegistry.getArguments().getString("visualProfile") ?: "normal"
        val directory = File(context.getExternalFilesDir(null), "parity/$profile").apply { mkdirs() }
        val bitmap = requireNotNull(instrumentation.uiAutomation.takeScreenshot())
        File(directory, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }
    private fun jump(name: String) {
        ui.onNodeWithTag("section-pill").performClick()
        ui.onNode(hasText(name) and hasAnyAncestor(isPopup())).performScrollTo().performClick()
    }
    private fun sheet(text: String): SemanticsNodeInteraction {
        ui.onNodeWithTag("character-sheet").performScrollToNode(hasText(text))
        return ui.onNodeWithText(text)
    }
    @Test fun captureReferenceScreensAndVerifyNavigation() {
        ui.onNodeWithTag("dark-pack-splash").performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-library").fetchSemanticsNodes().isNotEmpty() }
        ui.onNodeWithTag("character-library").performScrollToNode(hasText("Lucius Avelorn"))
        ui.onAllNodesWithText("Ventrue (Bron) · Lancea et Sanctum").onFirst().assertExists()
        capture("01-characters")
        ui.onNodeWithText("Lucius Avelorn").performClick()
        ui.waitUntil(8_000) { ui.onAllNodesWithTag("character-sheet").fetchSemanticsNodes().isNotEmpty() }
        capture("02-sheet")
        ui.onNodeWithTag("section-pill").performClick(); capture("03-section-pill")
        ui.onNode(hasText("Skills") and hasAnyAncestor(isPopup())).performScrollTo().performClick(); capture("04-skills")
        jump("Disciplines"); capture("05-disciplines-merits")
        sheet("Add Discipline").performClick(); capture("06-discipline-picker")
        ui.onNodeWithText("Cancel").performClick()
        jump("Merits"); sheet("Add Merit").performClick(); capture("07-merit-picker")
        ui.onNodeWithText("Cancel").performClick()
        jump("Conditions"); capture("08-conditions")
        ui.onNode(hasText("SWOONING") and hasClickAction()).performClick(); capture("09-condition-card")
        ui.onNodeWithText("Done").performClick()
        jump("Experience"); sheet("Change Log").performClick(); capture("10-change-log")
    }
}
