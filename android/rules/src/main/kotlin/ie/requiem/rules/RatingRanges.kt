package ie.requiem.rules

enum class RatingKind(val minimum: Int) { Attribute(1), Skill(0) }

/** Base-dot choices: bonuses do not increase the purchasable cap. */
fun legalRatings(kind: RatingKind, bloodPotency: Int): IntRange = kind.minimum..bloodPotency.coerceIn(5, 10)
