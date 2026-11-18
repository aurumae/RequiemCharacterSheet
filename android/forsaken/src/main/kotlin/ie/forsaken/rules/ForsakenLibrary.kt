package ie.forsaken.rules

import ie.chronicles.core.*
import java.io.File

const val FORSAKEN_FILE_EXTENSION = "wtfcharacter"

fun forsakenPreviewStore(directory: File, catalog: ForsakenCatalog = ForsakenCatalog.bundled) = CharacterStore(
    directory, ForsakenPreviewCodec(catalog), FORSAKEN_FILE_EXTENSION,
    blank = { _: Boolean -> error("Create characters in the iOS app until Android editing is available.") },
    summarize = { c ->
        LibraryRow(c.id, c.name, c.modifiedAt, c.state.creation != null,
            details = listOf(catalog.name(CatalogKind.auspices, c.state.auspice), catalog.name(CatalogKind.tribes, c.state.tribe))
                .filter(String::isNotBlank).joinToString(" · "))
    },
)

enum class ForsakenSection(val title: String) {
    Creation("Character Creation"), Character("Character"), Form("Form"), Advantages("Advantages"),
    Attributes("Attributes"), Skills("Skills"), Merits("Merits"), Totem("Totem"), Renown("Renown"),
    AuspiceBenefit("Auspice Benefit"), Lodge("Lodge"), MoonGifts("Moon Gifts"), ShadowGifts("Shadow Gifts"),
    WolfGifts("Wolf Gifts"), Rites("Rites"), Fetishes("Fetishes"), Aspirations("Aspirations"), Health("Health"),
    Willpower("Willpower"), PrimalUrge("Primal Urge"), Harmony("Harmony"), Kuruth("Kuruth Triggers"),
    Experience("Experience"), Conditions("Conditions");

    companion object {
        fun available(c: ForsakenState, catalog: ForsakenCatalog): List<ForsakenSection> {
            val pure = catalog.entry(CatalogKind.tribes, c.tribe.catalog)?.text("kind") == "pure"
            val benefit = catalog.entry(CatalogKind.auspices, c.auspice.catalog)?.objectValue("benefit")
            val lodge = catalog.entry(CatalogKind.lodges, c.lodge.catalog)
            return entries.filter {
                when (it) {
                    Creation -> c.creation != null
                    AuspiceBenefit -> !pure && benefit != null
                    Lodge -> lodge != null && listOf("benefit", "blessing", "aspiration", "ban").any { key -> lodge.text(key) != null }
                    MoonGifts -> !pure
                    else -> true
                }
            }
        }
    }
}
