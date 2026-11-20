package ie.forsaken.sheet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import ie.chronicles.core.*
import ie.chronicles.ui.*
import ie.forsaken.rules.*

@Composable internal fun FormDescription(rules: ForsakenRules) {
    Column(Modifier.fillMaxWidth().padding(horizontal=8.dp,vertical=12.dp).semantics(mergeDescendants=true) {},
        verticalArrangement=Arrangement.spacedBy(4.dp)) {
        SheetText(rules.state.form.description,style=LocalSheetType.current.ratedTrait)
        val changes=attributeDefinitions.mapNotNull {
            val amount=rules.formModifier(it.id,rules.state.form)
            if(amount==0) null else "${it.name} ${if(amount>0) "+$amount" else "−${-amount}"}"
        }.joinToString(" · ")
        if(changes.isNotBlank()) SheetText(changes,style=MaterialTheme.typography.bodyMedium)
        SheetText(rules.state.form.notes,style=MaterialTheme.typography.bodyMedium,color=SheetColors.muted)
    }
    SheetRule()
}

@Composable internal fun AdvantagesTable(rules: ForsakenRules, conditions: (() -> Unit)?) {
    val scale=LocalDensity.current.fontScale.coerceAtLeast(1f)
    val rows=buildList<Pair<String,(Form)->String>> {
        add("Size" to { rules.size(it).toString() })
        add("Defense" to { rules.defense(it).toString() })
        rules.alternativeDefenseSkills.forEach { skill -> add("Def. (${traitTitle(skill)})" to { rules.defense(it,skill).toString() }) }
        add("Initiative" to { rules.initiative(it).toString() })
        add("Speed" to { rules.speed(it).toString() })
        add("Perception" to { "+${it.perceptionBonus}" })
        add("Armor" to { rules.armor(it).let { (general,ballistic) -> "$general/$ballistic" } })
        add("Brawl" to { rules.brawlPool(it).toString() })
        if(rules.state.skillRating("weaponry")>0) add("Weaponry" to { rules.weaponryPool(it)?.toString() ?: "—" })
        if(rules.state.skillRating("firearms")>0) add("Firearms" to { rules.firearmsPool(it)?.toString() ?: "—" })
    }
    val measurer=rememberTextMeasurer()
    val density=LocalDensity.current
    val labelWidth=with(density) { rows.maxOf { (label,_) -> measurer.measure(label,LocalSheetType.current.label).size.width }.toDp() }+8.dp
    BoxWithConstraints(Modifier.fillMaxWidth().padding(horizontal=8.dp,vertical=12.dp)) {
        val tableWidth=maxOf(maxWidth,labelWidth+250.dp*scale)
        // Keep every column legible at large text. Native horizontal scrolling exposes all five forms.
        Column(Modifier.horizontalScroll(rememberScrollState()).testTag("advantages-table")) {
            Column(Modifier.width(tableWidth),verticalArrangement=Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment=Alignment.CenterVertically) {
                    Spacer(Modifier.width(labelWidth))
                    Form.entries.forEach { form ->
                        Box(Modifier.weight(1f).background(if(form==rules.state.form) SheetColors.accent else Color.Transparent,CircleShape)
                            .padding(vertical=5.dp).clearAndSetSemantics {
                                contentDescription="Traits in ${form.title}"; selected=form==rules.state.form
                                stateDescription=rows.joinToString(". ") { (label,value) -> "$label ${value(form)}" }
                            },contentAlignment=Alignment.Center) {
                            SheetText(form.title,style=MaterialTheme.typography.bodySmall,color=if(form==rules.state.form) Color.White else SheetColors.accent)
                        }
                    }
                }
                rows.forEach { (label,value) ->
                    if(label=="Brawl") SheetRule()
                    Row(Modifier.fillMaxWidth().heightIn(min=40.dp*scale).semantics(mergeDescendants=true) {
                        contentDescription=label+": "+Form.entries.joinToString { "${it.title} ${value(it)}" }
                    },verticalAlignment=Alignment.CenterVertically) {
                        SheetText(label,Modifier.width(labelWidth),style=LocalSheetType.current.label)
                        Form.entries.forEach { form ->
                            SheetText(value(form),Modifier.weight(1f),textAlign=TextAlign.Center,
                                style=if(form==rules.state.form) LocalSheetType.current.ratedTrait else MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
            }
        }
    }
    if(conditions!=null) Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
        ConditionIndicator("Defense",conditions)
        SheetText("Conditions affecting Defense",style=MaterialTheme.typography.bodySmall,color=SheetColors.muted)
    }
    SheetRule()
}
