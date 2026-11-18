package ie.forsaken.sheet

import androidx.test.platform.app.InstrumentationRegistry
import ie.forsaken.rules.ForsakenSection
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class HeadingResourcesTest {
    @Test fun everyOriginalOutlineSurvivesPackagingAndParsesIncludingLongPaths() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val resources = instrumentation.targetContext.resources
        val headings = readHeadingArt(resources)
        assertEquals(ForsakenSection.entries.map { it.title }.toSet(), headings.keys)
        assertTrue(headings.values.all { it.vector != null && it.vector.root.size > 0 })
        val manifest = resources.openRawResource(R.raw.headings).bufferedReader().use {
            Json.parseToJsonElement(it.readText()).jsonObject.getValue("headings").jsonArray
        }
        manifest.forEach { item ->
            val name = item.jsonObject.getValue("drawable").jsonPrimitive.content
            val original = instrumentation.context.assets.open("$name.xml").use { it.readBytes() }
            @Suppress("DiscouragedApi")
            val packaged = resources.getIdentifier(name, "raw", instrumentation.targetContext.packageName)
            assertArrayEquals(name, original, resources.openRawResource(packaged).use { it.readBytes() })
        }
        assertTrue(instrumentation.context.assets.open("heading_character_creation.xml").use { it.readBytes().size } > 32767)
    }
}
