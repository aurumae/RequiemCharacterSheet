package ie.requiem.sheet

import androidx.compose.runtime.Composable
import ie.chronicles.ui.*
import ie.requiem.rules.*

@Composable
internal fun StaminaControl(c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit) {
    TraitRatingControl("Stamina", c.stamina, c.staminaBonus(catalog),
        legalRatings(RatingKind.Attribute, c.bloodPotency), editable) { edit(SheetEdit.StaminaRating(it)) }
}

@Composable internal fun HealthTrack(c: CharacterSave, catalog: Catalog, editable: Boolean, edit: (SheetEdit) -> Unit) =
    HealthBoxes(c.healthTrack, c.health(catalog).coerceAtLeast(0), editable) { edit(SheetEdit.Mark(it)) }
