package ie.forsaken.sheet

import androidx.compose.runtime.Composable
import ie.chronicles.core.*
import ie.forsaken.rules.*
import kotlinx.serialization.json.*
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable internal fun PlayDialogs(route: String, character: ForsakenCharacter, rules: ForsakenRules,
    actions: ForsakenActions, navigate: (String?) -> Unit) {
    val parts=route.split('|'); val type=parts.getOrNull(1).orEmpty(); val key=parts.getOrNull(2).orEmpty()
    val c=character.state; val catalog=actions.catalog
    val dismiss={navigate(null)}
    when(parts[0]) {
        "browse" -> CatalogBrowser(catalog,c.showsUnofficialContent,{navigate("details|$it")},dismiss)
        "details" -> catalog.resolve(type)?.let { CatalogDetails(it,catalog,dismiss) }
        "pick" -> PlayCatalogPicker(type,rules,Renown.entries.firstOrNull { it.name==key },choose={ choice ->
            val entry=choice.entry
            if(type in listOf("merit","totemMerit") && entry.objectValue("qualifier")!=null) navigate("qualifier|$type|${entry.id}|new")
            else { selectCatalog(type,choice,rules,actions); dismiss() }
        },custom={navigate("custom|$type")},clear=if(type in listOf("blood","bone","auspice","tribe","lodge","kuruth","moon")) ({
            actions.change { identity(it,type,if(type=="moon") null else TraitSource(custom="")) }; dismiss()
        }) else null,dismiss=dismiss)
        "custom" -> CustomEntryDialog(type,key,c,rules,actions,navigate)
        "qualifier" -> QualifierDialog(type,key,parts.getOrNull(3).orEmpty(),rules,actions,dismiss)
        "number" -> {
            val (value,range)=when(type) {
                "armor" -> c.armor to (0..99); "ballisticArmor" -> c.ballisticArmor to (0..99)
                "packPoints" -> c.totem.packPoints to (0..99); "essence" -> c.essence to (0..rules.essenceMaximum.coerceAtLeast(0))
                "beats" -> c.beats to (0..4); else -> c.experiences to (0..Int.MAX_VALUE)
            }
            val title=when(type) { "ballisticArmor" -> "Ballistic Armor"; "packPoints" -> "Pack's Totem points"; else -> type.replaceFirstChar(Char::uppercaseChar) }
            DraftDialog(title,listOf(DraftField("$title (${range.first}–${range.last})",value.toString(),numeric=true)),dismiss,
                valid={it[0].toIntOrNull()?.let(range::contains)==true}) { input ->
                val number=input[0].toInt()
                actions.change { when(type) {
                    "armor" -> it.copy(armor=number); "ballisticArmor" -> it.copy(ballisticArmor=number)
                    "packPoints" -> it.copy(totem=it.totem.copy(packPoints=number)); "essence" -> it.copy(essence=number)
                    "beats" -> it.copy(beats=number); else -> it.copy(experiences=number)
                } }
            }
        }
        "form" -> ChoiceDialog("Form",Form.entries.map { PlayOption(it.name,it.title,it.description) },c.form.name,dismiss) { name ->
            actions.change { it.copy(form=Form.valueOf(name)) }; dismiss()
        }
        "aspect" -> ChoiceDialog("Hunter's Aspect",rules.tribe?.array("huntersAspects").orEmpty().map {
            val obj=it.jsonObject; val name=obj["name"]?.jsonPrimitive?.content.orEmpty()
            PlayOption(name,name,catalog.entry(CatalogKind.conditions,obj["condition"]?.jsonPrimitive?.content)?.summary.orEmpty())
        },c.huntersAspect,dismiss) { name -> actions.change { it.copy(huntersAspect=name) }; dismiss() }
        "favored" -> FavoredFormDialog(type,key.toInt(),rules,actions,navigate)
        "specialty" -> {
            val index=key.toInt(); val previous=c.skills.firstOrNull { it.skill==type }?.specialties?.getOrNull(index).orEmpty()
            DraftDialog("${traitTitle(type)} Specialty",listOf(DraftField(if(index<0) "Specialty" else "Specialty (clear to remove)",previous)),dismiss,
                valid={index>=0 || it[0].isNotBlank()}) { input ->
                actions.specialty(type,index,previous,input[0])
            }
        }
        "asp" -> {
            val existing=c.aspirations.firstOrNull { it.id.toString()==type }
            DraftDialog("Aspiration",listOf(DraftField("Aspiration",existing?.text.orEmpty(),multiline=true)),dismiss,valid={true}) { input ->
                actions.change { it.copy(aspirations=if(existing==null) it.aspirations+Aspiration(input[0]) else it.aspirations.map { row -> if(row.id==existing.id) row.copy(text=input[0]) else row }) }
            }
        }
        "remove" -> PlayConfirm("Delete entry?","Paid dots are refunded in XP Mode. Deleting a Facet learned with Renown returns its free Facet credit.","Delete",dismiss) {
            if(type=="facet") c.facets.firstOrNull { it.id.toString()==key }?.let { actions.forget(it.id) }
            else actions.change { s -> when(type) {
                "merit" -> s.copy(merits=s.merits.filterNot { it.id.toString()==key })
                "extraMoon" -> s.copy(extraMoonGifts=s.extraMoonGifts.filterNot { it.id.toString()==key })
                "rite" -> s.copy(rites=s.rites.filterNot { it.id.toString()==key })
                "fetish" -> s.copy(fetishes=s.fetishes.filterNot { it.id.toString()==key })
                "asp" -> s.copy(aspirations=s.aspirations.filterNot { it.id.toString()==key })
                "totem" -> s.copy(totem=s.totem.copy(advantages=s.totem.advantages.filterNot { it.id.toString()==key }))
                else -> s
            } }
        }
        "totemKind","totemTarget","totemSpecialty","totem" -> TotemDialog(parts,rules,actions,navigate)
        "conditionNote" -> c.conditions.firstOrNull { it.id.toString()==type }?.let { row ->
            val entry=catalog.entry(CatalogKind.conditions,row.source.catalog)
            val choices=entry?.let(rules::noteOptionGroups).orEmpty().flatMap { group -> group.options.map {
                PlayOption(it.name,it.name,listOf(group.title,group.warning.orEmpty(),it.summary).filter(String::isNotEmpty).joinToString("\n"))
            } }+PlayOption("","None")
            ChoiceDialog(entry?.text("notePrompt") ?: "Note",choices,row.note,dismiss) { note ->
                actions.change { s -> s.copy(conditions=s.conditions.map { if(it.id==row.id) it.copy(note=note) else it }) }; dismiss()
            }
        }
        "conditionCounter" -> c.conditions.firstOrNull { it.id.toString()==type }?.let { row ->
            DraftDialog("Counter",listOf(DraftField("Counter (0–99)",row.counter.toString(),numeric=true)),dismiss,
                valid={it[0].toIntOrNull() in 0..99}) { input -> actions.change { s -> s.copy(conditions=s.conditions.map { if(it.id==row.id) it.copy(counter=input[0].toInt()) else it }) } }
        }
        "endCondition","resolveCondition" -> c.conditions.firstOrNull { it.id.toString()==type }?.let { row ->
            val resolve=parts[0]=="resolveCondition"; val entry=catalog.entry(CatalogKind.conditions,row.source.catalog)
            val name=catalog.name(CatalogKind.conditions,row.source)
            val awards=resolve && entry?.fields?.get("beatOnResolve")?.jsonPrimitive?.booleanOrNull!=false
            PlayConfirm("${if(resolve) "Resolve" else "End"} $name?",if(awards) "Remove the Condition and take a Beat." else "Remove the Condition without taking a Beat.",
                if(resolve) "Resolve" else "End",dismiss) { actions.condition(row,if(resolve) ConditionEvent.resolved else ConditionEvent.ended) }
        }
        "effects" -> PlayInformationDialog("Conditions affecting ${traitTitle(type)}",rules.conditionEffects(type).map { (row,text) ->
            catalog.name(CatalogKind.conditions,row.source) to text
        },dismiss)
        "log" -> {
            val names=rules.traitSnapshot()
            val formatter=DateTimeFormatter.ofPattern("d MMM yyyy, HH:mm").withZone(ZoneId.systemDefault())
            val lines=c.changeLog.asReversed().map { change ->
                val title=names[change.trait]?.name ?: change.name
                val event=change.event
                val detail=if(event!=null) event.name.replaceFirstChar(Char::uppercaseChar)+(change.beats?.let { " · $it Beat" } ?: "")
                    else "${change.from} → ${change.to} · "+when { change.experiences<0 -> "${experiencesText(-change.experiences)} refunded"
                        change.experiences>0 -> "${experiencesText(change.experiences)} spent"; else -> "Free" }
                title to (detail+"\n"+formatter.format(Instant.ofEpochMilli(((change.date+978307200)*1000).toLong()))+
                    if(change.duringCreation==true) " · Creation" else if(change.xpMode) " · XP Mode" else "")
            }
            PlayInformationDialog("Change log",lines.ifEmpty { listOf("" to "No changes yet") },dismiss)
        }
    }
}

internal fun identity(s: ForsakenState, type: String, source: TraitSource?): ForsakenState = when(type) {
    "blood" -> s.copy(blood=requireNotNull(source)); "bone" -> s.copy(bone=requireNotNull(source))
    "auspice" -> s.copy(auspice=requireNotNull(source)); "tribe" -> s.copy(tribe=requireNotNull(source))
    "lodge" -> s.copy(lodge=requireNotNull(source)); "kuruth" -> s.copy(kuruthTriggerSet=requireNotNull(source))
    "moon" -> s.copy(moonGift=source); else -> s
}

internal fun selectCatalog(type: String, choice: PlayPick, rules: ForsakenRules, actions: ForsakenActions, qualifier: String?=null) {
    val entry=choice.entry; val source=TraitSource(catalog=entry.id)
    when(type) {
        "free","shadow","wolf" -> choice.facet?.let(actions::learn)
        "condition" -> actions.condition(CharacterCondition(source),ConditionEvent.added)
        else -> actions.change { s -> when(type) {
            "merit" -> s.copy(merits=s.merits+Merit(source,qualifier,entry.array("ratings").map { it.jsonPrimitive.int }.minOrNull() ?: 1))
            "totemMerit" -> s.copy(totem=s.totem.copy(advantages=s.totem.advantages+TotemAdvantage(TotemKind.merit,entry.id,
                detail=qualifier.orEmpty(),dots=entry.array("ratings").map { it.jsonPrimitive.int }.minOrNull() ?: 1)))
            "extraMoon" -> s.copy(extraMoonGifts=s.extraMoonGifts+OwnedMoonGift(source))
            "rite" -> s.copy(rites=s.rites+OwnedRite(source)); "fetish" -> s.copy(fetishes=s.fetishes+OwnedFetish(source))
            "moon" -> identity(s,type,source.takeUnless { entry.text("auspice")==rules.effectiveAuspice?.id })
            else -> identity(s,type,source)
        } }
    }
}
