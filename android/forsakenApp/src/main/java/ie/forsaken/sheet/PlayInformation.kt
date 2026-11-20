package ie.forsaken.sheet

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.clickable
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import ie.chronicles.core.*
import ie.chronicles.ui.*
import ie.forsaken.rules.*
import kotlinx.serialization.json.*

@Composable internal fun FreeFacetRow(rules: ForsakenRules, renown: Renown, editable: Boolean, open: ()->Unit) {
    val count=rules.state.renownFacetCredits[renown.name] ?: 0
    if(rules.freeFacetChoices(renown).isEmpty()) PlayNote("${renown.title}: $count free ${if(count==1) "Facet" else "Facets"} kept for the next Gift.")
    else AddSheetRow("${renown.title}: ${if(count==1) "a free Facet to learn" else "$count free Facets to learn"}",editable,open)
}

@Composable internal fun FacetInformation(entry: ForsakenEntry, rules: ForsakenRules, open: ()->Unit, showName: Boolean=true) {
    val details=listOfNotNull(entry.text("renown")?.replaceFirstChar(Char::uppercaseChar),entry.text("cost"),entry.text("action"),entry.text("duration")).joinToString(" · ")
    val pool=entry.text("dicePool")
    val worked=pool?.let { rules.worked(it) }
    Column(Modifier.fillMaxWidth().clickable(role=Role.Button,onClick=open).padding(horizontal=8.dp,vertical=8.dp),verticalArrangement=Arrangement.spacedBy(3.dp)) {
        if(showName) SheetText(entry.name,style=LocalSheetType.current.trait)
        if(details.isNotBlank()) SheetText(details,style=MaterialTheme.typography.bodySmall,color=SheetColors.muted)
        if(pool!=null) Text(buildAnnotatedString {
            if(worked!=null) {
                withStyle(SpanStyle(color=SheetColors.accent,fontWeight=FontWeight.Bold)) { append(worked.summary) }
                append(" · ")
            }
            append(pool)
        },style=MaterialTheme.typography.bodyMedium)
    }
}

@Composable internal fun LodgeInformation(lodge: ForsakenEntry, catalog: ForsakenCatalog, open: (String)->Unit) {
    PlayInfo(lodge.name,lodge.summary,traitName=true) { open("lodges/${lodge.id}") }
    for(key in listOf("benefit","blessing","aspiration","ban","totem","tools")) lodge.text(key)?.let {
        PlayInfo(key.replaceFirstChar(Char::uppercaseChar),it)
    }
    catalog.sacredHunt(lodge)?.let {
        PlayInfo("Sacred Hunt",it.summary)
    }
    for(kind in listOf(CatalogKind.merits,CatalogKind.rites,CatalogKind.fetishes)) lodge.strings(kind.name).forEach { id ->
        catalog.entry(kind,id)?.let { entry -> PlayInfo(entry.name,kind.title,traitName=true) { open("${kind.name}/$id") } }
    }
    if(lodge.text("ban")!=null) PlayNote("Breaking the ban brings the Ban Condition; breaking it again under that Condition takes the Blessing away while it lasts. Lodge lore costs a werewolf outside the lodge three times the Experiences.")
}
