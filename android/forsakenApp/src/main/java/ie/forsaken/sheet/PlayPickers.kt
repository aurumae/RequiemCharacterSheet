package ie.forsaken.sheet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import ie.chronicles.core.*
import ie.chronicles.ui.*
import ie.forsaken.rules.*

internal data class PlayPick(val entry: ForsakenEntry, val group: String="", val detail: String="", val warning: String="", val disabled: Boolean=false, val facet: CatalogFacet?=null)

internal fun pickerKind(type: String): CatalogKind = when(type) {
    "blood","bone" -> CatalogKind.archetypes; "auspice" -> CatalogKind.auspices; "tribe" -> CatalogKind.tribes
    "lodge" -> CatalogKind.lodges; "kuruth" -> CatalogKind.kuruthTriggers
    "moon","extraMoon","shadow","wolf","free" -> CatalogKind.gifts
    "merit","totemMerit" -> CatalogKind.merits; "rite" -> CatalogKind.rites; "fetish" -> CatalogKind.fetishes
    else -> CatalogKind.conditions
}
internal fun pickerTitle(type: String) = when(type) {
    "extraMoon" -> "Add Moon Gift"; "moon" -> "Moon Gift"; "free" -> "Learn a free Facet"
    "shadow" -> "Add Shadow Facet"; "wolf" -> "Add Wolf Facet"; "totemMerit" -> "Totem Merit"
    "kuruth" -> "Kuruth trigger set"; else -> type.replaceFirstChar(Char::uppercaseChar)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable internal fun PlayCatalogPicker(type: String, rules: ForsakenRules, freeRenown: Renown?,
    choose: (PlayPick)->Unit, custom: ()->Unit, clear: (() -> Unit)?, dismiss: ()->Unit) {
    var query by rememberSaveable { mutableStateOf("") }
    val catalog=rules.catalog; val c=rules.state; val kind=pickerKind(type)
    val options=remember(type,c,catalog,freeRenown) {
        val knownFacets=c.facets.mapNotNull { it.source.catalog }.toSet()
        if(type in listOf("shadow","wolf","free")) {
            val candidates=if(type=="free" && freeRenown!=null) rules.freeFacetChoices(freeRenown) else catalog.all(CatalogKind.gifts)
                .filter { it.text("kind")==type }.flatMap { gift -> gift.array("facets").map { CatalogFacet(gift,ForsakenEntry(it as kotlinx.serialization.json.JsonObject)) } }
            candidates.filter { c.showsUnofficialContent || catalog.books[it.gift.source.book]?.official!=false }.map { found ->
                val price=rules.price(found); val renown=Renown.entries.firstOrNull { it.name==found.facet.text("renown") }
                val priceText=if(!c.xpMode) "" else if(price.renown!=null) "Free with ${price.renown?.title}" else
                    "${experiencesText(price.experiences)}"+(if(price.unlocksGift) " to unlock this Gift" else "")
                PlayPick(found.facet,found.gift.name,listOfNotNull(renown?.title,priceText.takeIf(String::isNotEmpty),"Affinity".takeIf { rules.hasAffinity(found.gift) }).joinToString(" · "),
                    if(found.facet.id in knownFacets) "Already known" else if(renown!=null && rules.renown(renown)==0) "Needs ${renown.title} 1" else "",
                    found.facet.id in knownFacets,found)
            }
        } else catalog.visible(kind,c.showsUnofficialContent).filter {
            when(type) { "blood","bone" -> it.text("kind")==type; "moon","extraMoon" -> it.text("kind")=="moon"
                "totemMerit" -> it.id !in totemMeritsNeverGranted; else -> true }
        }.map { entry ->
            when(type) {
                "merit","totemMerit" -> {
                    val granted=type=="totemMerit"
                    val owned=!granted && !entry.flag("repeatable") && c.merits.any { it.source.catalog==entry.id }
                    val specialty=entry.objectValue("qualifier")?.get("fromSpecialties")?.toString()=="true" && c.specialtyChoices.isEmpty()
                    val unavailable=rules.meritUnavailableReason(entry)
                    PlayPick(entry,entry.text("category")?.replaceFirstChar(Char::uppercaseChar).orEmpty(),
                        entry.array("ratings").joinToString(" or ")+" dots",
                        when { owned -> "Already owned"; unavailable!=null -> unavailable; specialty -> "Needs a Skill Specialty first"
                            !granted -> rules.prerequisiteChecks(entry).prerequisiteWarning(); else -> "" },owned || unavailable!=null || specialty)
                }
                "extraMoon","moon" -> {
                    val own=entry.text("auspice")==rules.effectiveAuspice?.id
                    val owned=type=="extraMoon" && (rules.moonGift?.id==entry.id || c.extraMoonGifts.any { it.source.catalog==entry.id })
                    PlayPick(entry,if(own) "Your Auspice" else "Other Auspices",
                        if(type=="extraMoon" && c.xpMode) "5 Experiences with its first Facet, then 2 for each Facet after it" else "",
                        when { owned -> "Already owned"; !own -> "A Moon Gift of the ${catalog.entry(CatalogKind.auspices,entry.text("auspice"))?.name ?: "other auspice"}"
                            rules.moonGiftDots==0 -> "Needs ${rules.moonGiftRenown?.title.orEmpty()} 1"; else -> "" },owned)
                }
                "rite" -> {
                    val owned=c.rites.any { it.source.catalog==entry.id }; val lodges=rules.lodgesTeaching("rites",entry.id)
                    PlayPick(entry,entry.text("kind")?.replaceFirstChar(Char::uppercaseChar).orEmpty(),"${entry.number("rating") ?: 1} dots",
                        if(owned) "Already known" else if(lodges.isNotEmpty()) "Lodge: ${lodges.joinToString { it.name }} (three times the cost otherwise)" else "",owned)
                }
                "condition" -> {
                    val owned=!entry.flag("repeatable") && c.conditions.any { it.source.catalog==entry.id }
                    PlayPick(entry,warning=if(owned) "Already active" else "",disabled=owned)
                }
                else -> PlayPick(entry)
            }
        }
    }
    val search=CatalogSearch(query)
    val matches=options.filter { search.matches(it.entry.name) || search.matches(it.entry.summary) || search.matches(it.group) || search.matches(catalog.citation(it.entry)) }
    CatalogPicker(pickerTitle(type),"Search names or rules",query,{query=it},"play-picker",dismiss) {
        catalog.books.values.filter { it.official || c.showsUnofficialContent }.forEach { book ->
            val groups=matches.filter { it.entry.source.book==book.id }.groupBy { it.group }.entries.toList()
            groups.forEachIndexed { index,(group,rows) ->
                item(key="${book.id}/$group") { CatalogSectionHeading(if(index==0) book.name+(if(book.official) "" else " (Unofficial)") else null,group) }
                items(rows,key={"${book.id}/$group/${it.entry.id}"}) { option ->
                    Column(Modifier.fillMaxWidth().clickable(enabled=!option.disabled,role=Role.Button) { choose(option) }.padding(vertical=12.dp)
                        .semantics(mergeDescendants=true) {}) {
                        SheetText(option.entry.name,style=LocalSheetType.current.trait,color=if(option.disabled) SheetColors.muted else SheetColors.ink)
                        if(option.detail.isNotEmpty()) SheetText(option.detail,style=MaterialTheme.typography.bodySmall,color=SheetColors.accent)
                        SheetText(option.entry.summary,style=MaterialTheme.typography.bodySmall)
                        if(option.warning.isNotEmpty()) SheetText(option.warning,style=MaterialTheme.typography.bodySmall,color=SheetColors.caution)
                        SheetText(catalog.citation(option.entry),style=MaterialTheme.typography.bodySmall,color=SheetColors.muted)
                    }; SheetRule()
                }
            }
        }
        if(matches.isEmpty()) item { PlayNote("No matching entries") }
        if(type!in listOf("free","totemMerit")) item { AddSheetRow("Custom ${pickerTitle(type).removePrefix("Add ")}",true,custom) }
        if(clear!=null) item { TextButton(onClick=clear) { SheetText("None") } }
    }
}
