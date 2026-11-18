package ie.forsaken.sheet

import ie.chronicles.core.*
import ie.forsaken.rules.*

internal class ForsakenActions(val catalog: ForsakenCatalog, private val apply: ((ForsakenCharacter) -> ForsakenCharacter) -> Unit) {
    private val edits = ForsakenEdits(catalog)
    fun change(transform: (ForsakenState) -> ForsakenState) = apply { edits.change(it, transform = transform) }
    fun renown(kind: Renown, rating: Int) = apply { edits.renown(it, kind, rating) }
    fun learn(found: CatalogFacet) = apply { edits.learn(it, found) }
    fun forget(id: SaveId) = apply { edits.forget(it, id) }
    fun specialty(skill: String, index: Int, previous: String, text: String) = apply { edits.specialty(it, skill, index, previous, text) }
    fun condition(row: CharacterCondition, event: ConditionEvent) = apply { edits.condition(it, row, event) }
}
