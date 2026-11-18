package ie.forsaken.rules

import ie.chronicles.core.*
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.io.File

class ForsakenCatalogTest {
    private val catalog = ForsakenCatalog.bundled

    @Test fun allAuthoritativeCatalogSourcesAreBundledInSwiftOrder() {
        val names = File(System.getProperty("forsakenCatalogDir")).listFiles()!!.filter { it.extension == "json" }.map { it.name }.toSet() + "cofd-core.json"
        assertEquals(names, catalog.sourceFiles.toSet())
        assertEquals(listOf("wtf2e-core.json", "cofd-core.json"), catalog.sourceFiles.take(2))
        assertTrue(catalog.sourceFiles.indexOf("dark-eras.json") < catalog.sourceFiles.indexOf("dark-eras-2.json"))
        assertEquals(listOf("giver-of-gifts-1.json", "giver-of-gifts-2.json"), catalog.sourceFiles.takeLast(2))
        assertTrue(CatalogKind.entries.all { catalog.all(it).isNotEmpty() })
        assertEquals(5, catalog.all(CatalogKind.auspices).size)
        assertEquals("pure", catalog.entry(CatalogKind.tribes, "predator-kings")!!.text("kind"))
        assertEquals("glory", catalog.entry(CatalogKind.tribes, "predator-kings")!!.text("renown"))
        assertEquals("cofd-core", catalog.entry(CatalogKind.merits, "fast-reflexes")!!.source.book)
    }

    @Test fun unofficialVisibilityDoesNotHideOwnedDetailsAndUrlCitationsRemainUrls() {
        val all = catalog.all(CatalogKind.gifts)
        val unofficial = all.first { catalog.books[it.source.book]?.official == false }
        assertFalse(unofficial in catalog.visible(CatalogKind.gifts, false))
        assertTrue(unofficial in catalog.visible(CatalogKind.gifts, true))
        assertEquals(unofficial, catalog.entry(CatalogKind.gifts, unofficial.id))
        assertEquals(catalog.books.getValue(unofficial.source.book).url, catalog.citation(unofficial))
        val hunt = catalog.entry(CatalogKind.conditions, "siskur-dah")!!
        assertTrue(hunt.noteOptions.any { it.group == "lodge" })
        assertTrue(catalogDetails(hunt, catalog).any { it.text == hunt.noteOptions.last().summary })
    }

    @Test fun sharedCatalogOnlyContributesMeritsAndConditionsAndFirstEntryWins() {
        fun file(format: String, book: String, label: String) = """{"format":"$format","version":1,"book":{"id":"$book","name":"$book"},"tribes":[{"id":"example","name":"$label","summary":"Tribe","source":{"book":"$book"}}],"merits":[{"id":"same","name":"$label","summary":"Merit","source":{"book":"$book"}}]}"""
        val c = ForsakenCatalog.fromFiles(mapOf("wtf2e-core.json" to file("forsaken-catalog", "core", "First"),
            "cofd-core.json" to file("requiem-catalog", "cofd", "Second")))
        assertEquals("First", c.entry(CatalogKind.merits, "same")!!.name)
        val sharedOnly = ForsakenCatalog.fromFiles(mapOf("cofd-core.json" to file("requiem-catalog", "cofd", "Second")))
        assertTrue(sharedOnly.all(CatalogKind.tribes).isEmpty())
        assertEquals(1, sharedOnly.all(CatalogKind.merits).size)
    }

    @Test fun unknownEffectsRemainReadableAdvisoryTextAndNestedFacetDataIsRetained() {
        val file = """{"format":"forsaken-catalog","version":1,"book":{"id":"example","name":"Example"},"gifts":[{"id":"test","name":"Hunter’s Gift","kind":"shadow","summary":"Keep this description","source":{"book":"example","page":12},"facets":[{"id":"facet","name":"Hunt","summary":"Tell the Storyteller to add the bonus.","source":{"book":"example","page":13},"effects":[{"type":"future-rule","amount":99}],"effectForms":["dalu"],"passive":true}]}]}"""
        val c = ForsakenCatalog.fromFiles(mapOf("example.json" to file))
        val gift = c.entry(CatalogKind.gifts, "test")!!
        val facet = c.facet("facet")!!.facet
        assertEquals("future-rule", facet.array("effects").single().jsonObject.getValue("type").jsonPrimitive.content)
        assertTrue(CatalogSearch("Hunter's").matches(gift.name))
        val details = catalogDetails(gift, c)
        assertTrue(details.any { it.text.contains(facet.summary) && it.text.contains("Example, p. 13") })
        assertFalse(details.any { it.text.contains("99") })
    }

    @Test fun everySheetSectionHasAnOriginalHeadingOutline() {
        val root = File(System.getProperty("headingsDir"))
        val headings = Json.parseToJsonElement(root.resolve("headings.json").readText()).jsonObject.getValue("headings").jsonArray
        assertEquals(ForsakenSection.entries.map { it.title }.toSet(), headings.map { it.jsonObject.getValue("heading").jsonPrimitive.content }.toSet())
        headings.forEach { value ->
            val file = root.resolve(value.jsonObject.getValue("drawable").jsonPrimitive.content + ".xml")
            assertTrue(file.isFile)
            assertTrue(file.readText().contains("android:pathData="))
        }
    }
}
