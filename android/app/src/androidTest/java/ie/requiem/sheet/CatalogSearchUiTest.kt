package ie.requiem.sheet

import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import ie.requiem.rules.Catalog
import ie.requiem.rules.CharacterSave
import org.junit.Rule
import org.junit.Test

class CatalogSearchUiTest {
    @get:Rule val ui = createComposeRule()

    @Test fun quotedAccentedTextFindsEntriesInAllThreePickers() {
        val catalog = Catalog(mapOf("sample.json" to """{
            "format":"requiem-catalog", "version":1, "book":{"id":"sample","name":"Test Book"},
            "clans":[{"id":"clan","name":"Éire’s “Court”","source":{"book":"sample"}}],
            "conditions":[{"id":"condition","name":"Éire’s “Court”","source":{"book":"sample"}}],
            "merits":[{"id":"merit","name":"Éire’s “Court”","source":{"book":"sample"}}]
        }"""))
        val character = CharacterSave()
        var route by mutableStateOf<String?>("identityPick|Clan")
        ui.setContent { SheetTheme { SheetDialogs(route, character, catalog, {}, { route = it }) } }
        for ((picker, tag) in listOf("identityPick|Clan" to "identity-search",
            "conditionPick" to "condition-search", "pick|Merit" to "catalog-search")) {
            ui.runOnIdle { route = picker }
            val field = ui.onNodeWithTag(tag)
            field.performTextReplacement("absent")
            ui.onNodeWithText("Éire’s “Court”").assertDoesNotExist()
            field.performTextReplacement("eire's \"court\"")
            field.performImeAction()
            ui.onNodeWithText("Éire’s “Court”").assertExists()
        }
    }
}
