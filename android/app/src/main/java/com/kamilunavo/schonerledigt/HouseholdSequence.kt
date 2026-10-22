package com.kamilunavo.schonerledigt

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.Locale
import java.util.UUID

data class SequenceCardState(val id: String, val title: String, val confirmationToken: String?, val confirmationOrder: Double?, val confirmedAt: Long? = null)
data class SequenceStep(val routineID: String, val title: String)
data class SequenceHandover(val id: String = UUID.randomUUID().toString(), val date: Long, val from: String?, val to: String, val note: String, val pendingIDs: List<String>)
data class SequenceRoundRecord(val id: String = UUID.randomUUID().toString(), val name: String, val startedAt: Long, val endedAt: Long, val responsiblePerson: String?, val steps: List<SequenceStep>, val completedIDs: List<String>, val handovers: List<SequenceHandover>) {
    val pendingIDs get() = steps.drop(completedIDs.size).map { it.routineID }
}
data class HouseholdSequence(
    val id: String = UUID.randomUUID().toString(), val name: String, val steps: List<SequenceStep>, val people: List<String>,
    val rotationIndex: Int = 0, val startedAt: Long, val baselineTokens: Map<String,String>, val ownerOverride: String? = null,
    val handovers: List<SequenceHandover> = emptyList(), val rounds: List<SequenceRoundRecord> = emptyList(),
) {
    companion object {
        fun create(name: String, steps: List<SequenceStep>, people: List<String>, cards: List<SequenceCardState>, at: Long): HouseholdSequence {
            val value = HouseholdSequence(name = name.trim(), steps = steps.toList(), people = people.map { it.trim() }, startedAt = at,
                baselineTokens = steps.associate { step -> step.routineID to (cards.firstOrNull { it.id == step.routineID }?.confirmationToken ?: "") })
            value.validate(); return value
        }
    }
    val responsiblePerson: String? get() = ownerOverride ?: people.getOrNull(rotationIndex)
    fun progress(cards: List<SequenceCardState>): Int {
        var count = 0; var previousOrder: Double? = null
        for (step in steps) {
            val card = cards.firstOrNull { it.id == step.routineID } ?: break
            val token = card.confirmationToken ?: break
            val confirmedAt = card.confirmedAt ?: break
            if (confirmedAt <= startedAt) break
            val order = card.confirmationOrder ?: break
            if (token.isEmpty() || token == baselineTokens[step.routineID] || !order.isFinite() || previousOrder?.let { order <= it } == true) break
            count++; previousOrder = order
        }
        return count
    }
    fun eligibleStepID(cards: List<SequenceCardState>): String? {
        val next = steps.getOrNull(progress(cards)) ?: return null
        return next.routineID.takeIf { id -> cards.any { it.id == id } }
    }
    fun handover(to: String, note: String, cards: List<SequenceCardState>, at: Long): HouseholdSequence {
        require(to.isNotBlank() && progress(cards) < steps.size && at >= startedAt)
        return copy(ownerOverride = to.trim(), handovers = handovers + SequenceHandover(date = at, from = responsiblePerson,
            to = to.trim(), note = note.trim(), pendingIDs = steps.drop(progress(cards)).map { it.routineID }))
    }
    fun nextRound(cards: List<SequenceCardState>, at: Long): HouseholdSequence {
        require(progress(cards) == steps.size && at >= startedAt)
        return copy(rounds = rounds + record(cards,at), rotationIndex = if (people.isEmpty()) 0 else (rotationIndex + 1) % people.size,
            ownerOverride = null, handovers = emptyList(), startedAt = at,
            baselineTokens = steps.associate { step -> step.routineID to (cards.firstOrNull { it.id == step.routineID }?.confirmationToken ?: "") })
    }
    fun reconfigure(name: String, steps: List<SequenceStep>, people: List<String>, cards: List<SequenceCardState>, at: Long): HouseholdSequence {
        require(at >= startedAt)
        return create(name,steps,people,cards,at).copy(id = id, rounds = rounds + record(cards,at))
    }
    private fun record(cards: List<SequenceCardState>, at: Long) = SequenceRoundRecord(name = name, startedAt = startedAt, endedAt = at,
        responsiblePerson = responsiblePerson, steps = steps, completedIDs = steps.take(progress(cards)).map { it.routineID }, handovers = handovers)
    internal fun validate() {
        require(validUUID(id) && name.isNotBlank() && validSteps(steps))
        require(people.all { it.isNotBlank() } && people.map { it.lowercase(Locale.ROOT) }.toSet().size == people.size)
        require(rotationIndex >= 0 && rotationIndex < maxOf(people.size,1) && baselineTokens.keys == steps.map { it.routineID }.toSet())
        require(ownerOverride == null || ownerOverride.isNotBlank())
        require(validHandovers(handovers,steps,startedAt,null) && rounds.map { it.id }.toSet().size == rounds.size)
        rounds.forEach { round ->
            require(validUUID(round.id) && round.name.isNotBlank() && round.endedAt >= round.startedAt && validSteps(round.steps))
            require(round.completedIDs.size <= round.steps.size && round.completedIDs == round.steps.take(round.completedIDs.size).map { it.routineID })
            require(validHandovers(round.handovers,round.steps,round.startedAt,round.endedAt))
        }
    }
}
private fun validUUID(value: String) = runCatching { UUID.fromString(value).toString().equals(value,true) }.getOrDefault(false)
private fun validSteps(steps: List<SequenceStep>) = steps.isNotEmpty() && steps.all { validUUID(it.routineID) && it.title.isNotBlank() } && steps.map { it.routineID }.toSet().size == steps.size
private fun validHandovers(values: List<SequenceHandover>, steps: List<SequenceStep>, start: Long, end: Long?) =
    values.map { it.id }.toSet().size == values.size && values.all {
        validUUID(it.id) && it.date >= start && (end == null || it.date <= end) && it.to.isNotBlank() &&
            it.pendingIDs.isNotEmpty() && it.pendingIDs.size <= steps.size && it.pendingIDs == steps.takeLast(it.pendingIDs.size).map { step -> step.routineID }
    }

class SequenceArchive(val file: File) {
    fun load(): List<HouseholdSequence> {
        if (!file.exists()) return emptyList()
        val root = JsonParser.parseString(file.readText(Charsets.UTF_8))
        val array = if (root.isJsonArray) root.asJsonArray else root.asJsonObject.let {
            require(it.number("schemaVersion") == 1L) { "Unsupported sequence archive" }
            it.getAsJsonArray("sequences") ?: error("Missing sequences")
        }
        val values = array.map { element -> decodeSequence(element.asJsonObject) }
        validate(values); return values
    }
    fun save(values: List<HouseholdSequence>) {
        load(); validate(values)
        val document = JsonObject().apply {
            addProperty("schemaVersion",1)
            add("sequences", JsonArray().apply { values.forEach { add(it.json()) } })
        }
        val parent = file.absoluteFile.parentFile ?: error("Missing storage directory")
        require(parent.isDirectory || parent.mkdirs())
        val temporary = File.createTempFile("sequences-",".tmp",parent)
        try {
            FileOutputStream(temporary).use { it.write(document.toString().toByteArray(Charsets.UTF_8)); it.fd.sync() }
            Files.move(temporary.toPath(),file.toPath(),StandardCopyOption.ATOMIC_MOVE,StandardCopyOption.REPLACE_EXISTING)
        } finally { temporary.delete() }
    }
    private fun validate(values: List<HouseholdSequence>) {
        require(values.map { it.id }.toSet().size == values.size); values.forEach { it.validate() }
    }
}
class SequenceStore(file: File) {
    private val archive = SequenceArchive(file)
    var sequences by mutableStateOf<List<HouseholdSequence>>(emptyList()); private set
    var loadFailed by mutableStateOf(false); private set
    var error by mutableStateOf<String?>(null)
    init { reload() }
    fun reload() {
        try { sequences = archive.load(); loadFailed = false; error = null }
        catch (_: Exception) { loadFailed = true; error = "load" }
    }
    fun commit(values: List<HouseholdSequence>): Boolean {
        if (loadFailed) { error = "load"; return false }
        return try { archive.save(values); sequences = values.toList(); error = null; true }
        catch (_: Exception) { error = "save"; false }
    }
}

private fun SequenceStep.json() = JsonObject().apply { addProperty("routineID",routineID); addProperty("title",title) }
private fun SequenceHandover.json() = JsonObject().apply {
    addProperty("id",id); addProperty("date",date); if (from != null) addProperty("from",from)
    addProperty("to",to); addProperty("note",note); add("pendingIDs",pendingIDs.jsonStrings())
}
private fun SequenceRoundRecord.json() = JsonObject().apply {
    addProperty("id",id); addProperty("name",name); addProperty("startedAt",startedAt); addProperty("endedAt",endedAt)
    if (responsiblePerson != null) addProperty("responsiblePerson",responsiblePerson)
    add("steps",JsonArray().apply { steps.forEach { add(it.json()) } }); add("completedIDs",completedIDs.jsonStrings())
    add("handovers",JsonArray().apply { handovers.forEach { add(it.json()) } })
}
private fun HouseholdSequence.json() = JsonObject().apply {
    addProperty("id",id); addProperty("name",name); addProperty("rotationIndex",rotationIndex); addProperty("startedAt",startedAt)
    if (ownerOverride != null) addProperty("ownerOverride",ownerOverride)
    add("people",people.jsonStrings()); add("baselineTokens",JsonObject().apply { baselineTokens.forEach { (key,value) -> addProperty(key,value) } })
    add("steps",JsonArray().apply { steps.forEach { add(it.json()) } })
    add("handovers",JsonArray().apply { handovers.forEach { add(it.json()) } }); add("rounds",JsonArray().apply { rounds.forEach { add(it.json()) } })
}
private fun decodeSteps(item: JsonObject) = item.getAsJsonArray("steps").map { it.asJsonObject.let { step -> SequenceStep(step.text("routineID"),step.text("title")) } }
private fun decodeHandover(item: JsonObject) = SequenceHandover(item.text("id"),item.number("date"),item.optionalText("from"),item.text("to"),item.text("note"),item.strings("pendingIDs"))
private fun decodeRound(item: JsonObject) = SequenceRoundRecord(item.text("id"),item.text("name"),item.number("startedAt"),item.number("endedAt"),item.optionalText("responsiblePerson"),decodeSteps(item),item.strings("completedIDs"),item.getAsJsonArray("handovers").map { decodeHandover(it.asJsonObject) })
private fun decodeSequence(item: JsonObject): HouseholdSequence {
    val rotation = item.number("rotationIndex"); require(rotation >= 0 && rotation <= Int.MAX_VALUE.toLong())
    val baselines = item.getAsJsonObject("baselineTokens").entrySet().associate { (key,value) -> key to value.stringValue() }
    return HouseholdSequence(item.text("id"),item.text("name"),decodeSteps(item),item.strings("people"),rotation.toInt(),item.number("startedAt"),baselines,item.optionalText("ownerOverride"),
        item.getAsJsonArray("handovers").map { decodeHandover(it.asJsonObject) }, item.getAsJsonArray("rounds").map { decodeRound(it.asJsonObject) })
}
private fun List<String>.jsonStrings() = JsonArray().apply { this@jsonStrings.forEach { add(it) } }
private fun JsonElement.stringValue(): String { require(isJsonPrimitive && asJsonPrimitive.isString); return asString }
private fun JsonObject.text(key: String) = (get(key) ?: error("Missing $key")).stringValue()
private fun JsonObject.optionalText(key: String): String? = get(key)?.let { if (it.isJsonNull) null else it.stringValue() }
private fun JsonObject.strings(key: String) = getAsJsonArray(key).map { it.stringValue() }
private fun JsonObject.number(key: String): Long {
    val value = get(key); require(value != null && value.isJsonPrimitive && value.asJsonPrimitive.isNumber)
    return value.asBigDecimal.longValueExact()
}
