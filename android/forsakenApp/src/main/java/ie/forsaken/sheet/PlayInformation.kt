package ie.forsaken.sheet

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import ie.chronicles.core.*
import ie.chronicles.ui.*
import ie.forsaken.rules.*
import kotlinx.serialization.json.*

@Composable internal fun FormAdvantages(rules: ForsakenRules, form: Form, conditions: (() -> Unit)?) {
    Column(Modifier.fillMaxWidth().padding(8.dp).semantics(mergeDescendants=true) {}) {
        SheetText(form.title+if(form==rules.state.form) " · Current form" else "",Modifier.semantics { heading() },style=LocalSheetType.current.trait,
            color=if(form==rules.state.form) SheetColors.accent else SheetColors.ink)
        SheetText("Size ${rules.size(form)} · Defense ${rules.defense(form)} · Initiative ${rules.initiative(form)} · Speed ${rules.speed(form)}",style=MaterialTheme.typography.bodyMedium)
        val armor=rules.armor(form)
        SheetText("Perception +${form.perceptionBonus} · Armor ${armor.first}/${armor.second} · Brawl ${rules.brawlPool(form)}",style=MaterialTheme.typography.bodyMedium)
        rules.alternativeDefenseSkills.forEach { SheetText("Defense (${traitTitle(it)}): ${rules.defense(form,it)}",style=MaterialTheme.typography.bodyMedium) }
        if(rules.state.skillRating("weaponry")>0) rules.weaponryPool(form)?.let { SheetText("Weaponry: $it",style=MaterialTheme.typography.bodyMedium) }
        if(rules.state.skillRating("firearms")>0) rules.firearmsPool(form)?.let { SheetText("Firearms: $it",style=MaterialTheme.typography.bodyMedium) }
        if(conditions!=null) ConditionIndicator("Defense",conditions)
    }
    SheetRule()
}

@Composable internal fun FreeFacetRow(rules: ForsakenRules, renown: Renown, editable: Boolean, open: ()->Unit) {
    val count=rules.state.renownFacetCredits[renown.name] ?: 0
    if(rules.freeFacetChoices(renown).isEmpty()) PlayNote("${renown.title}: $count free ${if(count==1) "Facet" else "Facets"} kept for the next Gift.")
    else AddSheetRow("${renown.title}: ${if(count==1) "a free Facet to learn" else "$count free Facets to learn"}",editable,open)
}

@Composable internal fun FacetInformation(entry: ForsakenEntry, rules: ForsakenRules, open: ()->Unit, showName: Boolean=true) {
    val details=listOfNotNull(entry.text("renown")?.replaceFirstChar(Char::uppercaseChar),entry.text("cost"),entry.text("action"),entry.text("duration")).joinToString(" · ")
    val pool=entry.text("dicePool")
    val worked=pool?.let { rules.worked(it) }
    val text=listOfNotNull(details.takeIf(String::isNotEmpty),pool?.let { (worked?.summary?.plus(" · ") ?: "")+it }).joinToString("\n")
    PlayInfo(if(showName) entry.name else "",text,open)
}

@Composable internal fun LodgeInformation(lodge: ForsakenEntry, catalog: ForsakenCatalog, open: (String)->Unit) {
    PlayInfo(lodge.name,lodge.summary) { open("lodges/${lodge.id}") }
    for(key in listOf("benefit","blessing","aspiration","ban","totem","tools")) lodge.text(key)?.let {
        PlayInfo(key.replaceFirstChar(Char::uppercaseChar),it)
    }
    catalog.sacredHunt(lodge)?.let {
        PlayInfo("Sacred Hunt",it.summary)
    }
    for(kind in listOf(CatalogKind.merits,CatalogKind.rites,CatalogKind.fetishes)) lodge.strings(kind.name).forEach { id ->
        catalog.entry(kind,id)?.let { entry -> PlayInfo(entry.name,kind.title) { open("${kind.name}/$id") } }
    }
    if(lodge.text("ban")!=null) PlayNote("Breaking the ban brings the Ban Condition; breaking it again under that Condition takes the Blessing away while it lasts. Lodge lore costs a werewolf outside the lodge three times the Experiences.")
}

@Composable internal fun PlayCondition(row: CharacterCondition, rules: ForsakenRules, editable: Boolean, actions: ForsakenActions, navigate: (String)->Unit) {
    val entry=rules.catalog.entry(CatalogKind.conditions,row.source.catalog)
    val name=rules.catalog.name(CatalogKind.conditions,row.source)
    PlayEntryHeader(name,editable,{navigate(if(entry!=null) "details|conditions/${entry.id}" else "custom|condition|${row.id}")},
        if(entry==null) ({navigate("custom|condition|${row.id}")}) else null,{navigate("endCondition|${row.id}")})
    PlayNote(entry?.summary ?: row.customEffect)
    val noteGroups=entry?.let(rules::noteOptionGroups).orEmpty()
    if(noteGroups.isNotEmpty()) {
        PlayChoice(entry?.text("notePrompt") ?: "Note",row.note,editable,{navigate("conditionNote|${row.id}")})
        entry?.noteOptions?.firstOrNull { it.name==row.note }?.let { PlayNote(it.summary) }
    } else SheetFieldRow("condition/${row.id}/note",entry?.text("notePrompt") ?: "Note","$name note",row.note,editable) { text ->
        actions.change { s -> s.copy(conditions=s.conditions.map { if(it.id==row.id) it.copy(note=text) else it }) }
    }
    if(entry?.flag("counter")==true) CounterRow("$name counter",row.counter,editable,row.counter>0,row.counter<99,
        { delta -> actions.change { s -> s.copy(conditions=s.conditions.map { if(it.id==row.id) it.copy(counter=(it.counter+delta).coerceIn(0,99)) else it }) } },
        {navigate("conditionCounter|${row.id}")})
    val resolution=entry?.text("resolution") ?: row.customResolution
    if(resolution.isNotEmpty()) PlayInfo("Resolution",resolution)
    val beat=entry?.text("beat") ?: row.customBeat
    if(beat.isNotEmpty()) {
        PlayInfo("Beat",beat)
        TextButton(onClick={actions.condition(row,ConditionEvent.beat)},enabled=editable) { SheetText("Take Beat from $name") }
    }
    Row {
        TextButton(onClick={navigate("resolveCondition|${row.id}")},enabled=editable) { SheetText("Resolve $name") }
        TextButton(onClick={navigate("endCondition|${row.id}")},enabled=editable) { SheetText("End $name") }
    }
    SheetRule()
}
