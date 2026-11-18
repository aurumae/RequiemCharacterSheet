package ie.forsaken.sheet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import ie.chronicles.core.*
import ie.chronicles.ui.*
import ie.forsaken.rules.*
import kotlinx.serialization.json.*

private data class PlayRow(val key: String, val section: ForsakenSection, val content: @Composable () -> Unit)

@Composable
internal fun ForsakenSheet(character: ForsakenCharacter, actions: ForsakenActions, editable: Boolean, requested: ForsakenSection?,
    report: (ForsakenSection) -> Unit, handled: () -> Unit) {
    val c = character.state; val catalog = actions.catalog
    val rules = remember(c, catalog) { ForsakenRules(c, catalog) }
    val art = rememberHeadingArt()
    var overlay by rememberSaveable(character.id.toString()) { mutableStateOf<String?>(null) }
    fun navigate(route: String) { overlay = route }
    fun conditions(target: String): (() -> Unit)? = if (rules.conditionEffects(target).isEmpty()) null else ({ navigate("effects|$target") })
    val rows = buildList {
        for (section in ForsakenSection.available(c, catalog)) {
            fun row(id: String, content: @Composable () -> Unit) { add(PlayRow("${section.name}/$id", section, content)) }
            fun note(id: String, text: String) = row(id) { PlayNote(text) }
            fun field(id: String, label: String, value: String, transform: (ForsakenState, String) -> ForsakenState) = row(id) {
                SheetFieldRow("${section.name}/$id", label, "${section.title} $label", value, editable) { text -> actions.change { transform(it, text) } }
                SheetRule()
            }
            fun number(key: String, title: String, value: Int, range: IntRange, transform: (ForsakenState, Int) -> ForsakenState) = row(key) {
                CounterRow(title, value, editable, value > range.first, value < range.last,
                    { amount -> actions.change {
                        val latest=when(key) { "armor" -> it.armor; "ballisticArmor" -> it.ballisticArmor; "packPoints" -> it.totem.packPoints
                            "essence" -> it.essence; "experiences" -> it.experiences; else -> error("Unknown counter $key") }
                        transform(it, (latest.toLong() + amount).coerceIn(range.first.toLong(), range.last.toLong()).toInt())
                    } },
                    { navigate("number|$key") })
            }
            fun choice(key: String, title: String, value: String, reference: String? = null) = row(key) {
                PlayChoice(title, value, editable, { navigate("pick|$key") }, reference?.let { { navigate("details|$it") } })
            }
            row("heading") { ForsakenHeading(section.title, art[section.title]) }
            when (section) {
                ForsakenSection.Character -> {
                    field("name", "Name", c.name) { s, v -> s.copy(name=v) }
                    field("player", "Player", c.player) { s, v -> s.copy(player=v) }
                    field("chronicle", "Chronicle", c.chronicle) { s, v -> s.copy(chronicle=v) }
                    field("concept", "Concept", c.concept) { s, v -> s.copy(concept=v) }
                    choice("blood","Blood",catalog.name(CatalogKind.archetypes,c.blood),c.blood.catalog?.let { "archetypes/$it" })
                    choice("bone","Bone",catalog.name(CatalogKind.archetypes,c.bone),c.bone.catalog?.let { "archetypes/$it" })
                    if (!rules.isPure) choice("auspice","Auspice",catalog.name(CatalogKind.auspices,c.auspice),c.auspice.catalog?.let { "auspices/$it" })
                    choice("tribe","Tribe",catalog.name(CatalogKind.tribes,c.tribe),c.tribe.catalog?.let { "tribes/$it" })
                    choice("lodge","Lodge",catalog.name(CatalogKind.lodges,c.lodge),c.lodge.catalog?.let { "lodges/$it" })
                    if (rules.isPure) row("huntersAspect") { PlayChoice("Hunter's Aspect",c.huntersAspect,editable,{navigate("aspect")}) }
                    rules.huntersAspect?.let { aspect ->
                        val name = aspect["name"]?.jsonPrimitive?.content.orEmpty()
                        val condition = aspect["condition"]?.jsonPrimitive?.content
                        row("aspectDetails") { PlayInfo("Hunter's Aspect: $name", catalog.entry(CatalogKind.conditions,condition)?.summary.orEmpty(),
                            condition?.let { { navigate("details|conditions/$it") } }) }
                    }
                    row("unofficial") { PlaySwitch("Unofficial Content",c.showsUnofficialContent,editable) { checked -> actions.change { it.copy(showsUnofficialContent=checked) } } }
                    row("browse") { TextButton(onClick={navigate("browse")}) { SheetText("Browse catalog") } }
                }
                ForsakenSection.Form -> {
                    row("choose") { PlayChoice("Form","${c.form.title} · ${c.form.description}",editable,{navigate("form")}) }
                    note("modifiers",attributeDefinitions.mapNotNull {
                        val amount=rules.formModifier(it.id,c.form)
                        if(amount==0) null else "${it.name} ${if(amount>0) "+$amount" else "−${-amount}"}"
                    }.joinToString(" · "))
                    note("formNotes",c.form.notes)
                    rules.favoredForm?.let { (form,dots) ->
                        note("favored","Favored Form: ${form.title}. Choose the Attributes raised and each drawback (p. 106).")
                        repeat(if(dots>=4) 2 else if(dots>=2) 1 else 0) { index -> row("favoredRaised/$index") {
                            PlayChoice("${if(index==0) "Second" else "Fourth"} dot",c.favoredForm.attributes.getOrNull(index)?.let(::traitTitle).orEmpty(),editable,{navigate("favored|raised|$index")})
                        } }
                        repeat(dots.coerceIn(0,10)) { index -> row("drawback/$index") {
                            val d=c.favoredForm.drawbacks.getOrNull(index)
                            PlayChoice("Drawback ${index+1}", listOfNotNull(d?.form?.title,d?.attribute?.let(::traitTitle)).joinToString(" · "),editable,{navigate("favored|drawback|$index")})
                        } }
                    }
                }
                ForsakenSection.Advantages -> {
                    Form.entries.forEach { form -> row("form/${form.name}") { FormAdvantages(rules,form,conditions("defense")) } }
                    note("combat","Defense applies against Firearms in Dalu. Gauru adds +3 Initiative when attacking with teeth or claws. Touching silver does 1 bashing damage a turn, or 1 lethal on nights of the full moon.")
                    number("armor","Armor",c.armor,0..99) { s,v -> s.copy(armor=v) }
                    number("ballisticArmor","Ballistic Armor",c.ballisticArmor,0..99) { s,v -> s.copy(ballisticArmor=v) }
                }
                ForsakenSection.Attributes -> {
                    TraitCategory.entries.forEach { category ->
                        row("category/${category.name}") { SubsectionLabel(category.title) }
                        c.attributes.filter { a -> attributeDefinitions.firstOrNull { it.id==a.attribute }?.category==category }.forEach { a -> row(a.attribute) {
                            TraitRatingControl(traitTitle(a.attribute),a.rating,rules.totalAttribute(a.attribute)-a.rating,1..rules.baseRatingCap,editable,
                                countedRating=rules.attribute(a.attribute),note=rules.attributeNote(a.attribute),onConditions=conditions("attribute:${a.attribute}")) { value ->
                                actions.change { s -> s.copy(attributes=s.attributes.map { if(it.attribute==a.attribute) it.copy(rating=value) else it }) }
                            }; SheetRule()
                        } }
                    }
                }
                ForsakenSection.Skills -> {
                    TraitCategory.entries.forEach { category ->
                        row("category/${category.name}") { SubsectionLabel("${category.title} (${category.unskilledPenalty} unskilled)") }
                        c.skills.filter { sk -> modernSkillDefinitions.firstOrNull { it.id==sk.skill }?.category==category }.forEach { skill ->
                            row(skill.skill) {
                                TraitRatingControl(traitTitle(skill.skill),skill.rating,rules.skillBonus(skill.skill),0..rules.baseRatingCap,editable,
                                    countedRating=rules.skill(skill.skill),onConditions=conditions("skill:${skill.skill}")) { value ->
                                    actions.change { s -> s.copy(skills=s.skills.map { if(it.skill==skill.skill) it.copy(rating=value) else it }) }
                                }
                            }
                            skill.specialties.forEachIndexed { index,text -> row("${skill.skill}/specialty/$index") {
                                TextButton(onClick={navigate("specialty|${skill.skill}|$index")},enabled=editable) { SheetText(text.ifBlank { "Unnamed Specialty" }) }
                            } }
                            rules.grantedSpecialties(skill.skill).forEachIndexed { index,text -> note("${skill.skill}/granted/$index","$text · From the totem") }
                            row("${skill.skill}/add") { AddSheetRow("Add ${traitTitle(skill.skill)} Specialty",editable) { navigate("specialty|${skill.skill}|-1") }; SheetRule() }
                        }
                    }
                }
                ForsakenSection.Merits -> {
                    c.merits.forEach { merit -> row(merit.id.toString()) {
                        val entry=catalog.entry(CatalogKind.merits,merit.source.catalog)
                        val title=catalog.name(CatalogKind.merits,merit.source) + merit.qualifier?.takeIf { it.isNotEmpty() }?.let { " ($it)" }.orEmpty()
                        val values=entry?.array("ratings")?.map { it.jsonPrimitive.int }?.sorted()?.takeIf { it.isNotEmpty() } ?: (1..5).toList()
                        PlayEntryHeader(title,editable,{navigate(if(entry!=null) "details|merits/${entry.id}" else "custom|merit|${merit.id}")},
                            if(entry==null || entry.objectValue("qualifier")!=null) ({navigate("custom|merit|${merit.id}")}) else null,{navigate("remove|merit|${merit.id}")})
                        TraitRatingControl(title,merit.rating,merit.source.catalog?.let(rules::meritBonus) ?: 0,0..maxOf(5,values.last()),editable,
                            allowedValues=listOf(0)+values,visibleCap=5) { value -> actions.change { s -> s.copy(merits=s.merits.map { if(it.id==merit.id) it.copy(rating=value) else it }) } }
                        if(entry!=null && rules.prerequisitesApply(merit)) {
                            val warning=rules.prerequisiteChecks(entry).prerequisiteWarning()
                            if(warning.isNotEmpty()) PlayNote(warning,true)
                        }
                        if(entry!=null && !rules.prerequisitesApply(merit)) PlayNote("Includes ${rules.meritBonus(entry.id)} dots from the totem; prerequisites do not apply.")
                        SheetRule()
                    } }
                    row("add") { AddSheetRow("Add Merit",editable) { navigate("pick|merit") } }
                }
                ForsakenSection.Totem -> {
                    field("name","Name",c.totem.name) { s,v -> s.copy(totem=s.totem.copy(name=v)) }
                    field("aspiration","Aspiration",c.totem.aspiration) { s,v -> s.copy(totem=s.totem.copy(aspiration=v)) }
                    field("ban","Ban",c.totem.ban) { s,v -> s.copy(totem=s.totem.copy(ban=v)) }
                    number("packPoints","Pack's Totem points",c.totem.packPoints,0..99) { s,v -> s.copy(totem=s.totem.copy(packPoints=v)) }
                    note("ownDots","Every packmate's Totem dots added up. Yours: ${c.merits.firstOrNull { it.source.catalog=="totem" }?.rating ?: 0}, from the Totem Merit.")
                    row("budget") { PlayNote("Advantages: ${c.totem.experiencesSpent} of ${c.totem.experienceBudget} Experiences",c.totem.experiencesSpent>c.totem.experienceBudget) }
                    note("benefits","Every pack member gains them, even past their usual limits or without a Merit's prerequisites.")
                    c.totem.advantages.forEach { advantage -> row(advantage.id.toString()) {
                        val name=if(advantage.kind==TotemKind.merit) catalog.entry(CatalogKind.merits,advantage.target)?.name ?: advantage.target else traitTitle(advantage.target)
                        PlayEntryHeader(name+advantage.detail.takeIf(String::isNotEmpty)?.let { " ($it)" }.orEmpty(),editable,
                            {navigate("totem|${advantage.kind.name}|${advantage.id}")},{navigate("totem|${advantage.kind.name}|${advantage.id}")},{navigate("remove|totem|${advantage.id}")})
                        PlayNote("${advantage.dots} ${if(advantage.dots==1) "dot" else "dots"} · ${experiencesText(advantage.cost)}")
                    } }
                    row("add") { AddSheetRow("Add Advantage",editable) { navigate("totemKind") } }
                }
                ForsakenSection.Renown -> {
                    Renown.entries.forEach { kind -> row(kind.name) {
                        TraitRatingControl(kind.title,rules.renown(kind),0,0..5,editable) { actions.renown(kind,it) }
                        if(kind in rules.renownsWithFreeFacets) FreeFacetRow(rules,kind,editable) { navigate("pick|free|${kind.name}") }
                        SheetRule()
                    } }
                    row("rank") { ValueRow("Spirit Rank",rules.spiritRank) }
                }
                ForsakenSection.AuspiceBenefit -> rules.effectiveAuspice?.let { auspice -> row("benefit") {
                    val benefit=auspice.objectValue("benefit")
                    PlayInfo(benefit?.get("name")?.jsonPrimitive?.content.orEmpty(),benefit?.get("summary")?.jsonPrimitive?.content.orEmpty()) { navigate("details|auspices/${auspice.id}") }
                } }
                ForsakenSection.Lodge -> rules.lodge?.let { lodge -> row("lodge") { LodgeInformation(lodge,catalog) { navigate("details|$it") } } }
                ForsakenSection.MoonGifts -> {
                    choice("moon","Moon Gift",rules.moonGiftName,rules.moonGift?.id?.let { "gifts/$it" })
                    fun moonRows(id: String, gift: ForsakenEntry?, source: TraitSource?, known: Int, names: List<String>, update: (ForsakenState,List<String>)->ForsakenState) {
                        if(gift!=null) gift.array("facets").map { ForsakenEntry(it.jsonObject) }.sortedBy { it.number("dots") ?: 0 }.forEach { facet -> row("$id/${facet.id}") {
                            val unlocked=(facet.number("dots") ?: 0)<=known
                            Column(Modifier.alpha(if(unlocked) 1f else .45f)) {
                                FacetInformation(facet,rules,{navigate("details|facet/${facet.id}")})
                                if(!unlocked) PlayNote("Comes with ${rules.moonGiftRenown?.title.orEmpty()} ${facet.number("dots") ?: 0}")
                            }
                        } } else if(source?.custom!=null) repeat(5) { index -> row("$id/custom/$index") {
                            Column(Modifier.alpha(if(index<known) 1f else .45f)) {
                                SheetFieldRow("$id/custom/$index","Facet ${index+1}","$id ${index+1}-dot Facet",names.getOrNull(index).orEmpty(),editable) { text ->
                                    actions.change { state ->
                                        val all=names.toMutableList(); while(all.size<=index) all.add(""); all[index]=text
                                        while(all.lastOrNull()=="") all.removeAt(all.lastIndex)
                                        update(state,all)
                                    }
                                }
                            }
                        } }
                    }
                    moonRows("own",rules.moonGift,c.moonGift,rules.moonGiftDots,c.moonFacets) { s,v -> s.copy(moonFacets=v) }
                    c.extraMoonGifts.forEach { owned ->
                        val gift=catalog.entry(CatalogKind.gifts,owned.source.catalog); val name=catalog.name(CatalogKind.gifts,owned.source)
                        row(owned.id.toString()) {
                            PlayEntryHeader(name,editable,{navigate(if(gift!=null) "details|gifts/${gift.id}" else "custom|extraMoon|${owned.id}")},
                                if(gift==null) ({navigate("custom|extraMoon|${owned.id}")}) else null,{navigate("remove|extraMoon|${owned.id}")})
                            TraitRatingControl(name,owned.dots,0,1..maxOf(1,rules.moonGiftDots),editable,countedRating=rules.moonDots(owned),visibleCap=5) { value ->
                                actions.change { s -> s.copy(extraMoonGifts=s.extraMoonGifts.map { if(it.id==owned.id) it.copy(dots=value) else it }) }
                            }
                            if(owned.dots<5) PlayNote(if(owned.dots>=rules.moonGiftDots) "Its next Facet needs ${rules.moonGiftRenown?.title.orEmpty()} ${owned.dots+1}"
                                else if(c.xpMode) "Its next Facet costs 2 Experiences" else "")
                        }
                        moonRows(owned.id.toString(),gift,owned.source,rules.moonDots(owned),owned.facets) { s,v -> s.copy(extraMoonGifts=s.extraMoonGifts.map { if(it.id==owned.id) it.copy(facets=v) else it }) }
                    }
                    row("add") { AddSheetRow("Add Moon Gift",editable) { navigate("pick|extraMoon") } }
                }
                ForsakenSection.ShadowGifts, ForsakenSection.WolfGifts -> {
                    val kind=if(section==ForsakenSection.ShadowGifts) "shadow" else "wolf"
                    rules.renownsWithFreeFacets.forEach { renown -> row("free/${renown.name}") { FreeFacetRow(rules,renown,editable) { navigate("pick|free|${renown.name}") } } }
                    val owned=c.facets.filter { (rules.gift(it)?.text("kind") ?: it.customKind.name)==kind }
                    owned.groupBy { rules.gift(it)?.id ?: "custom/${it.customGift}" }.forEach { (key,facets) ->
                        val gift=rules.gift(facets.first()); val name=gift?.name ?: facets.first().customGift.ifBlank { "Custom Gift" }
                        row("gift/$key") { SubsectionLabel(name); PlayNote("${facets.size} of ${gift?.array("facets")?.size ?: 5}") }
                        facets.forEach { facet -> row(facet.id.toString()) {
                            val entry=catalog.facet(facet.source.catalog)?.facet
                            PlayEntryHeader(rules.facetName(facet),editable,{navigate(if(entry!=null) "details|facet/${entry.id}" else "custom|$kind|${facet.id}")},
                                if(entry==null) ({navigate("custom|$kind|${facet.id}")}) else null,{navigate("remove|facet|${facet.id}")})
                            if(entry!=null) {
                                FacetInformation(entry,rules,{navigate("details|facet/${entry.id}")},showName=false)
                                if(entry.array("effects").isNotEmpty() && !entry.flag("passive")) PlaySwitch("${entry.name} active",facet.active,editable) { value ->
                                    actions.change { s -> s.copy(facets=s.facets.map { if(it.id==facet.id) it.copy(active=value) else it }) }
                                }
                            }
                            if(facet.withRenown) PlayNote("Learned with Renown")
                            SheetRule()
                        } }
                    }
                    row("add") { AddSheetRow("Add ${kind.replaceFirstChar(Char::uppercaseChar)} Facet",editable) { navigate("pick|$kind") } }
                }
                ForsakenSection.Rites -> {
                    c.rites.forEach { rite -> row(rite.id.toString()) {
                        val entry=catalog.entry(CatalogKind.rites,rite.source.catalog); val name=catalog.name(CatalogKind.rites,rite.source)
                        PlayEntryHeader(name,editable,{navigate(if(entry!=null) "details|rites/${entry.id}" else "custom|rite|${rite.id}")},
                            if(entry==null) ({navigate("custom|rite|${rite.id}")}) else null,{navigate("remove|rite|${rite.id}")})
                        PlayNote("${rules.riteRating(rite)} dots"+entry?.text("kind")?.let { " · $it" }.orEmpty())
                        if(entry!=null && entry.array("effects").isNotEmpty()) PlaySwitch("$name active",rite.active,editable) { value -> actions.change { s -> s.copy(rites=s.rites.map { if(it.id==rite.id) it.copy(active=value) else it }) } }
                        val lodges=rules.lodgesTeaching("rites",rite.source.catalog)
                        if(lodges.isNotEmpty()) PlayNote("Lodge: ${lodges.joinToString { it.name }} (three times the cost otherwise)",rules.lodgeMultiplier(lodges)>1)
                        SheetRule()
                    } }
                    row("add") { AddSheetRow("Add Rite",editable) { navigate("pick|rite") } }
                }
                ForsakenSection.Fetishes -> {
                    c.fetishes.forEach { fetish -> row(fetish.id.toString()) {
                        val entry=catalog.entry(CatalogKind.fetishes,fetish.source.catalog); val name=catalog.name(CatalogKind.fetishes,fetish.source)
                        PlayEntryHeader(name,editable,{navigate(if(entry!=null) "details|fetishes/${entry.id}" else "custom|fetish|${fetish.id}")},
                            {navigate("custom|fetish|${fetish.id}")},{navigate("remove|fetish|${fetish.id}")})
                        PlayNote("${entry?.number("rating") ?: fetish.customRating} dots"+fetish.note.takeIf(String::isNotEmpty)?.let { " · $it" }.orEmpty())
                        SheetRule()
                    } }
                    row("add") { AddSheetRow("Add Fetish",editable) { navigate("pick|fetish") } }
                }
                ForsakenSection.Aspirations -> {
                    c.aspirations.forEachIndexed { index,asp -> row(asp.id.toString()) {
                        WrittenRow(asp.text,"Tap to write an Aspiration",editable,"Aspiration ${index+1}",{navigate("asp|${asp.id}")},{navigate("remove|asp|${asp.id}")})
                    } }
                    row("add") { AddSheetRow("Add Aspiration",editable) { navigate("asp|new") } }
                }
                ForsakenSection.Health -> row("track") { HealthBoxes(c.healthTrack,rules.health().coerceAtLeast(0),editable) { index ->
                    actions.change { it.copy(healthTrack=it.healthTrack.editBox(rules.health(),index,Damage.none) { old -> Damage.entries[(old.ordinal+1)%Damage.entries.size] }) }
                } }
                ForsakenSection.Willpower -> row("track") { WillpowerBoxes(c.willpowerTrack,rules.willpower,editable) { index ->
                    actions.change { it.copy(willpowerTrack=it.willpowerTrack.editBox(rules.willpower,index,WillpowerMark.none) { old -> if(old==WillpowerMark.none) WillpowerMark.spent else WillpowerMark.none }) }
                } }
                ForsakenSection.PrimalUrge -> {
                    row("primalUrge") { TraitRatingControl("Primal Urge",c.primalUrge,0,1..10,editable) { value -> actions.change { it.copy(primalUrge=value) } } }
                    val level=rules.primalUrge
                    note("table","Traits up to ${level.traitMaximum} · Heals ${level.regeneration} bashing a turn"+
                        (if(level.feeding!="None") " · Lives only on ${level.feeding.lowercase()}" else "")+(if(level.lunacyPenalty!=0) " · Lunacy ${level.lunacyPenalty}" else ""))
                    number("essence","Essence",c.essence,0..rules.essenceMaximum.coerceAtLeast(0)) { s,v -> s.copy(essence=v) }
                    note("pool","Holds ${rules.essenceMaximum} · Spend up to ${level.essencePerTurn} a turn")
                }
                ForsakenSection.Harmony -> {
                    row("harmony") { TraitRatingControl("Harmony",c.harmony,0,0..10,editable) { value -> actions.change { it.copy(harmony=value) } } }
                    note("table",harmonyDescription(c.harmony))
                    field("fleshTouchstone","Flesh",c.fleshTouchstone) { s,v -> s.copy(fleshTouchstone=v) }
                    if(c.harmony<=2) note("fleshInactive","The flesh Touchstone falls away at Harmony 2 or less.")
                    field("spiritTouchstone","Spirit",c.spiritTouchstone) { s,v -> s.copy(spiritTouchstone=v) }
                    if(c.harmony>=8) note("spiritInactive","The spirit Touchstone falls away at Harmony 8 or more.")
                }
                ForsakenSection.Kuruth -> {
                    choice("kuruth","Trigger set",catalog.name(CatalogKind.kuruthTriggers,c.kuruthTriggerSet),c.kuruthTriggerSet.catalog?.let { "kuruthTriggers/$it" })
                    TriggerKind.entries.forEach { kind -> row(kind.name) {
                        Column(Modifier.alpha(if(kind.applies(c.harmony)) 1f else .45f)) {
                            if(c.kuruthTriggerSet.catalog!=null) PlayInfo(kind.name.replaceFirstChar(Char::uppercaseChar),rules.kuruthTrigger(kind))
                            else SheetFieldRow("kuruth/${kind.name}",kind.name.replaceFirstChar(Char::uppercaseChar),"Kuruth ${kind.name}",rules.kuruthTrigger(kind),editable) { value -> actions.change {
                                it.copy(kuruthTriggers=when(kind) { TriggerKind.passive -> it.kuruthTriggers.copy(passive=value); TriggerKind.common -> it.kuruthTriggers.copy(common=value); TriggerKind.specific -> it.kuruthTriggers.copy(specific=value) })
                            } }
                        }
                    } }
                    note("general","General Triggers\n"+generalKuruthTriggers.joinToString("\n"))
                }
                ForsakenSection.Experience -> {
                    row("xpMode") { PlaySwitch("XP Mode",c.xpMode,editable) { value -> actions.change { it.copy(xpMode=value) } } }
                    note("help",if(c.xpMode) "Raising a trait spends Experiences. Lowering a paid trait refunds what was paid." else "Changes are free, e.g. Storyteller awards or entering an existing character.")
                    row("beats") { CounterRow("Beats",c.beats,editable,c.beats>0,true,{ amount -> actions.change {
                        if(amount<0) it.copy(beats=(it.beats-1).coerceAtLeast(0)) else incrementBeat(it.beats,it.experiences).let { total -> it.copy(beats=total.beats,experiences=total.experiences) }
                    } },{navigate("number|beats")}) }
                    number("experiences","Experiences",c.experiences,0..Int.MAX_VALUE) { s,v -> s.copy(experiences=v) }
                    row("spent") { ValueRow("Spent",rules.experiencesSpent) }
                    row("available") { ValueRow("Available",rules.experiencesAvailable,caution=rules.experiencesAvailable<0) }
                    row("log") { TextButton(onClick={navigate("log")}) { SheetText("View change log") } }
                }
                ForsakenSection.Conditions -> {
                    c.conditions.forEach { condition -> row(condition.id.toString()) { PlayCondition(condition,rules,editable,actions,::navigate) } }
                    row("add") { AddSheetRow("Add Condition",editable) { navigate("pick|condition") } }
                }
                ForsakenSection.Creation -> Unit
            }
        }
    }
    SheetList(rows.map { it.section },requested,report,handled) { items(rows,key={it.key}) { it.content() } }
    overlay?.let { route -> key(route) { PlayDialogs(route,character,rules,actions) { overlay=it } } }
}

@Composable internal fun PlayNote(text: String, warning: Boolean=false) {
    if(text.isNotEmpty()) SheetText(text,Modifier.fillMaxWidth().padding(8.dp),style=MaterialTheme.typography.bodySmall,color=if(warning) SheetColors.caution else SheetColors.muted)
}
@Composable internal fun PlayInfo(title: String, text: String, open: (() -> Unit)?=null) {
    Column(Modifier.fillMaxWidth().then(if(open!=null) Modifier.clickable(role=Role.Button,onClick=open) else Modifier).padding(8.dp)) {
        if(title.isNotEmpty()) SheetText(title,style=LocalSheetType.current.trait)
        if(text.isNotEmpty()) SheetText(text,Modifier.padding(top=4.dp),style=MaterialTheme.typography.bodyMedium)
        if(open!=null) SheetText("Read details ›",style=MaterialTheme.typography.bodySmall,color=SheetColors.accent)
    }
}
@Composable internal fun PlayChoice(label: String,value: String,editable: Boolean,choose: () -> Unit,details: (() -> Unit)?=null) {
    Column(Modifier.fillMaxWidth().padding(horizontal=8.dp)) {
        Row(verticalAlignment=Alignment.CenterVertically) {
            SheetText(label,Modifier.weight(1f),style=LocalSheetType.current.label)
            TextButton(onClick=choose,enabled=editable) { SheetText("Choose $label") }
        }
        if(value.isNotBlank()) SheetText(value,Modifier.fillMaxWidth().then(if(details!=null) Modifier.clickable(role=Role.Button,onClick=details) else Modifier).padding(bottom=12.dp),style=LocalSheetType.current.trait)
    }
    SheetRule()
}
@Composable internal fun PlaySwitch(label: String,value: Boolean,editable: Boolean,change: (Boolean)->Unit) {
    Row(Modifier.fillMaxWidth().padding(8.dp),verticalAlignment=Alignment.CenterVertically) {
        SheetText(label,Modifier.weight(1f),style=LocalSheetType.current.label)
        Switch(value,change,enabled=editable,modifier=Modifier.semantics { contentDescription=label })
    }
}
@Composable internal fun PlayEntryHeader(title: String,editable: Boolean,details: ()->Unit,edit: (() -> Unit)?,remove: ()->Unit) {
    var menu by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.Top) {
        SheetText(title.ifBlank { "Unnamed entry" },Modifier.weight(1f).clickable(role=Role.Button,onClick=details).heightIn(min=48.dp).padding(8.dp),style=LocalSheetType.current.trait)
        if(editable) Box {
            IconButton(onClick={menu=true},modifier=Modifier.semantics { contentDescription="Options for $title" }) { SheetIcon(SheetSymbol.More) }
            DropdownMenu(menu,{menu=false}) {
                DropdownMenuItem(text={SheetText("Details")},onClick={menu=false;details()})
                if(edit!=null) DropdownMenuItem(text={SheetText("Edit")},onClick={menu=false;edit()})
                DropdownMenuItem(text={SheetText("Delete")},onClick={menu=false;remove()})
            }
        }
    }
}
