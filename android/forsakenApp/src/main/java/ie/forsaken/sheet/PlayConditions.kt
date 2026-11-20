package ie.forsaken.sheet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ie.chronicles.core.*
import ie.chronicles.ui.*
import ie.forsaken.rules.*

@Composable internal fun PlayConditions(rules: ForsakenRules, editable: Boolean, navigate: (String)->Unit) {
    val conditions=rules.state.conditions
    if(conditions.isEmpty()) PlayNote("No Conditions")
    else {
        val pager=rememberPagerState { conditions.size }
        LaunchedEffect(conditions.map { it.id }) {
            if(pager.currentPage>conditions.lastIndex) pager.scrollToPage(conditions.lastIndex)
        }
        HorizontalPager(pager,key={conditions[it].id.toString()},contentPadding=PaddingValues(start=8.dp,end=48.dp),pageSpacing=12.dp,
            modifier=Modifier.fillMaxWidth().padding(top=8.dp).testTag("condition-carousel")) { index ->
            val row=conditions[index]; val entry=rules.catalog.entry(CatalogKind.conditions,row.source.catalog)
            Column(Modifier.fillMaxWidth().height(360.dp*LocalDensity.current.fontScale.coerceAtLeast(1f))
                .clip(RoundedCornerShape(10.dp)).border(1.dp,SheetColors.accent.copy(alpha=.4f),RoundedCornerShape(10.dp))
                .clickable(role=Role.Button,onClickLabel="Open full Condition card") { navigate("condition|${row.id}") }
                .semantics(mergeDescendants=true) {}.testTag("condition-card-${row.id}")) {
                PlayConditionTitle(row,rules)
                Column(Modifier.weight(1f).padding(12.dp),verticalArrangement=Arrangement.spacedBy(6.dp)) {
                    if(row.note.isNotBlank()) SheetText("${entry?.text("notePrompt") ?: "Note"}: ${row.note}",
                        style=LocalSheetType.current.label,maxLines=1,overflow=TextOverflow.Ellipsis)
                    SheetText(entry?.summary ?: row.customEffect,style=MaterialTheme.typography.bodyMedium,maxLines=4,overflow=TextOverflow.Ellipsis)
                    SheetText("Resolution: ${entry?.text("resolution") ?: row.customResolution}",style=MaterialTheme.typography.bodySmall,maxLines=2,overflow=TextOverflow.Ellipsis)
                    SheetText("Beat: ${(entry?.text("beat") ?: row.customBeat).ifEmpty { "n/a" }}",style=MaterialTheme.typography.bodySmall,maxLines=2,overflow=TextOverflow.Ellipsis)
                    Spacer(Modifier.weight(1f))
                    SheetText("Tap for the full card",style=MaterialTheme.typography.bodySmall,color=SheetColors.muted)
                }
            }
        }
        val page=pager.currentPage.coerceIn(conditions.indices)
        Box(Modifier.fillMaxWidth().padding(12.dp),contentAlignment=Alignment.Center) {
            SheetText("${page+1} of ${conditions.size}"+if(page<conditions.lastIndex) " · swipe for more" else "",
                style=MaterialTheme.typography.bodySmall,color=SheetColors.muted,modifier=Modifier.testTag("condition-position"))
        }
    }
    AddSheetRow("Add Condition",editable) { navigate("pick|condition") }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable private fun PlayConditionTitle(row: CharacterCondition,rules: ForsakenRules) {
    val entry=rules.catalog.entry(CatalogKind.conditions,row.source.catalog)
    FlowRow(Modifier.fillMaxWidth().background(SheetColors.accent).padding(12.dp),
        horizontalArrangement=Arrangement.spacedBy(8.dp),verticalArrangement=Arrangement.spacedBy(4.dp)) {
        SheetText(rules.catalog.name(CatalogKind.conditions,row.source).ifBlank { "Custom Condition" }.uppercase(),
            style=LocalSheetType.current.label.copy(fontSize=24.sp,lineHeight=30.sp),color=Color.White)
        if(entry?.flag("persistent") ?: row.customPersistent) SheetText("PERSISTENT",
            Modifier.border(1.dp,Color.White,CircleShape).padding(horizontal=6.dp,vertical=2.dp),style=MaterialTheme.typography.labelSmall,color=Color.White)
    }
}

@OptIn(ExperimentalMaterial3Api::class,ExperimentalLayoutApi::class)
@Composable internal fun PlayConditionCard(row: CharacterCondition,rules: ForsakenRules,actions: ForsakenActions,navigate: (String?)->Unit) {
    val entry=rules.catalog.entry(CatalogKind.conditions,row.source.catalog)
    val name=rules.catalog.name(CatalogKind.conditions,row.source)
    val groups=entry?.let(rules::noteOptionGroups).orEmpty().map { NoteGroup(it.title,it.options,it.warning) }
    fun update(change: (CharacterCondition)->CharacterCondition) {
        actions.change { s -> s.copy(conditions=s.conditions.map { if(it.id==row.id) change(it) else it }) }
    }
    ModalBottomSheet(onDismissRequest={navigate(null)},sheetState=rememberModalBottomSheetState(skipPartiallyExpanded=true),containerColor=Color.White) {
        Column(Modifier.fillMaxWidth().padding(horizontal=16.dp).imePadding()) {
            ModalHeading("Condition","Done") { navigate(null) }
            Column(Modifier.verticalScroll(rememberScrollState()).padding(bottom=24.dp).testTag("condition-full-card")) {
                Column(Modifier.clip(RoundedCornerShape(10.dp)).border(1.dp,SheetColors.accent.copy(alpha=.4f),RoundedCornerShape(10.dp))) {
                    PlayConditionTitle(row,rules)
                    Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
                        val prompt=entry?.text("notePrompt") ?: "Note"
                        if(groups.isNotEmpty()) {
                            ConditionNoteMenu(prompt,row.note,groups) { value -> update { it.copy(note=value) } }
                            ConditionNoteEffect(prompt,row.note,groups,entry?.source,rules.catalog.books)
                        } else OutlinedTextField(row.note,{value -> update { it.copy(note=value) }},label={SheetText(prompt)},
                            modifier=Modifier.fillMaxWidth().revealWhileEditing(row.note).testTag("condition-note"))
                        if(entry?.flag("counter")==true) CounterRow("Penalty",row.counter,true,row.counter>0,row.counter<99,
                            {delta -> update { it.copy(counter=(it.counter+delta).coerceIn(0,99)) } },
                            {navigate("conditionCounter|${row.id}")},valueBetweenButtons=true)
                        if(row.source.custom!=null) {
                            @Composable fun field(label: String,value: String,change: (CharacterCondition,String)->CharacterCondition) {
                                OutlinedTextField(value,{text -> update { change(it,text) }},label={SheetText(label)},minLines=if(label=="Name") 1 else 2,
                                    modifier=Modifier.fillMaxWidth().revealWhileEditing(value))
                            }
                            field("Name",row.source.custom.orEmpty()) { c,text -> c.copy(source=TraitSource(custom=text)) }
                            field("Effect",row.customEffect) { c,text -> c.copy(customEffect=text) }
                            field("Resolution",row.customResolution) { c,text -> c.copy(customResolution=text) }
                            field("Beat",row.customBeat) { c,text -> c.copy(customBeat=text) }
                            PlaySwitch("Persistent",row.customPersistent,true) { value -> update { it.copy(customPersistent=value) } }
                        } else {
                            SheetText(entry?.summary.orEmpty(),style=MaterialTheme.typography.bodyMedium)
                            PlayInfo("Resolution",entry?.text("resolution").orEmpty())
                        }
                        val beat=entry?.text("beat") ?: row.customBeat
                        PlayInfo("Beat",beat.ifEmpty { "n/a" })
                        if(beat.isNotBlank()) TextButton(onClick={actions.condition(row,ConditionEvent.beat)},modifier=Modifier.align(Alignment.End)
                            .testTag("condition-take-beat").semantics { contentDescription="Take Beat from $name" }) { SheetText("+ Beat") }
                        entry?.text("possibleSources")?.takeIf(String::isNotEmpty)?.let { SheetText("Possible sources: $it",style=MaterialTheme.typography.bodySmall,color=SheetColors.muted) }
                        if(entry!=null) SheetText(rules.catalog.citation(entry),style=MaterialTheme.typography.bodySmall,color=SheetColors.muted)
                        FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(onClick={navigate("endCondition|${row.id}")},modifier=Modifier.testTag("condition-end")
                                .semantics { contentDescription="End $name" }) { SheetText("End") }
                            Button(onClick={navigate("resolveCondition|${row.id}")},modifier=Modifier.testTag("condition-resolve")
                                .semantics { contentDescription="Resolve $name" }) {
                                SheetText(if(entry?.fields?.get("beatOnResolve")?.toString()!="false") "Resolve · +1 Beat" else "Resolve",color=Color.White)
                            }
                        }
                    }
                }
            }
        }
    }
}
