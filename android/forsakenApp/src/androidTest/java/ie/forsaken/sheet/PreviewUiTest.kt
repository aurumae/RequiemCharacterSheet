package ie.forsaken.sheet

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.semantics.SemanticsActions
import androidx.core.content.FileProvider
import androidx.lifecycle.ViewModelProvider
import androidx.test.platform.app.InstrumentationRegistry
import ie.forsaken.rules.*
import ie.chronicles.core.*
import kotlinx.serialization.json.*
import org.junit.*
import org.junit.Assert.*
import java.io.File
import java.util.UUID
import java.util.concurrent.atomic.AtomicReference

class PreviewUiTest {
    @get:Rule val ui = createAndroidComposeRule<MainActivity>()
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext
    private fun stored(id: UUID) = File(context.filesDir, "characters/$id.json")
    private fun ready(tag: String) = ui.waitUntil(10_000) { ui.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }
    private fun library() {
        if (ui.onAllNodesWithTag("dark-pack-splash").fetchSemanticsNodes().isNotEmpty()) ui.onNodeWithTag("dark-pack-splash").performClick()
        ready("character-library")
    }
    @Before fun resetPreviewLibrary() {
        ui.activity.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        library()
        File(context.filesDir, "characters").deleteRecursively()
        ui.runOnIdle { ViewModelProvider(ui.activity)[PreviewModel::class.java].refresh() }
        ready("character-library")
    }
    private fun fixture(name: String = "play") = instrumentation.context.assets.open("forsaken-v1-$name.json").use { it.readBytes() }
    private fun uri(bytes: ByteArray): Uri {
        val file = File(context.cacheDir, "character-exports/test-${UUID.randomUUID()}/input.wtfcharacter")
        file.parentFile!!.mkdirs(); file.writeBytes(bytes)
        return FileProvider.getUriForFile(context, "${context.packageName}.characterfiles", file)
    }
    private fun receive(bytes: ByteArray, view: Boolean = false) {
        val source = uri(bytes)
        context.startActivity(Intent(context, MainActivity::class.java).apply {
            action = if (view) Intent.ACTION_VIEW else Intent.ACTION_SEND
            if (view) setDataAndType(source, "application/octet-stream") else { type = "application/json"; putExtra(Intent.EXTRA_STREAM, source) }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        })
    }
    private fun back() { ui.onNodeWithContentDescription("Back").performClick(); ready("character-library") }
    private fun libraryClick(text: String) {
        ui.onNodeWithTag("character-library").performScrollToNode(hasText(text)); ui.onNodeWithText(text).performClick()
    }

    private fun section(title: String) {
        ui.onNodeWithTag("section-pill").performClick()
        ui.onNode(hasText(title) and hasAnyAncestor(isPopup())).performScrollTo().performClick()
    }
    private fun state(): ForsakenState = ui.runOnIdle { ViewModelProvider(ui.activity)[PreviewModel::class.java].ui.value.character!!.state }

    @Test fun blankSheetEditsAndDraftSurviveRecreationAndRestart() {
        libraryClick("New blank sheet"); ready("character-sheet")
        ui.onNodeWithContentDescription("Character Name").performTextReplacement("Android wolf")
        ui.onNodeWithContentDescription("Character Name").performImeAction()
        section("Aspirations")
        ui.onNodeWithText("Add Aspiration").performClick()
        ui.onNodeWithTag("play-input-0").performTextInput("Keep the pack together")
        ui.activityRule.scenario.recreate(); ready("play-input-0")
        ui.onNodeWithTag("play-input-0").assertTextContains("Keep the pack together")
        ui.onNode(hasText("Save") and hasAnyAncestor(isDialog())).performClick()
        val id=state().id
        back(); libraryClick("Android wolf"); ready("character-sheet")
        assertEquals("Android wolf",state().name)
        assertEquals(1,state().aspirations.count { it.text=="Keep the pack together" })
        assertTrue(state().changeLog.isEmpty())
        back()
        assertEquals("Android wolf",forsakenStore(File(context.filesDir,"characters")).open(id).saved.name)
    }

    @Test fun renownPurchaseFreeFacetAndRefundSurviveRecreationExactlyOnce() {
        receive(fixture()); ready("character-sheet")
        val original=state(); val originalLog=original.changeLog.size
        section("Renown")
        ui.onNodeWithContentDescription("Cunning").performSemanticsAction(SemanticsActions.SetProgress) { it(2f) }
        assertEquals(3,state().changeLog.last().experiences)
        assertEquals(1,state().renownFacetCredits["cunning"])
        ui.onNodeWithText("Cunning: a free Facet to learn").performClick()
        ui.onNodeWithTag("play-picker-search").performTextInput("Unchained")
        ui.onNodeWithTag("play-picker-options").performScrollToNode(hasText("Unchained"))
        ui.onNode(hasText("Unchained") and hasAnyAncestor(hasTestTag("play-picker-options"))).performClick()
        assertTrue(state().facets.single { it.source.catalog=="strength-unchained" }.withRenown)
        assertEquals(0,state().changeLog.last().experiences)
        ui.activityRule.scenario.recreate(); ready("character-sheet")
        assertEquals(originalLog+2,state().changeLog.size)
        section("Shadow Gifts")
        ui.onNodeWithTag("character-sheet").performScrollToNode(hasContentDescription("Options for Unchained"))
        ui.onNodeWithContentDescription("Options for Unchained").performClick()
        ui.onNodeWithText("Delete").performClick()
        ui.onNode(hasText("Delete") and hasAnyAncestor(isDialog())).performClick()
        assertEquals(1,state().renownFacetCredits["cunning"])
        section("Renown")
        ui.onNodeWithContentDescription("Cunning").performSemanticsAction(SemanticsActions.SetProgress) { it(1f) }
        assertEquals(-3,state().changeLog.last().experiences)
        section("Form")
        ui.onNodeWithText("Choose Form").performClick(); ui.onNodeWithText("Gauru").performClick()
        assertEquals(10,ForsakenRules(state()).attribute("strength"))
        back(); libraryClick("Mara Voss"); ready("character-sheet")
        assertEquals(originalLog+4,state().changeLog.size)
        assertEquals(10,ForsakenRules(state()).experiencesSpent)
        assertEquals(Form.gauru,state().form)
        section("Attributes")
        ui.onNodeWithTag("character-sheet").performScrollToNode(hasContentDescription("Strength"))
        ui.onNodeWithContentDescription("Strength").assertIsDisplayed()
    }

    @Test fun totemGrantAndConditionResolutionUseTheSameStoredSheet() {
        libraryClick("New blank sheet"); ready("character-sheet")
        section("Totem")
        ui.onNodeWithTag("character-sheet").performScrollToNode(hasText("Add Advantage"))
        ui.onNodeWithText("Add Advantage").performClick()
        ui.onNodeWithText("Merit").performClick()
        ui.onNodeWithTag("play-picker-search").performTextInput("Fast Reflexes")
        ui.onNode(hasText("Fast Reflexes") and hasAnyAncestor(hasTestTag("play-picker-options"))).performClick()
        assertEquals(0,state().merits.single().rating)
        assertEquals(1,state().totem.experiencesSpent)
        assertEquals(3,ForsakenRules(state()).initiative())
        assertTrue(state().changeLog.isEmpty())
        section("Conditions")
        ui.onNodeWithText("Add Condition").performClick()
        ui.onNodeWithTag("play-picker-search").performTextInput("Siskur")
        ui.onNode(hasText("Siskur-Dah") and hasAnyAncestor(hasTestTag("play-picker-options"))).performClick()
        val sheet=ui.onNodeWithTag("character-sheet")
        sheet.performScrollToNode(hasText("Choose Ritemaster"))
        ui.onNodeWithText("Choose Ritemaster").performClick()
        ui.onNodeWithText("Blood Talons").performClick()
        assertEquals("Blood Talons",state().conditions.single().note)
        sheet.performScrollToNode(hasText("Resolve Siskur-Dah"))
        ui.onNodeWithText("Resolve Siskur-Dah").performClick()
        ui.onNode(hasText("Resolve") and hasAnyAncestor(isDialog())).performClick()
        assertTrue(state().conditions.isEmpty()); assertEquals(1,state().beats)
        assertEquals(listOf(ConditionEvent.added,ConditionEvent.resolved),state().changeLog.map { it.event })
        back(); libraryClick("Unnamed Character"); ready("character-sheet")
        assertEquals(1,state().beats)
        assertEquals(0,state().merits.single().rating)
    }

    @Test fun openingOrdinaryPlayDoesNotRewriteAcrossRecreationAndCatalogSearch() {
        ui.onNodeWithTag("character-library").performScrollToNode(hasText("New blank sheet"))
        ui.onNodeWithText("New blank sheet").assertIsDisplayed()
        ui.onNodeWithText("Guided character creation").assertDoesNotExist()
        val bytes = fixture()
        val c = ForsakenPreviewCodec().decode(bytes.decodeToString())
        receive(bytes)
        ready("character-sheet")
        ui.onNodeWithText("Save").assertIsDisplayed()
        val sheet = ui.onNodeWithTag("character-sheet")
        sheet.performScrollToNode(hasText("Mara Voss")); ui.onNodeWithText("Mara Voss").assertIsDisplayed()
        ui.activityRule.scenario.recreate()
        ready("character-sheet")
        sheet.performScrollToNode(hasText("Browse catalog")); ui.onNodeWithText("Browse catalog").performClick()
        ui.onNodeWithTag("forsaken-catalog-search").performTextInput("Primal Strength")
        ui.onNodeWithTag("forsaken-catalog-options").performScrollToNode(hasText("Gift of Strength"))
        ui.onNodeWithText("Gift of Strength").performClick()
        ui.onNodeWithTag("catalog-details").performScrollToNode(hasText("Primal Strength"))
        ui.onNode(hasText("Primal Strength") and hasAnyAncestor(hasTestTag("catalog-details"))).assertIsDisplayed()
        ui.onNodeWithText("Done").performClick()
        back()
        assertArrayEquals(bytes, stored(c.id).readBytes())
        libraryClick("Mara Voss")
        ready("character-sheet")
        assertArrayEquals(bytes, stored(c.id).readBytes())
    }

    @Test fun creationGrantChoicesAndLongHeadingRemainIntactAfterOpening() {
        val bytes = fixture("creation")
        val c = ForsakenPreviewCodec().decode(bytes.decodeToString())
        receive(bytes, view = true)
        ready("character-sheet")
        ui.onNodeWithContentDescription("Character Creation").assertIsDisplayed()
        ui.onNodeWithText("Save file").assertIsDisplayed()
        ui.onAllNodes(hasSetTextAction()).assertCountEquals(0)
        ui.onNodeWithTag("character-sheet").performScrollToNode(hasText("Survival"))
        ui.onNodeWithText("Survival").assertIsDisplayed()
        ui.onNodeWithTag("section-pill").performClick()
        ui.onNode(hasText("Conditions") and hasAnyAncestor(isPopup())).performScrollTo().performClick()
        ui.onNodeWithContentDescription("Conditions").assertIsDisplayed()
        ui.onNodeWithTag("section-pill").performClick()
        ui.onNode(hasText("Conditions") and hasAnyAncestor(isPopup())).assertIsDisplayed().assertIsSelected()
        ui.onNode(hasText("Character Creation") and hasAnyAncestor(isPopup())).performScrollTo().performClick()
        ui.onNodeWithContentDescription("Character Creation").assertIsDisplayed()
        back()
        assertArrayEquals(bytes, stored(c.id).readBytes())
    }

    @Test fun pickerSaveAndShareUseForsakenAuthorityAndExactOriginalBytes() {
        val bytes = fixture()
        val captured = AtomicReference<Intent>()
        var result = Instrumentation.ActivityResult(Activity.RESULT_OK, Intent().setData(uri(bytes)))
        val monitor = object : Instrumentation.ActivityMonitor() {
            override fun onStartActivity(intent: Intent): Instrumentation.ActivityResult? {
                if (intent.action !in listOf(Intent.ACTION_OPEN_DOCUMENT, Intent.ACTION_CREATE_DOCUMENT, Intent.ACTION_CHOOSER)) return null
                captured.set(intent); return result
            }
        }
        instrumentation.addMonitor(monitor)
        try {
            libraryClick("Import Character")
            ready("character-sheet")
            assertEquals(Intent.ACTION_OPEN_DOCUMENT, captured.get().action)
            val destination = uri(byteArrayOf())
            result = Instrumentation.ActivityResult(Activity.RESULT_OK, Intent().setData(destination))
            captured.set(null)
            back()
            ui.onNodeWithContentDescription("Options for Mara Voss").performClick()
            ui.onNodeWithText("Save to file").performClick()
            ui.waitUntil(5000) { captured.get()?.action == Intent.ACTION_CREATE_DOCUMENT }
            assertEquals("Mara Voss.wtfcharacter", captured.get().getStringExtra(Intent.EXTRA_TITLE))
            assertEquals("application/octet-stream", captured.get().type)
            ui.waitUntil(5000) { context.contentResolver.openInputStream(destination)!!.use { it.readBytes() }.contentEquals(bytes) }
            result = Instrumentation.ActivityResult(Activity.RESULT_CANCELED, null)
            captured.set(null)
            ui.onNodeWithContentDescription("Options for Mara Voss").performClick()
            ui.onNodeWithText("Export").performClick()
            ui.waitUntil(5000) { captured.get()?.action == Intent.ACTION_CHOOSER }
            val send = captured.get().getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)!!
            val shared = send.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)!!
            assertEquals("com.omccolgan.ForsakenCharacterSheet.characterfiles", shared.authority)
            assertTrue(send.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
            assertEquals(0, send.flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            assertArrayEquals(bytes, context.contentResolver.openInputStream(shared)!!.use { it.readBytes() })
            context.contentResolver.query(shared, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)!!.use {
                assertTrue(it.moveToFirst()); assertEquals("Mara Voss.wtfcharacter", it.getString(0))
            }
        } finally { instrumentation.removeMonitor(monitor) }
    }

    @Test fun pendingKeepBothSurvivesRecreationAndDoesNotChangeTheOriginal() {
        val bytes = fixture()
        val c = ForsakenPreviewCodec().decode(bytes.decodeToString())
        receive(bytes); ready("character-sheet"); back()
        val incoming = JsonObject(Json.parseToJsonElement(bytes.decodeToString()).jsonObject.toMutableMap().apply {
            put("name", JsonPrimitive("Mara incoming"))
        }).toString().toByteArray()
        receive(incoming)
        fun conflict() = ui.waitUntil(10_000) { ui.onAllNodesWithText("Keep Both").fetchSemanticsNodes().isNotEmpty() }
        conflict()
        ui.activityRule.scenario.recreate(); conflict()
        ui.onNodeWithText("Keep Both").performClick(); ready("character-sheet")
        ui.onNodeWithTag("character-sheet").performScrollToNode(hasText("Mara incoming (1)"))
        ui.onNodeWithText("Mara incoming (1)").assertIsDisplayed()
        assertArrayEquals(bytes, stored(c.id).readBytes())
        assertEquals(2, forsakenStore(File(context.filesDir, "characters")).library().size)
    }

    @Test fun otherGamesAndFutureOrDamagedFilesAreRefusedByTheActivity() {
        val before = File(context.filesDir, "characters").listFiles()?.map { it.name }?.toSet().orEmpty()
        for ((text, message) in listOf(
            """{"game":"requiem","name":"Vampire","schemaVersion":12}""" to "This character is from another game. Open it in that game's app.",
            """{"name":"Legacy vampire","schemaVersion":1}""" to "This character is from another game. Open it in that game's app.",
            """{"game":"forsaken","name":"Future","schemaVersion":2}""" to "This character was saved by a newer version of the app. Update the app to open it.",
            """{"game":"forsaken","name":99}""" to "The file isn't a character file, or it's damaged.",
        )) {
            receive(text.toByteArray())
            ui.waitUntil(10_000) { ui.onAllNodesWithText(message).fetchSemanticsNodes().isNotEmpty() }
            ui.onNodeWithText("OK").performClick(); ready("character-library")
            assertEquals(before, File(context.filesDir, "characters").listFiles()?.map { it.name }?.toSet().orEmpty())
        }
    }
}
