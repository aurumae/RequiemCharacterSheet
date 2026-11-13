package ie.requiem.rules

import org.junit.Assert.*
import org.junit.Test

class RatingRangesTest {
    @Test fun attributeAndSkillMenusFollowBloodPotencyWithoutOfferingBonusDots() {
        for ((potency, cap) in listOf(-1 to 5, 0 to 5, 1 to 5, 5 to 5, 6 to 6, 9 to 9, 10 to 10, 11 to 10)) {
            assertEquals(1..cap, legalRatings(RatingKind.Attribute, potency))
            assertEquals(0..cap, legalRatings(RatingKind.Skill, potency))
            val c = CharacterSave(bloodPotency = potency)
            assertEquals(cap, c.staminaCap)
        }
    }
}
