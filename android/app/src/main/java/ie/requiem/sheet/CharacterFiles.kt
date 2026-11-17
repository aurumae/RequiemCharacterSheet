package ie.requiem.sheet

import ie.chronicles.core.CharacterStore
import ie.requiem.rules.*
import java.io.File

internal typealias LibraryRow = ie.chronicles.core.LibraryRow
internal typealias CharacterExport = ie.chronicles.core.CharacterExport

internal fun CharacterFiles(directory: File, catalog: Catalog) = CharacterStore(
    directory, CharacterCodec(catalog), REQUIEM_FILE_EXTENSION,
    blank = { guided -> CharacterSave(creation = if (guided) CreationState() else null) },
    summarize = { c ->
        val clan = catalog.name(CatalogKind.clans, c.clan)
        val bloodline = catalog.name(CatalogKind.bloodlines, c.bloodline)
        val lineage = listOf(clan, bloodline.takeIf { it.isNotBlank() }?.let { "($it)" }.orEmpty())
            .filter { it.isNotBlank() }.joinToString(" ")
        val details = listOf(lineage, catalog.name(CatalogKind.covenants, c.covenant))
            .filter { it.isNotBlank() }.joinToString(" · ")
        LibraryRow(c.id, c.name, c.modifiedAt, c.creation != null, details = details)
    },
)
