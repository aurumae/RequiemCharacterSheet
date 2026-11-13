package ie.requiem.rules

// Preserve the existing Requiem API; these models are owned by the JVM core.
typealias SaveId = ie.chronicles.core.SaveId
typealias SwiftUuidSerializer = ie.chronicles.core.SwiftUuidSerializer
typealias TraitSource = ie.chronicles.core.TraitSource
typealias Attribute = ie.chronicles.core.Attribute
typealias Skill = ie.chronicles.core.Skill
typealias Aspiration = ie.chronicles.core.Aspiration
typealias Merit = ie.chronicles.core.Merit
typealias Damage = ie.chronicles.core.Damage
typealias WillpowerMark = ie.chronicles.core.WillpowerMark
typealias CharacterCondition = ie.chronicles.core.CharacterCondition
typealias ConditionEvent = ie.chronicles.core.ConditionEvent
typealias TraitChange = ie.chronicles.core.TraitChange
typealias TraitCategory = ie.chronicles.core.TraitCategory
typealias TraitDefinition = ie.chronicles.core.TraitDefinition
typealias CatalogSection<T> = ie.chronicles.core.CatalogSection<T>
typealias SpecialtyChoice = ie.chronicles.core.SpecialtyChoice

val attributeDefinitions get() = ie.chronicles.core.attributeDefinitions
val skillDefinitions get() = ie.chronicles.core.modernSkillDefinitions
