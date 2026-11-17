package ie.requiem.sheet

import androidx.compose.runtime.Composable
import ie.chronicles.ui.SheetFieldRow
import ie.requiem.rules.*

@Composable
internal fun CharacterDetailRow(field: CharacterDetail, c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit, navigate: (String) -> Unit) {
    if (field.catalogKind != null) {
        IdentityRow(field, c, catalog, editable, navigate)
        return
    }
    SheetFieldRow("character/${field.name}", field.label, if (field == CharacterDetail.Name) "Character name" else field.label,
        field.value(c, catalog), editable) { edit(SheetEdit.Detail(field, it)) }
}
