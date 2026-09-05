package com.kamilunavo.schonerledigt

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

enum class ResetRule(val hours: Int?) { Manual(null), FourHours(4), EightHours(8), DailyMidnight(0), DailyMorning(-6) }

data class Routine(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val detail: String = "",
    val icon: String = "check",
    val tint: Long = 0xFF6C63FF,
    val reset: ResetRule = ResetRule.DailyMidnight,
    val completedAt: Long? = null,
    val resetAt: Long? = null
)

data class HistoryEntry(
    val id: String = UUID.randomUUID().toString(),
    val routineTitle: String,
    val completedAt: Long,
    val photoUri: String? = null
)

class RoutineStore(context: Context) {
    private val prefs = context.getSharedPreferences("schon_erledigt_data", Context.MODE_PRIVATE)
    var onboarding: Boolean
        get() = prefs.getBoolean("onboarding", false)
        set(value) = prefs.edit().putBoolean("onboarding", value).apply()
    var reminders: Boolean
        get() = prefs.getBoolean("reminders", false)
        set(value) = prefs.edit().putBoolean("reminders", value).apply()
    var profileName: String
        get() = prefs.getString("name", "").orEmpty()
        set(value) = prefs.edit().putString("name", value).apply()

    fun routines(): List<Routine> {
        val stored = runCatching { JSONArray(prefs.getString("routines", "[]")) }.getOrDefault(JSONArray())
        val parsed = (0 until stored.length()).mapNotNull { stored.optJSONObject(it)?.toRoutine() }
        if (parsed.isNotEmpty() || prefs.contains("seeded")) return reopenDue(parsed)
        val samples = listOf(
            Routine(title = if (de()) "Haustür abgeschlossen" else "Front door locked", detail = if (de()) "Vor dem Schlafengehen" else "Before bedtime", icon = "lock"),
            Routine(title = if (de()) "Herd ausgeschaltet" else "Stove turned off", detail = if (de()) "Nach dem Kochen" else "After cooking", icon = "flame", tint = 0xFFFF6B57),
            Routine(title = if (de()) "Medikamente genommen" else "Medication taken", detail = if (de()) "Morgens" else "In the morning", icon = "pill", tint = 0xFF28BFA3, reset = ResetRule.DailyMorning)
        )
        prefs.edit().putBoolean("seeded", true).apply(); saveRoutines(samples); return samples
    }

    fun history(): List<HistoryEntry> {
        val data = runCatching { JSONArray(prefs.getString("history", "[]")) }.getOrDefault(JSONArray())
        return (0 until data.length()).mapNotNull { data.optJSONObject(it)?.let { value -> HistoryEntry(value.optString("id"), value.optString("title"), value.optLong("at"), value.optString("photo").takeIf(String::isNotBlank)) } }.sortedByDescending { it.completedAt }
    }

    fun save(routine: Routine) { val values = routines().toMutableList(); val index = values.indexOfFirst { it.id == routine.id }; if (index >= 0) values[index] = routine else values.add(routine); saveRoutines(values) }
    fun delete(id: String) = saveRoutines(routines().filterNot { it.id == id })
    fun complete(id: String, photoUri: String? = null) {
        val now = System.currentTimeMillis(); val values = routines().map { if (it.id == id) it.copy(completedAt = now, resetAt = resetTime(now, it.reset)) else it }
        val title = values.firstOrNull { it.id == id }?.title ?: return
        saveRoutines(values); saveHistory(listOf(HistoryEntry(routineTitle = title, completedAt = now, photoUri = photoUri)) + history())
    }
    fun reopen(id: String) = saveRoutines(routines().map { if (it.id == id) it.copy(completedAt = null, resetAt = null) else it })
    fun restoreSamples() { prefs.edit().remove("routines").remove("history").remove("seeded").apply(); routines() }

    private fun reopenDue(values: List<Routine>): List<Routine> {
        val now = System.currentTimeMillis(); val refreshed = values.map { if (it.resetAt != null && it.resetAt <= now) it.copy(completedAt = null, resetAt = null) else it }
        if (refreshed != values) saveRoutines(refreshed); return refreshed
    }
    private fun saveRoutines(values: List<Routine>) = prefs.edit().putString("routines", JSONArray(values.map { it.json() }).toString()).apply()
    private fun saveHistory(values: List<HistoryEntry>) = prefs.edit().putString("history", JSONArray(values.map { JSONObject().put("id", it.id).put("title", it.routineTitle).put("at", it.completedAt).put("photo", it.photoUri ?: "") }).toString()).apply()
}

private fun Routine.json() = JSONObject().put("id", id).put("title", title).put("detail", detail).put("icon", icon).put("tint", tint).put("reset", reset.name).put("completed", completedAt ?: JSONObject.NULL).put("resetAt", resetAt ?: JSONObject.NULL)
private fun JSONObject.toRoutine() = runCatching { Routine(optString("id"), optString("title"), optString("detail"), optString("icon", "check"), optLong("tint", 0xFF6C63FF), ResetRule.valueOf(optString("reset", ResetRule.DailyMidnight.name)), if (isNull("completed")) null else optLong("completed"), if (isNull("resetAt")) null else optLong("resetAt")) }.getOrNull()
private fun resetTime(now: Long, rule: ResetRule): Long? = when (rule) { ResetRule.Manual -> null; ResetRule.FourHours, ResetRule.EightHours -> now + (rule.hours!! * 3_600_000L); ResetRule.DailyMidnight, ResetRule.DailyMorning -> { val calendar = java.util.Calendar.getInstance().apply { timeInMillis = now; add(java.util.Calendar.DAY_OF_YEAR, 1); set(java.util.Calendar.HOUR_OF_DAY, if (rule == ResetRule.DailyMorning) 6 else 0); set(java.util.Calendar.MINUTE, 0); set(java.util.Calendar.SECOND, 0); set(java.util.Calendar.MILLISECOND, 0) }; calendar.timeInMillis } }
private fun de() = java.util.Locale.getDefault().language == "de"
