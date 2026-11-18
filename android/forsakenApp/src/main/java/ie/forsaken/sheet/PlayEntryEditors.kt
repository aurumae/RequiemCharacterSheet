package ie.forsaken.sheet

import androidx.compose.runtime.Composable
import ie.chronicles.core.*
import ie.forsaken.rules.*
import kotlinx.serialization.json.*

@Composable internal fun QualifierDialog(type: String, entryId: String, rowId: String, rules: ForsakenRules, actions: ForsakenActions, dismiss: () -> Unit) {
    val entry=rules.catalog.entry(CatalogKind.merits,entryId) ?: return
    val qualifier=entry.objectValue("qualifier") ?: return
    val row=rules.state.merits.firstOrNull { it.id.toString()==rowId }
    val choices=if(qualifier["fromSpecialties"]?.jsonPrimitive?.booleanOrNull==true) rules.state.specialtyChoices.map { it.specialty }
        else (qualifier["options"] as? JsonArray).orEmpty().map { it.jsonPrimitive.content }
    val prompt=qualifier["prompt"]?.jsonPrimitive?.content ?: "For"
    fun save(value: String) {
        if(row==null) selectCatalog(type,PlayPick(entry),rules,actions,value)
        else actions.change { s -> s.copy(merits=s.merits.map { if(it.id==row.id) it.copy(qualifier=value) else it }) }
    }
    if(choices.isNotEmpty()) ChoiceDialog("${entry.name}: $prompt",choices.map { PlayOption(it,it) },row?.qualifier,dismiss) { save(it); dismiss() }
    else DraftDialog("${entry.name}: $prompt",listOf(DraftField(prompt,row?.qualifier.orEmpty())),dismiss) { save(it[0].trim()) }
}

@Composable internal fun CustomEntryDialog(type: String, rowId: String, c: ForsakenState, rules: ForsakenRules,
    actions: ForsakenActions, navigate: (String?) -> Unit) {
    val catalog=rules.catalog; val dismiss={navigate(null)}
    val merit=c.merits.firstOrNull { it.id.toString()==rowId }
    val facet=c.facets.firstOrNull { it.id.toString()==rowId }
    val moon=c.extraMoonGifts.firstOrNull { it.id.toString()==rowId }
    val rite=c.rites.firstOrNull { it.id.toString()==rowId }
    val fetish=c.fetishes.firstOrNull { it.id.toString()==rowId }
    val condition=c.conditions.firstOrNull { it.id.toString()==rowId }
    if(type=="merit" && merit?.source?.catalog!=null) {
        QualifierDialog(type,merit.source.catalog!!,rowId,rules,actions,dismiss); return
    }
    if(type=="fetish" && fetish?.source?.catalog!=null) {
        DraftDialog(catalog.name(CatalogKind.fetishes,fetish.source),listOf(DraftField("Note",fetish.note,multiline=true)),dismiss,valid={true}) { input ->
            actions.change { s -> s.copy(fetishes=s.fetishes.map { if(it.id==fetish.id) it.copy(note=input[0]) else it }) }
        }; return
    }
    val source=when(type) {
        "merit" -> merit?.source; "shadow","wolf" -> facet?.source; "extraMoon" -> moon?.source
        "rite" -> rite?.source; "fetish" -> fetish?.source; "condition" -> condition?.source
        "blood" -> c.blood; "bone" -> c.bone; "auspice" -> c.auspice; "tribe" -> c.tribe
        "lodge" -> c.lodge; "kuruth" -> c.kuruthTriggerSet; "moon" -> c.moonGift; else -> null
    }
    val fields=buildList {
        add(DraftField("Name",source?.custom.orEmpty()))
        when(type) {
            "shadow","wolf" -> add(DraftField("Gift",facet?.customGift.orEmpty()))
            "merit" -> add(DraftField("Dots (1–5)",(merit?.rating ?: 1).toString(),numeric=true))
            "rite" -> add(DraftField("Dots (1–5)",(rite?.customRating ?: 1).toString(),numeric=true))
            "fetish" -> { add(DraftField("Dots (1–5)",(fetish?.customRating ?: 1).toString(),numeric=true)); add(DraftField("Note",fetish?.note.orEmpty(),multiline=true)) }
            "condition" -> {
                add(DraftField("Effect",condition?.customEffect.orEmpty(),multiline=true))
                add(DraftField("Resolution",condition?.customResolution.orEmpty(),multiline=true))
                add(DraftField("Beat",condition?.customBeat.orEmpty(),multiline=true))
                add(DraftField("Persistent",if(condition?.customPersistent==true) "yes" else "no",toggle=true))
            }
        }
    }
    DraftDialog("Custom ${pickerTitle(type).removePrefix("Add ")}",fields,dismiss,valid={ values ->
        values[0].isNotBlank() && (type !in listOf("merit","rite","fetish") || values[1].toIntOrNull() in 1..5) &&
            (type!="condition" || values[4].trim().lowercase() in listOf("yes","no"))
    },supportingText=if(c.xpMode && rowId.isEmpty()) when(type) {
        "shadow","wolf" -> "Costs 2 Experiences."
        "extraMoon" -> "Costs 5 Experiences with its first Facet, then 2 for each Facet after it."
        "merit","rite" -> "Costs 1 Experience per dot."
        else -> null
    } else null) { values ->
        // Custom powers stay custom; identity fields use the same name linking as iOS.
        val selected=if(type in listOf("blood","bone","auspice","tribe","lodge","kuruth")) catalog.index(pickerKind(type)).source(values[0].trim())
            else TraitSource(custom=values[0].trim())
        if(type=="condition" && condition==null) actions.condition(CharacterCondition(selected,customEffect=values[1],customResolution=values[2],customBeat=values[3],
            customPersistent=values[4].trim().equals("yes",ignoreCase=true)),ConditionEvent.added)
        else actions.change { s -> when(type) {
            "merit" -> s.copy(merits=if(merit==null) s.merits+Merit(selected,rating=values[1].toInt()) else s.merits.map { if(it.id==merit.id) it.copy(source=selected,rating=values[1].toInt()) else it })
            "shadow","wolf" -> s.copy(facets=if(facet==null) s.facets+OwnedFacet(selected,customGift=values[1],customKind=GiftKind.valueOf(type)) else s.facets.map { if(it.id==facet.id) it.copy(source=selected,customGift=values[1]) else it })
            "extraMoon" -> s.copy(extraMoonGifts=if(moon==null) s.extraMoonGifts+OwnedMoonGift(selected) else s.extraMoonGifts.map { if(it.id==moon.id) it.copy(source=selected) else it })
            "rite" -> s.copy(rites=if(rite==null) s.rites+OwnedRite(selected,customRating=values[1].toInt()) else s.rites.map { if(it.id==rite.id) it.copy(source=selected,customRating=values[1].toInt()) else it })
            "fetish" -> s.copy(fetishes=if(fetish==null) s.fetishes+OwnedFetish(selected,customRating=values[1].toInt(),note=values[2]) else s.fetishes.map { if(it.id==fetish.id) it.copy(source=selected,customRating=values[1].toInt(),note=values[2]) else it })
            "condition" -> s.copy(conditions=s.conditions.map { if(it.id==condition?.id) it.copy(source=selected,customEffect=values[1],customResolution=values[2],customBeat=values[3],customPersistent=values[4].trim().equals("yes",true)) else it })
            else -> identity(s,type,selected)
        } }
    }
}
