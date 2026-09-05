package com.kamilunavo.schonerledigt

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.DateFormat
import java.util.Date
import java.util.Locale

private val Purple = Color(0xFF6C63FF)
private val Green = Color(0xFF28BFA3)
private val Ink = Color(0xFF151821)
private val Canvas = Color(0xFFF4F5F8)
private val Border = Color(0xFFE5E7EC)
private val Secondary = Color(0xFF68707F)
private val german get() = Locale.getDefault().language == "de"
private fun tr(de: String, en: String) = if (german) de else en

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState); enableEdgeToEdge()
        setContent { SchonTheme { SchonApp() } }
    }
}

@Composable private fun SchonTheme(content: @Composable () -> Unit) = MaterialTheme(
    colorScheme = lightColorScheme(primary = Purple, secondary = Green, background = Canvas, surface = Color.White, onSurface = Ink, surfaceVariant = Color(0xFFF0F1F5), outline = Border),
    content = content
)

@Composable private fun SchonApp() {
    val context = LocalContext.current
    val store = remember { RoutineStore(context) }
    val billing = remember { BillingManager(context) }
    val billingState by billing.state.collectAsState()
    var refresh by remember { mutableIntStateOf(0) }
    var onboarding by remember { mutableStateOf(store.onboarding) }
    if (!onboarding) Onboarding { store.onboarding = true; onboarding = true }
    else MainTabs(store, billing, billingState, refresh) { refresh++ }
}

@Composable private fun Onboarding(done: () -> Unit) {
    val pages = listOf(
        Triple(Icons.Default.Verified, tr("Nicht mehr zweimal fragen", "Stop asking twice"), tr("Ein Blick genügt: Du siehst sofort, was erledigt wurde und wann.", "One glance shows what was done and when.")),
        Triple(Icons.Default.Autorenew, tr("Bereit für den nächsten Tag", "Ready for the next day"), tr("Jede Karte wird automatisch zu dem Zeitpunkt zurückgesetzt, den du festlegst.", "Each card automatically resets at the time you choose.")),
        Triple(Icons.Default.TouchApp, tr("Ein Tipp. Fertig.", "One tap. Done."), tr("Keine Projekte und keine komplizierten Listen – nur klare Gewissheit im Alltag.", "No projects or complicated lists—just everyday certainty."))
    )
    var page by remember { mutableIntStateOf(0) }
    Box(Modifier.fillMaxSize().background(Brush.linearGradient(listOf(Color(0xFFF3F1FF), Color.White))).statusBarsPadding()) {
        Column(Modifier.fillMaxSize().padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.weight(1f))
            Box(Modifier.size(142.dp).background(Purple.copy(alpha = .12f), CircleShape), contentAlignment = Alignment.Center) { Icon(pages[page].first, null, tint = Purple, modifier = Modifier.size(64.dp)) }
            Text(pages[page].second, color = Ink, fontSize = 34.sp, lineHeight = 39.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 28.dp))
            Text(pages[page].third, color = Secondary, fontSize = 19.sp, lineHeight = 27.sp, textAlign = TextAlign.Center, modifier = Modifier.padding(12.dp))
            Spacer(Modifier.weight(1f))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { pages.indices.forEach { Box(Modifier.width(if (it == page) 26.dp else 8.dp).height(8.dp).background(if (it == page) Purple else Border, CircleShape)) } }
            Button(onClick = { if (page < 2) page++ else done() }, Modifier.fillMaxWidth().height(64.dp).padding(top = 12.dp), shape = RoundedCornerShape(18.dp)) { Text(if (page == 2) tr("Loslegen", "Get started") else tr("Weiter", "Continue"), fontWeight = FontWeight.Bold) }
        }
    }
}

private enum class Tab(val icon: ImageVector) { Today(Icons.Default.CheckCircle), History(Icons.Default.History), Settings(Icons.Default.Settings) }

@Composable private fun MainTabs(store: RoutineStore, billing: BillingManager, billingState: BillingState, refresh: Int, reload: () -> Unit) {
    var tab by remember { mutableStateOf(Tab.Today) }
    Scaffold(containerColor = Canvas, bottomBar = { NavigationBar(Modifier.navigationBarsPadding(), containerColor = Color.White) { Tab.entries.forEach { item -> NavigationBarItem(tab == item, { tab = item }, { Icon(item.icon, null) }, label = { Text(when(item) { Tab.Today -> tr("Heute", "Today"); Tab.History -> tr("Verlauf", "History"); Tab.Settings -> tr("Einstellungen", "Settings") }) }) } } }) { padding ->
        when(tab) { Tab.Today -> Home(store, billing, billingState, refresh, reload, Modifier.padding(padding)); Tab.History -> HistoryScreen(store, refresh, Modifier.padding(padding)); Tab.Settings -> SettingsScreen(store, billing, billingState, refresh, reload, Modifier.padding(padding)) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable private fun Home(store: RoutineStore, billingManager: BillingManager, billing: BillingState, refresh: Int, reload: () -> Unit, modifier: Modifier) {
    val routines = remember(refresh) { store.routines() }; val open = routines.filter { it.completedAt == null }; val done = routines.filter { it.completedAt != null }
    var editor by remember { mutableStateOf<Routine?>(null) }; var showEditor by remember { mutableStateOf(false) }; var showPaywall by remember { mutableStateOf(false) }; var photoRoutine by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> uri?.let { runCatching { context.contentResolver.takePersistableUriPermission(it, Intent.FLAG_GRANT_READ_URI_PERMISSION) }; photoRoutine?.let { id -> store.complete(id, it.toString()); reload() } }; photoRoutine = null }
    Scaffold(modifier, containerColor = Canvas, topBar = { TopAppBar(title = { Text(tr("Schon erledigt?", "Already done?"), fontWeight = FontWeight.Bold) }, actions = { IconButton(onClick = { if (routines.size < 6 || billing.pro) { editor = null; showEditor = true } else showPaywall = true }) { Icon(Icons.Default.Add, tr("Neue Karte", "New card")) } }, colors = TopAppBarDefaults.topAppBarColors(containerColor = Canvas)) }) { inner ->
        LazyColumn(Modifier.padding(inner).fillMaxSize(), contentPadding = PaddingValues(18.dp, 8.dp, 18.dp, 28.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            item { SummaryCard(routines.size, done.size, open.size) }
            if (open.isEmpty()) item { Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Green.copy(alpha = .09f)), shape = RoundedCornerShape(22.dp)) { Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) { Icon(Icons.Default.AutoAwesome, null, tint = Green, modifier = Modifier.size(30.dp)); Text(tr("Alles im grünen Bereich", "Everything is taken care of"), fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp)); Text(tr("Sobald eine Karte zurückgesetzt wird, erscheint sie wieder hier.", "When a card resets, it appears here again."), color = Secondary, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 6.dp)) } } }
            else { item { SectionTitle(tr("Noch offen", "Still open"), open.size) }; items(open, key = { it.id }) { routine -> RoutineCard(routine, false, { store.complete(routine.id); reload() }, { if (billing.pro) { photoRoutine = routine.id; picker.launch(arrayOf("image/*")) } else showPaywall = true }, { editor = routine; showEditor = true }, { store.delete(routine.id); reload() }) } }
            if (done.isNotEmpty()) { item { SectionTitle(tr("Schon erledigt", "Already done"), done.size) }; items(done, key = { it.id }) { routine -> RoutineCard(routine, true, { store.reopen(routine.id); reload() }, {}, { editor = routine; showEditor = true }, { store.delete(routine.id); reload() }) } }
        }
    }
    if (showEditor) RoutineEditor(editor, { showEditor = false }, { store.save(it); showEditor = false; reload() })
    if (showPaywall) Paywall(billing, billingManager) { showPaywall = false }
}

@Composable private fun SummaryCard(total: Int, completed: Int, open: Int) = Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Color.White), shape = RoundedCornerShape(24.dp), border = androidx.compose.foundation.BorderStroke(1.dp, Border)) { Row(Modifier.padding(18.dp), verticalAlignment = Alignment.CenterVertically) { Box(Modifier.size(72.dp).border(8.dp, if (open == 0) Green else Purple, CircleShape), contentAlignment = Alignment.Center) { Text("$completed/$total", fontWeight = FontWeight.Bold) }; Column(Modifier.padding(start = 16.dp)) { Text(greeting(), fontSize = 22.sp, fontWeight = FontWeight.Bold); Text(if (open == 0) tr("Für jetzt ist alles erledigt.", "Everything is taken care of for now.") else tr("$open Dinge brauchen noch Gewissheit.", "$open items still need confirmation."), color = Secondary) } } }

@Composable private fun RoutineCard(routine: Routine, completed: Boolean, toggle: () -> Unit, photo: () -> Unit, edit: () -> Unit, delete: () -> Unit) {
    val tint = Color(routine.tint); var menu by remember { mutableStateOf(false) }
    Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Color.White), shape = RoundedCornerShape(21.dp), border = androidx.compose.foundation.BorderStroke(1.dp, if (completed) Green.copy(alpha=.25f) else Border)) { Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
        Row(Modifier.weight(1f).clip(RoundedCornerShape(16.dp)).clickable(onClick = toggle).padding(2.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(54.dp).background((if (completed) Green else tint).copy(alpha=.13f), RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center) { Icon(if (completed) Icons.Default.Check else icon(routine.icon), null, tint = if (completed) Green else tint) }
            Column(Modifier.weight(1f).padding(horizontal = 14.dp)) { Text(routine.title, fontWeight = FontWeight.Bold, color = Ink, maxLines=1, overflow=TextOverflow.Ellipsis); Text(if (completed) tr("Erledigt ${relative(routine.completedAt)}", "Done ${relative(routine.completedAt)}") else routine.detail.ifBlank { resetLabel(routine.reset) }, color = if (completed) Green else Secondary, fontSize=13.sp, maxLines=1) }
            Icon(if (completed) Icons.Default.ReplayCircleFilled else Icons.Default.CheckCircle, null, tint = if (completed) Secondary.copy(alpha=.6f) else Purple, modifier=Modifier.size(28.dp))
        }
        if (!completed) IconButton(photo, Modifier.background(Purple.copy(alpha=.1f), RoundedCornerShape(16.dp))) { Icon(Icons.Default.PhotoCamera, tr("Fotobeleg", "Photo proof"), tint=Purple) }
        Box { IconButton({ menu=true }) { Icon(Icons.Default.MoreVert,null) }; DropdownMenu(menu,{menu=false}) { DropdownMenuItem({Text(tr("Bearbeiten","Edit"))},{menu=false;edit()}, leadingIcon={Icon(Icons.Default.Edit,null)}); DropdownMenuItem({Text(tr("Karte löschen","Delete card"),color=MaterialTheme.colorScheme.error)},{menu=false;delete()}, leadingIcon={Icon(Icons.Default.Delete,null,tint=MaterialTheme.colorScheme.error)}) } }
    } }
}

@Composable private fun RoutineEditor(existing: Routine?, close: () -> Unit, save: (Routine) -> Unit) {
    var title by remember { mutableStateOf(existing?.title.orEmpty()) }; var detail by remember { mutableStateOf(existing?.detail.orEmpty()) }; var selectedIcon by remember { mutableStateOf(existing?.icon ?: "check") }; var tint by remember { mutableStateOf(existing?.tint ?: 0xFF6C63FF) }; var reset by remember { mutableStateOf(existing?.reset ?: ResetRule.DailyMidnight) }
    val icons = listOf("lock","flame","pet","pill","leaf","drop","cart","box","car","washer","bed","check"); val colors=listOf(0xFF6C63FF,0xFFFF6B57,0xFF28BFA3,0xFFFFB84D,0xFF53B86B,0xFF3988FF,0xFFC45BE8,0xFF34435E)
    AlertDialog(onDismissRequest=close, title={Text(if(existing==null) tr("Neue Karte","New card") else tr("Karte bearbeiten","Edit card"),fontWeight=FontWeight.Bold)}, text={Column(Modifier.verticalScroll(rememberScrollState())) { OutlinedTextField(title,{title=it},Modifier.fillMaxWidth(),label={Text(tr("Was möchtest du bestätigen?","What would you like to confirm?"))}); OutlinedTextField(detail,{detail=it},Modifier.fillMaxWidth().padding(top=8.dp),label={Text(tr("Kurzer Hinweis","Short note"))}); Text(tr("Symbol","Icon"),fontWeight=FontWeight.Bold,modifier=Modifier.padding(top=14.dp)); Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){icons.take(6).forEach{ Box(Modifier.size(38.dp).clickable{selectedIcon=it}.background(if(selectedIcon==it) Color(tint) else Color(tint).copy(alpha=.1f),RoundedCornerShape(11.dp)),contentAlignment=Alignment.Center){Icon(icon(it),null,tint=if(selectedIcon==it)Color.White else Color(tint),modifier=Modifier.size(20.dp))}}}; Text(tr("Farbe","Color"),fontWeight=FontWeight.Bold,modifier=Modifier.padding(top=14.dp)); Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){colors.forEach{c->Box(Modifier.size(28.dp).background(Color(c),CircleShape).clickable{tint=c},contentAlignment=Alignment.Center){if(tint==c)Icon(Icons.Default.Check,null,tint=Color.White,modifier=Modifier.size(16.dp))}}}; Text(tr("Zurücksetzen","Reset"),fontWeight=FontWeight.Bold,modifier=Modifier.padding(top=14.dp)); ResetRule.entries.forEach{rule->Row(Modifier.fillMaxWidth().clickable{reset=rule}.padding(vertical=5.dp),verticalAlignment=Alignment.CenterVertically){RadioButton(reset==rule,{reset=rule});Text(resetLabel(rule))}} }}, confirmButton={TextButton({save((existing?:Routine(title=title)).copy(title=title.trim(),detail=detail.trim(),icon=selectedIcon,tint=tint,reset=reset))},enabled=title.isNotBlank()){Text(if(existing==null)tr("Erstellen","Create")else tr("Speichern","Save"))}}, dismissButton={TextButton(close){Text(tr("Abbrechen","Cancel"))}})
}

@Composable
private fun HistoryScreen(store: RoutineStore, refresh: Int, modifier: Modifier) {
    var query by remember { mutableStateOf("") }
    val values = remember(refresh) { store.history() }
        .filter { query.isBlank() || it.routineTitle.contains(query, true) }
    LazyColumn(
        modifier.fillMaxSize().statusBarsPadding(),
        contentPadding = PaddingValues(18.dp, 18.dp, 18.dp, 30.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text(tr("Verlauf", "History"), fontSize = 32.sp, fontWeight = FontWeight.Bold)
            OutlinedTextField(
                query,
                { query = it },
                Modifier.fillMaxWidth().padding(top = 12.dp),
                placeholder = { Text(tr("Verlauf durchsuchen", "Search history")) },
                leadingIcon = { Icon(Icons.Default.Search, null) }
            )
        }
        if (values.isEmpty()) {
            item { EmptyState() }
        } else {
            items(values, key = { it.id }) { entry ->
                Card(
                    Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = Color.White),
                    shape = RoundedCornerShape(19.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, Border)
                ) {
                    Row(Modifier.padding(15.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            Modifier.size(46.dp).background(Green.copy(alpha = .12f), RoundedCornerShape(14.dp)),
                            contentAlignment = Alignment.Center
                        ) { Icon(Icons.Default.Check, tint = Green, contentDescription = null) }
                        Column(Modifier.weight(1f).padding(start = 13.dp)) {
                            Text(entry.routineTitle, fontWeight = FontWeight.Bold)
                            Text(
                                DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(Date(entry.completedAt)),
                                color = Secondary,
                                fontSize = 13.sp
                            )
                        }
                        if (entry.photoUri != null) Icon(Icons.Default.Image, null, tint = Purple)
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsScreen(store: RoutineStore, billing: BillingManager, state: BillingState, refresh: Int, reload: () -> Unit, modifier: Modifier) {
    val context = LocalContext.current
    var name by remember(refresh) { mutableStateOf(store.profileName) }
    var confirmRestore by remember { mutableStateOf(false) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        store.reminders = granted
        reload()
    }
    LazyColumn(
        modifier.fillMaxSize().statusBarsPadding(),
        contentPadding = PaddingValues(18.dp, 18.dp, 18.dp, 32.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item { Text(tr("Einstellungen", "Settings"), fontSize = 32.sp, fontWeight = FontWeight.Bold) }
        item {
            SettingsCard(tr("Profil", "Profile"), Icons.Default.Person) {
                OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text(tr("Dein Name", "Your name")) })
                Button({ store.profileName = name.trim(); reload() }, Modifier.fillMaxWidth().padding(top = 8.dp)) { Text(tr("Speichern", "Save")) }
            }
        }
        item {
            SettingsCard(tr("Erinnerungen", "Reminders"), Icons.Default.Notifications) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("Bei Rücksetzung erinnern", "Notify when a card resets"), Modifier.weight(1f))
                    Switch(store.reminders) { enabled ->
                        if (enabled) permission.launch(Manifest.permission.POST_NOTIFICATIONS)
                        else { store.reminders = false; reload() }
                    }
                }
            }
        }
        item {
            SettingsCard("Schon erledigt? Pro", Icons.Default.WorkspacePremium) {
                Text(
                    if (state.pro) tr("Pro ist aktiv", "Pro is active") else tr("Unbegrenzt Karten, Fotobelege und vollständiger Verlauf.", "Unlimited cards, photo proof and complete history."),
                    color = if (state.pro) Green else Secondary
                )
                if (!state.pro) Button(
                    { state.yearly?.let { billing.purchase(context as Activity, it) } },
                    Modifier.fillMaxWidth().padding(top = 10.dp),
                    enabled = state.yearly != null
                ) { Text(tr("Jahresabo freischalten", "Unlock yearly Pro")) }
                state.lifetime?.let { product ->
                    OutlinedButton(
                        { billing.purchase(context as Activity, product) },
                        Modifier.fillMaxWidth().padding(top = 8.dp)
                    ) { Text(tr("Dauerhaft freischalten", "Unlock lifetime")) }
                }
                TextButton({ billing.restore() }, Modifier.fillMaxWidth()) { Text(tr("Käufe wiederherstellen", "Restore purchases")) }
            }
        }
        item {
            SettingsCard(tr("Daten", "Data"), Icons.Default.Storage) {
                Text("${store.routines().size} ${tr("Karten", "cards")} · ${store.history().size} ${tr("Bestätigungen", "confirmations")}", color = Secondary)
                OutlinedButton({ confirmRestore = true }, Modifier.fillMaxWidth().padding(top = 8.dp)) { Text(tr("Beispieldaten wiederherstellen", "Restore sample data")) }
            }
        }
        item {
            SettingsCard(tr("Hilfe & Rechtliches", "Help & legal"), Icons.Default.Help) {
                LinkRow(tr("Datenschutz", "Privacy policy")) { open(context, if (german) "https://kamilunavo.com/schon-erledigt/datenschutz" else "https://kamilunavo.com/schon-erledigt/privacy") }
                LinkRow(tr("Support", "Support")) { open(context, "https://kamilunavo.com/schon-erledigt/support") }
                Text(
                    tr("Wichtiger Hinweis: Die App dokumentiert deine Eingaben. Sie kann reale Zustände nicht prüfen.", "Important: The app records your input. It cannot verify real-world conditions."),
                    fontSize = 12.sp,
                    color = Secondary,
                    modifier = Modifier.padding(top = 10.dp)
                )
            }
        }
    }
    if (confirmRestore) AlertDialog(
        onDismissRequest = { confirmRestore = false },
        title = { Text(tr("Alle eigenen Daten ersetzen?", "Replace all your data?")) },
        text = { Text(tr("Karten und Verlauf werden durch Beispieldaten ersetzt.", "Cards and history will be replaced with sample data.")) },
        confirmButton = { TextButton({ store.restoreSamples(); confirmRestore = false; reload() }) { Text(tr("Wiederherstellen", "Restore")) } },
        dismissButton = { TextButton({ confirmRestore = false }) { Text(tr("Abbrechen", "Cancel")) } }
    )
}

@Composable private fun Paywall(state: BillingState, billing: BillingManager, close:()->Unit){val context=LocalContext.current;AlertDialog(close,title={Text("Schon erledigt? Pro",fontWeight=FontWeight.Bold)},text={Column{listOf(tr("Unbegrenzt viele Karten","Unlimited cards"),tr("Fotobelege und vollständiger Verlauf","Photo proof and complete history"),tr("Erinnerungen bei Rücksetzung","Reset reminders")).forEach{Row(Modifier.padding(vertical=5.dp)){Icon(Icons.Default.Check,null,tint=Green);Text(it,Modifier.padding(start=8.dp))}};state.yearly?.let{Button({billing.purchase(context as Activity,it)},Modifier.fillMaxWidth().padding(top=10.dp)){Text(it.name)}};state.lifetime?.let{OutlinedButton({billing.purchase(context as Activity,it)},Modifier.fillMaxWidth().padding(top=8.dp)){Text(it.name)}}}},confirmButton={TextButton(close){Text(tr("Fertig","Done"))}}) }

@Composable private fun SettingsCard(title:String,icon:ImageVector,content:@Composable ColumnScope.()->Unit)=Card(Modifier.fillMaxWidth(),colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(22.dp),border=androidx.compose.foundation.BorderStroke(1.dp,Border)){Column(Modifier.padding(18.dp)){Row(verticalAlignment=Alignment.CenterVertically){Box(Modifier.size(42.dp).background(Purple.copy(alpha=.12f),RoundedCornerShape(13.dp)),contentAlignment=Alignment.Center){Icon(icon,null,tint=Purple)};Text(title,fontSize=19.sp,fontWeight=FontWeight.Bold,modifier=Modifier.padding(start=12.dp))};Column(Modifier.padding(top=14.dp),content=content)}}
@Composable private fun SectionTitle(title:String,count:Int)=Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically){Text(title,fontWeight=FontWeight.Bold,fontSize=18.sp);Text(count.toString(),fontSize=11.sp,color=Secondary,modifier=Modifier.padding(start=8.dp).background(Border,CircleShape).padding(horizontal=8.dp,vertical=4.dp))}
@Composable private fun EmptyState()=Card(Modifier.fillMaxWidth(),colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(22.dp)){Column(Modifier.fillMaxWidth().padding(26.dp),horizontalAlignment=Alignment.CenterHorizontally){Icon(Icons.Default.History,null,tint=Purple,modifier=Modifier.size(36.dp));Text(tr("Noch kein Verlauf","No history yet"),fontWeight=FontWeight.Bold,modifier=Modifier.padding(top=8.dp));Text(tr("Jede Bestätigung erscheint automatisch hier.","Every confirmation appears here automatically."),color=Secondary,textAlign=TextAlign.Center)}}
@Composable private fun LinkRow(title:String,click:()->Unit)=Row(Modifier.fillMaxWidth().clickable(onClick=click).padding(vertical=10.dp),verticalAlignment=Alignment.CenterVertically){Text(title,Modifier.weight(1f),fontWeight=FontWeight.SemiBold);Icon(Icons.Default.OpenInNew,null,tint=Secondary)}
private fun icon(value:String):ImageVector=when(value){"lock"->Icons.Default.Lock;"flame"->Icons.Default.LocalFireDepartment;"pet"->Icons.Default.Pets;"pill"->Icons.Default.Medication;"leaf"->Icons.Default.Eco;"drop"->Icons.Default.WaterDrop;"cart"->Icons.Default.ShoppingCart;"box"->Icons.Default.Inventory2;"car"->Icons.Default.DirectionsCar;"washer"->Icons.Default.LocalLaundryService;"bed"->Icons.Default.Bed;else->Icons.Default.CheckCircle}
private fun resetLabel(rule:ResetRule)=when(rule){ResetRule.Manual->tr("Nur manuell","Manual only");ResetRule.FourHours->tr("Nach 4 Stunden","After 4 hours");ResetRule.EightHours->tr("Nach 8 Stunden","After 8 hours");ResetRule.DailyMidnight->tr("Täglich um 00:00","Daily at 00:00");ResetRule.DailyMorning->tr("Täglich um 06:00","Daily at 06:00")}
private fun greeting():String{val hour=java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY);return when(hour){in 5..11->tr("Guten Morgen","Good morning");in 12..17->tr("Guten Tag","Good afternoon");else->tr("Guten Abend","Good evening")}}
private fun relative(time:Long?)=time?.let{DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(it))}.orEmpty()
private fun open(context:android.content.Context,url:String)=context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
