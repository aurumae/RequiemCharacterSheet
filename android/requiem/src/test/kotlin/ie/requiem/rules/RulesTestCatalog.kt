package ie.requiem.rules

import kotlinx.serialization.json.*

/**
 * Small, fixed inputs for rule-engine tests, independent of the shipped books.
 * Familiar IDs keep existing assertions readable; these deliberately incomplete examples
 * are not book data. Change them to exercise a mechanic, never to follow a catalog correction.
 * Contract/exchange tests continue to load the authoritative bundled catalogs.
 */
internal fun rulesTestCatalog(): Catalog {
    fun book(id: String, name: String, body: String): String {
        val entries = Json.parseToJsonElement(body).jsonObject.mapValues { (_, rows) ->
            JsonArray(rows.jsonArray.map { row ->
                JsonObject(row.jsonObject + ("source" to buildJsonObject { put("book", id) }))
            })
        }
        return JsonObject(entries + mapOf(
            "format" to JsonPrimitive("requiem-catalog"), "version" to JsonPrimitive(1),
            "book" to buildJsonObject { put("id", id); put("name", name) },
        )).toString()
    }
    return Catalog(mapOf(
        "vtr2e-core.json" to book("sample-core", "Test Core", """{
          "clans": [
            {"id":"daeva","name":"Daeva","favoredAttributes":["dexterity","manipulation"],"disciplines":["celerity","majesty","vigor"],"bane":{"name":"Daeva bane","humanityThreshold":6}},
            {"id":"gangrel","name":"Gangrel","favoredAttributes":["stamina","composure"],"bane":{"name":"Gangrel bane","humanityThreshold":6}},
            {"id":"nosferatu","name":"Nosferatu","favoredAttributes":["strength","composure"],"bane":{"name":"Nosferatu bane","humanityThreshold":6}},
            {"id":"mekhet","name":"Mekhet","favoredAttributes":["intelligence","wits"],"disciplines":["auspex","celerity","obfuscate"],"bane":{"name":"Mekhet bane","humanityThreshold":6,"grantsExtraBane":true}},
            {"id":"ventrue","name":"Ventrue","favoredAttributes":["presence","resolve"],"disciplines":["animalism","dominate","resilience"],"bane":{"name":"Ventrue bane","humanityThreshold":6,"firstTouchstoneHumanity":7}},
            {"id":"dukhan","name":"Dukhan","meritAccess":[{"merits":["dream-visions"],"inPlaceOf":"mekhet"}]}
          ],
          "bloodlines": [
            {"id":"morbus","name":"Morbus","parentClans":["mekhet"],"disciplines":["auspex","celerity","cachexy","obfuscate"],"bane":{"name":"The Unclean Curse"}},
            {"id":"bron","name":"Bron","parentClans":["ventrue"],"disciplines":["animalism","crochan","dominate","resilience"],"favoredAttributes":["stamina","presence"]},
            {"id":"icelus","name":"Icelus","parentClans":["mekhet","ventrue"],"meritAccess":[{"merits":["dream-visions"],"inPlaceOf":"mekhet"}]},
            {"id":"penumbrae","name":"Penumbrae","parentClans":[],"requiredCovenant":"circle-of-the-crone"}
          ],
          "elderBanes": [
            {"id":"captivating-curse","name":"The Captivating Curse","clan":"daeva","humanityThreshold":3},
            {"id":"visceral-curse","name":"The Visceral Curse","clan":"gangrel","humanityThreshold":3}
          ],
          "covenants": [
            {"id":"carthian-movement","name":"Carthian Movement"},
            {"id":"circle-of-the-crone","name":"Circle of the Crone"},
            {"id":"invictus","name":"Invictus"},
            {"id":"lancea-et-sanctum","name":"Lancea et Sanctum"},
            {"id":"ordo-dracul","name":"Ordo Dracul"},
            {"id":"legion-of-the-green","name":"Legion of the Green","statusCountsAs":"invictus"},
            {"id":"circles-of-mor","name":"Circles of Mor","statusCountsAs":"circle-of-the-crone"},
            {"id":"ahl-al-mumit","name":"Ahl al-Mumit","teaches":["theban-sorcery"]},
            {"id":"firawn","name":"Fir'awn","teaches":["cruac"],"meritGroups":[{"merits":["altar"],"inPlaceOf":"circle-of-the-crone"}]},
            {"id":"jaliniyya","name":"Jaliniyya"},
            {"id":"tenth-choir","name":"Tenth Choir"},
            {"id":"belials-brood","name":"Belial's Brood"},
            {"id":"gallows-post","name":"Gallows Post","meritGroups":[{"group":"carthian-law","inPlaceOf":"carthian-movement"},{"merits":["carthian-pull","jack-booted-thug"],"inPlaceOf":"carthian-movement"}]}
          ],
          "disciplines": [
            {"id":"animalism","name":"Animalism"}, {"id":"auspex","name":"Auspex"},
            {"id":"dominate","name":"Dominate"}, {"id":"obfuscate","name":"Obfuscate"},
            {"id":"crochan","name":"Crochan"}, {"id":"majesty","name":"Majesty"},
            {"id":"cachexy","name":"Cachexy","bloodline":"morbus"},
            {"id":"celerity","name":"Celerity","effects":[{"type":"defense","amount":"rating"}]},
            {"id":"vigor","name":"Vigor","effects":[{"type":"attribute","attribute":"strength","amount":"rating"}]},
            {"id":"resilience","name":"Resilience","effects":[{"type":"attribute","attribute":"stamina","amount":"rating"}]},
            {"id":"praestantia","name":"Praestantia","effects":[{"type":"attributeRolls","attribute":"dexterity","amount":"rating"},{"type":"initiative","amount":"rating"}]},
            {"id":"cruac","name":"Crúac","kind":"ritual","ritualRules":{"covenant":"circle-of-the-crone","covenantStatusMinimum":1,"humanity":"capAtTenMinusDots","castingCost":{"vitae":"varies"}}},
            {"id":"theban-sorcery","name":"Theban Sorcery","kind":"ritual","ritualRules":{"covenant":"lancea-et-sanctum","covenantStatusMinimum":1,"humanity":"atLeastRitualDots"}},
            {"id":"kimiya","name":"Kimiya","kind":"ritual","ritualRules":{"covenant":"jaliniyya","covenantStatusMinimum":1,"humanity":"none"}},
            {"id":"therion","name":"Therion","kind":"ritual","ritualRules":{"covenant":"tenth-choir","covenantStatusMinimum":1,"humanity":"breakingPointAtSixMinusDots"}},
            {"id":"triadic-evolution","name":"Triadic Evolution","kind":"ritual","ritualRules":{"covenant":"belials-brood","covenantStatusMinimum":0,"humanity":"none"}}
          ],
          "merits": [
            {"id":"fast-reflexes","name":"Fast Reflexes","ratings":[1,2,3],"prerequisitesAnyOf":[[{"kind":"attribute","id":"wits","minimum":3}],[{"kind":"attribute","id":"dexterity","minimum":3}]]},
            {"id":"anonymity","name":"Anonymity","ratings":[1,2,3,4,5],"prerequisites":[{"kind":"other","text":"Advisory prerequisite"}]},
            {"id":"giant","name":"Giant","ratings":[3],"effects":[{"type":"size","amount":{"fixed":1}}]},
            {"id":"defensive-combat","name":"Defensive Combat","ratings":[1],"qualifier":{"prompt":"Skill","options":["Brawl","Weaponry"]},"effects":[{"type":"defenseSkillFromQualifier"}]},
            {"id":"covenant-status","name":"Covenant Status","ratings":[1,2,3,4,5],"repeatable":true,"qualifier":{"prompt":"Covenant","fromCovenants":true}},
            {"id":"language","name":"Language","ratings":[1],"repeatable":true,"qualifier":{"prompt":"Language"}},
            {"id":"resources","name":"Resources","ratings":[1,2,3,4,5]},
            {"id":"telepathy","name":"Telepathy","ratings":[3,5],"unavailableToKindred":true},
            {"id":"iron-skin","name":"Iron Skin","ratings":[2,4],"prerequisites":[{"kind":"attribute","id":"stamina","minimum":3}],"prerequisitesAnyOf":[[{"kind":"merit","id":"martial-arts","minimum":2}],[{"kind":"merit","id":"street-fighting","minimum":2}]]},
            {"id":"street-fighting","name":"Street Fighting","ratings":[1,2,3,4,5],"prerequisites":[{"kind":"attribute","id":"stamina","minimum":3},{"kind":"attribute","id":"composure","minimum":3},{"kind":"skill","id":"brawl","minimum":2},{"kind":"skill","id":"streetwise","minimum":2}]},
            {"id":"altar","name":"Altar","category":"vampire","ratings":[3],"prerequisites":[{"kind":"covenant","id":"circle-of-the-crone","minimum":1}]},
            {"id":"attache","name":"Attaché","ratings":[1],"prerequisites":[{"kind":"covenant","id":"invictus","minimum":1}]},
            {"id":"carthian-pull","name":"Carthian Pull","ratings":[1],"prerequisites":[{"kind":"covenant","id":"carthian-movement","minimum":1}]},
            {"id":"jack-booted-thug","name":"Jack-Booted Thug","ratings":[1],"prerequisites":[{"kind":"covenant","id":"carthian-movement","minimum":2}]},
            {"id":"mother-daughter-bond","name":"The Mother-Daughter Bond","ratings":[1],"prerequisites":[{"kind":"covenant","id":"circle-of-the-crone","minimum":1}]},
            {"id":"dream-visions","name":"Dream Visions","ratings":[1],"prerequisites":[{"kind":"clan","id":"mekhet"}]},
            {"id":"kiss-of-the-succubus","name":"Kiss of the Succubus","ratings":[1],"prerequisites":[{"kind":"clan","id":"daeva"}]},
            {"id":"psychognosis","name":"Psychognosis","ratings":[1,2,3,4,5],"prerequisites":[{"kind":"bloodline","id":"icelus"},{"kind":"other","text":"Psychology Specialty"}]},
            {"id":"area-of-expertise","name":"Area of Expertise","ratings":[1],"qualifier":{"prompt":"Specialty","fromSpecialties":true}},
            {"id":"herd","name":"Herd","ratings":[1,2,3,4,5]},
            {"id":"flock","name":"Flock","ratings":[1,2,3,4,5],"prerequisites":[{"kind":"other","text":"An advisory prerequisite"}],"effects":[{"type":"merit","merit":"herd","amount":"rating"}]},
            {"id":"casual-user","name":"Casual User","ratings":[2],"prerequisites":[{"kind":"notCovenant","id":"carthian-movement"}]},
            {"id":"mobilize-outrage","name":"Mobilize Outrage","ratings":[1,2,3],"prerequisites":[{"kind":"willpower","minimum":5}]},
            {"id":"breaking-the-chains","name":"Breaking the Chains","ratings":[1],"group":"carthian-law","prerequisites":[{"kind":"covenant","id":"carthian-movement","minimum":1}]},
            {"id":"cease-fire","name":"Cease Fire","ratings":[5],"group":"carthian-law","prerequisites":[{"kind":"covenant","id":"carthian-movement","minimum":5}]}
          ],
          "rituals": [
            {"id":"stigmata","name":"Stigmata","discipline":"theban-sorcery","dots":4},
            {"id":"rigor-mortis","name":"Rigor Mortis","discipline":"cruac","dots":1},
            {"id":"pangs-of-proserpina","name":"Pangs of Proserpina","discipline":"cruac","dots":1},
            {"id":"cheval","name":"Cheval","discipline":"cruac","dots":2}
          ],
          "devotions": [
            {"id":"body-of-will","name":"Body of Will","experienceCost":2,"dicePool":{"attribute":"stamina","skill":"survival","discipline":"resilience"}},
            {"id":"infectious-bite","name":"Infectious Bite","experienceCost":0},
            {"id":"city-attunement","name":"City Attunement","experienceCost":0}
          ],
          "mysteries": [
            {"id":"mystery-of-the-wyrm","name":"Mystery of the Wyrm","coil":{"name":"Coil of the Wyrm"}},
            {"id":"mystery-of-the-voivode","name":"Mystery of the Voivode","coil":{"name":"Coil of the Voivode"}},
            {"id":"coil-of-the-quintessence","name":"Coil of the Quintessence","coilOnly":true,"partOfMystery":"mystery-of-the-voivode"}
          ],
          "scales": [
            {"id":"kindred-sense-endowment","name":"Kindred Sense Endowment","prerequisiteCoils":[{"mystery":"mystery-of-the-wyrm","dots":2}]},
            {"id":"day-wake-conditioning","name":"Day-Wake Conditioning"},
            {"id":"spirit-tether","name":"Spirit Tether","anyCoil":2}
          ],
          "conditions": [
            {"id":"charmed","name":"Charmed","beat":"Take a Beat for this example."},
            {"id":"swooning","name":"Swooning","repeatable":true},
            {"id":"tempted","name":"Tempted","counter":true},
            {"id":"distracted","name":"Distracted","beatOnResolve":false},
            {"id":"stumbled","name":"Stumbled","beatOnResolve":false},
            {"id":"broken","name":"Broken","affects":[{"targets":["attribute:resolve","skillCategory:social"],"text":"Advisory penalty"}]},
            {"id":"deprived","name":"Deprived","affects":[{"targets":["attribute:resolve"],"text":"Another advisory penalty"}]},
            {"id":"confused","name":"Confused","affects":[{"targets":["attribute:wits"],"text":"Advisory Wits penalty"}]}
          ]
        }"""),
        "sample-covenants.json" to book("secrets-of-the-covenants", "Secrets of the Covenants", """{
          "mysteries":[{"id":"coil-of-ziva","name":"Coil of Ziva","coilOnly":true}],
          "conditions":[{"id":"primeval-truths","name":"Primeval Truths"}]
        }"""),
    ))
}
