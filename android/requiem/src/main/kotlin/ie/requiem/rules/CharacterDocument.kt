package ie.requiem.rules

typealias UnsupportedGame = ie.chronicles.core.UnsupportedGame
typealias UnsupportedSchema = ie.chronicles.core.UnsupportedSchema
typealias CharacterDocumentError = ie.chronicles.core.CharacterDocumentError
typealias CharacterDocument = ie.chronicles.core.CharacterDocument<CharacterSave>
class CharacterDocuments(catalog: Catalog) : ie.chronicles.core.SheetDocuments<CharacterSave>(CharacterCodec(catalog))

const val REQUIEM_FILE_EXTENSION = "vtrcharacter"

fun characterFileName(name: String) = ie.chronicles.core.characterFileName(name, REQUIEM_FILE_EXTENSION)
fun copyName(name: String, taken: Set<String>) = ie.chronicles.core.copyName(name, taken)
