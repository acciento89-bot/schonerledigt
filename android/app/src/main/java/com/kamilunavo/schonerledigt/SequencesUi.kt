package com.kamilunavo.schonerledigt

import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import java.text.DateFormat
import java.util.Date

private fun st(de: Boolean, german: String, english: String) = if (de) german else english
private fun seqCards(store: RoutineStore): List<SequenceCardState> = store.routines().map {
    SequenceCardState(it.id,it.title,it.completedAt?.let { time -> "${it.id}:$time" },it.completedAt?.toDouble(),it.completedAt)
}
private fun stamp(time: Long) = DateFormat.getDateTimeInstance(DateFormat.MEDIUM,DateFormat.SHORT).format(Date(time))
private fun notice(de: Boolean) = st(de,"Abläufe, Zuständigkeiten und Übergaben bleiben auf diesem Gerät. Kartenverlauf, Fotobelege und Rücksetzregeln bleiben erhalten.","Sequences, responsibility and handovers stay on this device. Existing card history, photo evidence and reset rules are retained.")
private fun errorText(error: String, de: Boolean) = when(error) {
    "load" -> st(de,"Abläufe konnten nicht geladen werden. Die Datei bleibt erhalten. Änderungen sind gesperrt; nach Behebung des Speicherproblems erneut laden.","Sequences could not be loaded. The file is preserved. Changes are blocked; retry after resolving the storage problem.")
    "invalid" -> st(de,"Bitte einen Namen, mindestens eine Karte und eindeutige Personennamen eingeben.","Enter a name, at least one card and unique names for the optional roster.")
    "changed" -> st(de,"Der Kartenstand hat sich geändert oder ein vorheriger Schritt ist wieder offen. Prüfe die Reihenfolge erneut.","The card state changed or an earlier step is pending again. Check the order again.")
    else -> st(de,"Die Änderung konnte nicht gespeichert werden. Bisherige Daten und deine Eingaben bleiben erhalten. Bitte erneut versuchen.","The change could not be saved. Existing data and your entered fields are preserved. Please try again.")
}
@Composable private fun SequenceErrorPanel(store: SequenceStore, de: Boolean) {
    val error = if (store.loadFailed) "load" else store.error
    if (error != null) {
        Text(errorText(error,de),color = MaterialTheme.colorScheme.error)
        if (store.loadFailed) TextButton(onClick = store::reload) { Text(st(de,"Erneut laden","Retry loading")) }
    }
}
@Composable private fun SequencePanel(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(Modifier.fillMaxWidth(),colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.padding(16.dp),verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(title,style = MaterialTheme.typography.titleMedium); content()
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable internal fun SequencesScreen(routines: RoutineStore, store: SequenceStore, pro: Boolean, de: Boolean, refresh: Int, reload: () -> Unit, onPaywall: () -> Unit, modifier: Modifier) {
    var selectedID by rememberSaveable { mutableStateOf<String?>(null) }
    var editorID by rememberSaveable { mutableStateOf<String?>(null) }
    var editing by rememberSaveable { mutableStateOf(false) }
    var handingOver by rememberSaveable { mutableStateOf(false) }
    var nextRound by rememberSaveable { mutableStateOf(false) }
    var deleting by rememberSaveable { mutableStateOf<String?>(null) }
    var photoRoutineID by rememberSaveable { mutableStateOf<String?>(null) }
    var photoSequenceID by rememberSaveable { mutableStateOf<String?>(null) }
    var tick by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while (true) { delay(1_000); tick = System.currentTimeMillis() } }
    val states = remember(refresh,tick) { seqCards(routines) }
    val group = store.sequences.firstOrNull { it.id == selectedID }
    val context = LocalContext.current
    val photo = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            val live = store.sequences.firstOrNull { it.id == photoSequenceID }
            if (photoRoutineID != null && live?.eligibleStepID(seqCards(routines)) == photoRoutineID && !store.loadFailed) {
                runCatching { context.contentResolver.takePersistableUriPermission(uri,Intent.FLAG_GRANT_READ_URI_PERMISSION) }
                routines.complete(photoRoutineID!!,uri.toString()); reload(); tick = System.currentTimeMillis()
            } else store.error = "changed"
        }
        photoRoutineID = null; photoSequenceID = null
    }
    BackHandler(enabled = selectedID != null && !editing && !handingOver) { selectedID = null }
    Scaffold(modifier = modifier, topBar = {
        TopAppBar(title = { Text(st(de,"Abläufe","Sequences")) }, navigationIcon = {
            if (selectedID != null) TextButton(onClick = { selectedID = null }) { Text(st(de,"Zurück","Back")) }
        },actions = {
            TextButton(enabled = !store.loadFailed,onClick = { editorID = null; editing = true; store.error = null }) { Text(st(de,"Neu","New")) }
        })
    }) { padding ->
        Column(Modifier.padding(padding).fillMaxSize().verticalScroll(rememberScrollState()).padding(18.dp),verticalArrangement = Arrangement.spacedBy(14.dp)) {
            SequenceErrorPanel(store,de)
            if (group == null) {
                Text(notice(de),style = MaterialTheme.typography.bodyMedium)
                if (store.sequences.isEmpty() && !store.loadFailed) Text(st(de,"Noch keine Abläufe. Fasse vorhandene Karten zu einer Reihenfolge zusammen.","No sequences yet. Group existing cards into an ordered sequence."))
                store.sequences.forEach { item ->
                    SequencePanel(item.name) {
                        Text(item.responsiblePerson ?: st(de,"Nicht zugeteilt","Unassigned"))
                        TextButton(onClick = { selectedID = item.id }) { Text(st(de,"Ablauf öffnen","Open sequence")) }
                        TextButton(onClick = { deleting = item.id }) { Text(st(de,"Löschen","Delete"),color = MaterialTheme.colorScheme.error) }
                    }
                }
            } else {
                val progress = group.progress(states)
                SequencePanel(group.name) {
                    Text("${st(de,"Zuständig","Responsible person")}: ${group.responsiblePerson ?: st(de,"Nicht zugeteilt","Unassigned")}")
                    Text("${st(de,"Schritte in Reihenfolge bestätigt","Steps confirmed in order")}: $progress/${group.steps.size}")
                    Text(notice(de),style = MaterialTheme.typography.bodySmall)
                    TextButton(enabled = !store.loadFailed,onClick = { editorID = group.id; editing = true; store.error = null }) { Text(st(de,"Ablauf bearbeiten","Edit sequence")) }
                }
                group.steps.forEachIndexed { index, step ->
                    val exists = states.any { it.id == step.routineID }
                    SequencePanel("${index+1}. ${states.firstOrNull { it.id == step.routineID }?.title ?: step.title}") {
                        when {
                            index < progress -> Text(st(de,"In dieser Runde bestätigt","Confirmed in this round"),color = MaterialTheme.colorScheme.secondary)
                            !exists -> Text(st(de,"Diese Karte wurde entfernt. Bearbeite den Ablauf, um sie zu ersetzen. Bis dahin bleibt dieser Schritt offen.","This card was removed. Edit the sequence to replace it. This step stays pending until then."),color = MaterialTheme.colorScheme.error)
                            else -> {
                                Text(if(index == progress) st(de,"Jetzt prüfen. Frühere oder vorgezogene Bestätigungen müssen erneut erfolgen.","Check now. Old confirmations or checks made before an earlier step must be confirmed again.") else st(de,"Wartet auf die vorherigen Schritte.","Waiting for earlier steps."))
                                Button(enabled = index == progress && !store.loadFailed,onClick = {
                                    val live = store.sequences.firstOrNull { it.id == group.id }
                                    if (live?.eligibleStepID(seqCards(routines)) == step.routineID) { routines.complete(step.routineID); reload(); tick = System.currentTimeMillis() }
                                    else store.error = "changed"
                                }) { Text(st(de,"Schritt bestätigen","Confirm step")) }
                                OutlinedButton(enabled = index == progress && !store.loadFailed,onClick = {
                                    if (!pro) onPaywall() else {
                                        val live = store.sequences.firstOrNull { it.id == group.id }
                                        if (live?.eligibleStepID(seqCards(routines)) == step.routineID) {
                                            photoRoutineID = step.routineID; photoSequenceID = group.id; photo.launch(arrayOf("image/*"))
                                        } else store.error = "changed"
                                    }
                                }) { Text(st(de,"Mit Fotobeleg bestätigen","Confirm with photo evidence")) }
                            }
                        }
                    }
                }
                Button(enabled = progress < group.steps.size && !store.loadFailed,onClick = { handingOver = true; store.error = null }) { Text(st(de,"Unfertigen Ablauf übergeben","Hand over unfinished sequence")) }
                OutlinedButton(enabled = progress == group.steps.size && !store.loadFailed,onClick = { nextRound = true }) { Text(st(de,"Nächste Runde starten","Start next round")) }
                Text(st(de,"Die bisherige Runde bleibt gespeichert. Eine neue Runde benötigt frische Bestätigungen und rotiert die Zuständigkeit. Karten und Rücksetzregeln bleiben erhalten.","The previous round is retained. A new round needs fresh confirmations and rotates responsibility. Cards and reset rules are retained."),style = MaterialTheme.typography.bodySmall)
                group.handovers.asReversed().forEach { HandoverPanel(it,group.steps,de) }
                group.rounds.asReversed().forEach { round ->
                    SequencePanel(st(de,"Gespeicherte Runde","Saved round") + " · " + stamp(round.endedAt)) {
                        Text(round.name); Text(round.responsiblePerson ?: st(de,"Nicht zugeteilt","Unassigned"))
                        Text(if (round.pendingIDs.isEmpty()) st(de,"Vollständig abgeschlossen","Fully completed") else st(de,"Unvollständig übergeben / neu geplant","Incomplete handover / replanned"))
                        round.steps.forEach { Text((if(it.routineID in round.completedIDs) "✓ " else "○ ") + it.title) }
                        round.handovers.forEach { HandoverPanel(it,round.steps,de) }
                    }
                }
            }
        }
    }
    if (editing) SequenceDefinitionDialog(editorID,store,routines,de,onDismiss = { editing = false }) { selectedID = it; editing = false }
    if (handingOver && group != null) HandoverDialog(group.id,store,routines,de) { handingOver = false }
    if (nextRound && group != null) AlertDialog(onDismissRequest = { nextRound = false },title = { Text(st(de,"Neue Runde starten?","Start a new round?")) },text = { Text(st(de,"Die bisherige Runde bleibt gespeichert. Alle Schritte brauchen frische Bestätigungen; die nächste Person übernimmt.","The previous round is retained. All steps need fresh confirmations; the next person takes responsibility.")) },confirmButton = {
        TextButton(onClick = {
            try {
                val latest = store.sequences.first { it.id == group.id }
                val next = latest.nextRound(seqCards(routines),System.currentTimeMillis())
                store.commit(store.sequences.map { if(it.id == next.id) next else it })
            } catch (_: Exception) { store.error = "changed" }
            nextRound = false
        }) { Text(st(de,"Starten","Start")) }
    },dismissButton = { TextButton(onClick = { nextRound = false }) { Text(st(de,"Abbrechen","Cancel")) } })
    if (deleting != null) AlertDialog(onDismissRequest = { deleting = null },title = { Text(st(de,"Ablauf löschen?","Delete sequence?")) },text = { Text(st(de,"Runden und Übergaben dieses Ablaufs werden gelöscht. Die Karten bleiben erhalten.","Rounds and handovers for this sequence will be deleted. The cards remain available.")) },confirmButton = { TextButton(onClick = { store.commit(store.sequences.filterNot { it.id == deleting }); deleting = null }) { Text(st(de,"Löschen","Delete")) } },dismissButton = { TextButton(onClick = { deleting = null }) { Text(st(de,"Abbrechen","Cancel")) } })
}

@Composable private fun HandoverPanel(event: SequenceHandover, steps: List<SequenceStep>, de: Boolean) {
    SequencePanel("${event.from ?: st(de,"Nicht zugeteilt","Unassigned")} → ${event.to}") {
        Text(stamp(event.date),style = MaterialTheme.typography.bodySmall)
        if(event.note.isNotBlank()) Text(event.note)
        Text(st(de,"Zum Übergabezeitpunkt noch offen:","Still pending when handed over:"))
        event.pendingIDs.forEach { id -> Text(steps.firstOrNull { it.routineID == id }?.title ?: id) }
    }
}
@Composable private fun SequenceDefinitionDialog(sequenceID: String?, store: SequenceStore, routines: RoutineStore, de: Boolean, onDismiss: () -> Unit, onSaved: (String) -> Unit) {
    val existing = store.sequences.firstOrNull { it.id == sequenceID }
    var name by rememberSaveable(sequenceID) { mutableStateOf(existing?.name ?: "") }
    var selected: List<String> by rememberSaveable(sequenceID) { mutableStateOf<List<String>>(existing?.steps?.map { it.routineID } ?: emptyList()) }
    var people by rememberSaveable(sequenceID) { mutableStateOf(existing?.people?.joinToString("\n") ?: "") }
    val available = routines.routines()
    fun title(id: String) = available.firstOrNull { it.id == id }?.title ?: existing?.steps?.firstOrNull { it.routineID == id }?.title ?: id
    AlertDialog(modifier = Modifier.imePadding(),onDismissRequest = onDismiss,title = { Text(if(sequenceID == null) st(de,"Neuer Ablauf","New sequence") else st(de,"Ablauf bearbeiten","Edit sequence")) },text = {
        Column(Modifier.heightIn(max = 540.dp).verticalScroll(rememberScrollState()),verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SequenceErrorPanel(store,de)
            OutlinedTextField(value = name,onValueChange = { name = it },label = { Text(st(de,"Name des Ablaufs","Sequence name")) },modifier = Modifier.fillMaxWidth())
            Text(st(de,"Geordnete Schritte","Ordered steps"),style = MaterialTheme.typography.titleMedium)
            selected.forEachIndexed { index,id ->
                Text("${index+1}. ${title(id)}")
                Row(Modifier.fillMaxWidth()) {
                    TextButton(enabled = index > 0,onClick = { selected = selected.toMutableList().apply { val value = removeAt(index); add(index-1,value) } },modifier = Modifier.weight(1f)) { Text(st(de,"Nach oben","Move up")) }
                    TextButton(enabled = index < selected.lastIndex,onClick = { selected = selected.toMutableList().apply { val value = removeAt(index); add(index+1,value) } },modifier = Modifier.weight(1f)) { Text(st(de,"Nach unten","Move down")) }
                    TextButton(onClick = { selected = selected.filterNot { it == id } },modifier = Modifier.weight(1f)) { Text(st(de,"Entfernen","Remove")) }
                }
            }
            Text(st(de,"Verfügbare Karten","Available cards"),style = MaterialTheme.typography.titleMedium)
            available.filterNot { it.id in selected }.forEach { card -> TextButton(onClick = { selected = selected + card.id }) { Text("+ ${card.title}") } }
            Text(st(de,"Neue Karten erstellst du unter Heute. Vorhandene Pro-Funktionen und Kartenlimits bleiben erhalten.","Create new cards under Today. Existing Pro features and card limits are retained."),style = MaterialTheme.typography.bodySmall)
            OutlinedTextField(value = people,onValueChange = { people = it },label = { Text(st(de,"Optionale Zuständigkeiten: eine Person pro Zeile","Optional roster: one person per line")) },modifier = Modifier.fillMaxWidth())
            Text(st(de,"Die erste Person beginnt; nach vollständigen Runden rotiert die Zuständigkeit. Namen müssen eindeutig sein.","The first person starts; responsibility rotates after completed rounds. Names must be unique."),style = MaterialTheme.typography.bodySmall)
            Text(if(existing == null) st(de,"Frühere Kartenbestätigungen zählen nicht. Prüfe die Schritte erneut in dieser Reihenfolge.","Earlier card confirmations do not count. Check the steps again in this order.") else st(de,"Speichern startet eine neue Runde. Der bisherige, auch unvollständige Stand und seine Übergaben bleiben gespeichert.","Saving starts a new round. The previous state, including unfinished work and handovers, is retained."))
            Text(notice(de),style = MaterialTheme.typography.bodySmall)
        }
    },confirmButton = {
        TextButton(enabled = name.isNotBlank() && selected.isNotEmpty() && !store.loadFailed,onClick = {
            try {
                val cards = seqCards(routines); val steps = selected.map { SequenceStep(it,title(it)) }
                val roster = people.lines().map { it.trim() }.filter { it.isNotEmpty() }; val now = System.currentTimeMillis()
                val latest = store.sequences.firstOrNull { it.id == sequenceID }
                val value = if (sequenceID == null) HouseholdSequence.create(name,steps,roster,cards,now)
                    else (latest ?: error("Missing sequence")).reconfigure(name,steps,roster,cards,now)
                val values = if(latest == null) store.sequences + value else store.sequences.map { if(it.id == value.id) value else it }
                if(store.commit(values)) onSaved(value.id)
            } catch (_: Exception) { store.error = "invalid" }
        }) { Text(st(de,"Speichern & starten","Save & start")) }
    },dismissButton = { TextButton(onClick = onDismiss) { Text(st(de,"Abbrechen","Cancel")) } })
}
@Composable private fun HandoverDialog(id: String, store: SequenceStore, routines: RoutineStore, de: Boolean, onDismiss: () -> Unit) {
    var person by rememberSaveable { mutableStateOf("") }; var note by rememberSaveable { mutableStateOf("") }
    AlertDialog(modifier = Modifier.imePadding(),onDismissRequest = onDismiss,title = { Text(st(de,"Unfertigen Ablauf übergeben","Hand over unfinished sequence")) },text = {
        Column(Modifier.heightIn(max = 480.dp).verticalScroll(rememberScrollState()),verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SequenceErrorPanel(store,de)
            OutlinedTextField(value = person,onValueChange = { person = it },label = { Text(st(de,"Übergeben an","Hand over to")) },modifier = Modifier.fillMaxWidth())
            OutlinedTextField(value = note,onValueChange = { note = it },label = { Text(st(de,"Übergabenotiz","Handover note")) },modifier = Modifier.fillMaxWidth())
            Text(st(de,"Der Fortschritt bleibt bestehen. Die Übergabe hält alle noch offenen abhängigen Schritte fest.","Progress is retained. The handover records all remaining dependent steps."))
        }
    },confirmButton = {
        TextButton(enabled = person.isNotBlank() && !store.loadFailed,onClick = {
            try {
                val group = store.sequences.first { it.id == id }
                val value = group.handover(person,note,seqCards(routines),System.currentTimeMillis())
                if(store.commit(store.sequences.map { if(it.id == id) value else it })) onDismiss()
            } catch (_: Exception) { store.error = "changed" }
        }) { Text(st(de,"Übergabe speichern","Save handover")) }
    },dismissButton = { TextButton(onClick = onDismiss) { Text(st(de,"Abbrechen","Cancel")) } })
}
