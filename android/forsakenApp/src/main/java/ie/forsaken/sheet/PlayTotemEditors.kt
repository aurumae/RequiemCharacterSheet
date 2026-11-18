package ie.forsaken.sheet

import androidx.compose.runtime.Composable
import ie.chronicles.core.*
import ie.forsaken.rules.*
import kotlinx.serialization.json.*

@Composable internal fun TotemDialog(parts: List<String>, rules: ForsakenRules, actions: ForsakenActions, navigate: (String?) -> Unit) {
    val type=parts.getOrNull(1).orEmpty(); val id=parts.getOrNull(2).orEmpty(); val c=rules.state
    val dismiss={navigate(null)}
    when(parts[0]) {
        "totemKind" -> ChoiceDialog("Add Advantage",TotemKind.entries.map { PlayOption(it.name,it.name.replaceFirstChar(Char::uppercaseChar),
            when(it) { TotemKind.attribute -> "4 Experiences per dot"; TotemKind.skill -> "2 Experiences per dot"; else -> "1 Experience per dot" }) },null,dismiss) {
            navigate(if(it=="merit") "pick|totemMerit" else "totemTarget|$it")
        }
        "totemTarget" -> {
            val definitions=if(type=="attribute") attributeDefinitions else modernSkillDefinitions
            ChoiceDialog("Totem ${type.replaceFirstChar(Char::uppercaseChar)}",definitions.map { PlayOption(it.id,it.name) },null,dismiss) { target ->
                if(type=="specialty") navigate("totemSpecialty|$target")
                else { actions.change { s ->
                    val kind=TotemKind.valueOf(type); val existing=s.totem.advantages.firstOrNull { it.kind==kind && it.target==target }
                    s.copy(totem=s.totem.copy(advantages=if(existing==null) s.totem.advantages+TotemAdvantage(kind,target)
                        else s.totem.advantages.map { if(it.id==existing.id) it.copy(dots=it.dots+1) else it }))
                }; dismiss() }
            }
        }
        "totemSpecialty" -> DraftDialog("Totem ${traitTitle(type)} Specialty",listOf(DraftField("Specialty")),dismiss) { input ->
            actions.change { s -> s.copy(totem=s.totem.copy(advantages=s.totem.advantages+TotemAdvantage(TotemKind.specialty,type,detail=input[0].trim()))) }
        }
        "totem" -> c.totem.advantages.firstOrNull { it.id.toString()==id }?.let { advantage ->
            if(advantage.kind==TotemKind.specialty) DraftDialog("Totem Specialty",listOf(DraftField("Specialty",advantage.detail)),dismiss) { input ->
                actions.change { s -> s.copy(totem=s.totem.copy(advantages=s.totem.advantages.map { if(it.id==advantage.id) it.copy(detail=input[0].trim()) else it })) }
            } else {
                val entry=rules.catalog.entry(CatalogKind.merits,advantage.target)
                val printed=entry?.array("ratings")?.map { it.jsonPrimitive.int }.orEmpty()
                val ratings=if(advantage.kind==TotemKind.merit && printed.isNotEmpty()) (printed.min()..printed.max()).toList() else (1..5).toList()
                ChoiceDialog("Totem ${if(advantage.kind==TotemKind.merit) entry?.name ?: advantage.target else traitTitle(advantage.target)}",
                    ratings.map { PlayOption(it.toString(),"$it ${if(it==1) "dot" else "dots"}") },advantage.dots.toString(),dismiss) { number ->
                    actions.change { s -> s.copy(totem=s.totem.copy(advantages=s.totem.advantages.map { if(it.id==advantage.id) it.copy(dots=number.toInt()) else it })) }; dismiss()
                }
            }
        }
    }
}

@Composable internal fun FavoredFormDialog(type: String, index: Int, rules: ForsakenRules, actions: ForsakenActions, navigate: (String?) -> Unit) {
    val c=rules.state; val form=rules.favoredForm?.first ?: return; val dismiss={navigate(null)}
    val existing=c.favoredForm.drawbacks.getOrNull(index) ?: FormDrawback()
    val options=listOf(PlayOption("","None"))+when(type) {
        "raised" -> attributeDefinitions.filter { (form.attributeModifiers[it.id] ?: 0)>=0 && it.id!=c.favoredForm.attributes.getOrNull(1-index) }.map { PlayOption(it.id,it.name) }
        "drawback" -> Form.entries.filter { it!=form }.map { PlayOption(it.name,it.title) }
        else -> attributeDefinitions.filter { it.category!=TraitCategory.Social }.map { PlayOption(it.id,it.name) }
    }
    val selected=when(type) { "raised" -> c.favoredForm.attributes.getOrNull(index); "drawback" -> existing.form?.name; else -> existing.attribute }.orEmpty()
    ChoiceDialog(when(type) { "raised" -> "Attribute raised in ${form.title}"; "drawback" -> "Drawback form"; else -> "Drawback Attribute" },options,selected,dismiss) { value ->
        actions.change { s ->
            if(type=="raised") {
                val all=s.favoredForm.attributes.toMutableList(); while(all.size<=index) all.add(null); all[index]=value.takeIf(String::isNotEmpty)
                s.copy(favoredForm=s.favoredForm.copy(attributes=all))
            } else {
                val all=s.favoredForm.drawbacks.toMutableList(); while(all.size<=index) all.add(FormDrawback())
                all[index]=if(type=="drawback") all[index].copy(form=Form.entries.firstOrNull { it.name==value }) else all[index].copy(attribute=value.takeIf(String::isNotEmpty))
                s.copy(favoredForm=s.favoredForm.copy(drawbacks=all))
            }
        }
        if(type=="drawback") navigate("favored|attribute|$index") else dismiss()
    }
}
