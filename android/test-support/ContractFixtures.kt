package ie.requiem.rules

import java.io.File
import kotlinx.serialization.json.*

/** Local tests cover this platform; only external I/O is limited to the shared plan. */
object ContractFixtures {
    val manifest: JsonObject = Json.parseToJsonElement(requireNotNull(javaClass.getResource("/contracts.json")).readText()).jsonObject
    val platform: JsonObject = manifest.getValue("platforms").jsonObject.getValue("android").jsonObject
    val scenarios: JsonObject = manifest.getValue("scenarios").jsonObject
    private fun supported(s: JsonObject, p: JsonObject): Boolean =
        (s["schema"] == JsonNull || s.getValue("schema").jsonPrimitive.int <= p.getValue("readSchema").jsonPrimitive.int) &&
            s.getValue("requires").jsonArray.all { it in p.getValue("capabilities").jsonArray }
    private val plan: JsonObject? = System.getProperty("contractPlan")?.let { Json.parseToJsonElement(File(it).readText()).jsonObject }
    fun selected(path: String): Boolean = plan?.getValue("scenarios")?.jsonArray?.contains(JsonPrimitive(path))
        ?: manifest.getValue("platforms").jsonObject.values.all { supported(scenarios.getValue(path).jsonObject, it.jsonObject) }
    fun names(role: String): List<String> = scenarios.filter { (_, s) ->
        JsonPrimitive(role) in s.jsonObject.getValue("roles").jsonArray && supported(s.jsonObject, platform)
    }.keys.map { it.removePrefix("characters/").removeSuffix(".json") }
    fun exchange(path: String): String? = System.getProperty("exchangeDir")?.takeIf { selected(path) }
    fun catalogKinds(): Set<String> = plan?.getValue("catalogKinds")?.jsonArray?.map { it.jsonPrimitive.content }?.toSet()
        ?: manifest.getValue("platforms").jsonObject.values.map { p -> p.jsonObject.getValue("catalogKinds").jsonArray.map { it.jsonPrimitive.content }.toSet() }.reduce(Set<String>::intersect)
    fun future(): ByteArray = """{"name":"Future save","schemaVersion":${CharacterSave().schemaVersion + 1},"unknownFutureState":{"retain":true}}""".toByteArray()
    fun rejectedFiles(): List<ByteArray> = listOf(future()) + scenarios.filter { (path, s) ->
        path.startsWith("characters/") && s.jsonObject.getValue("schema").jsonPrimitive.int > CharacterSave().schemaVersion
    }.keys.map { requireNotNull(javaClass.getResource("/$it")).readBytes() }
}
