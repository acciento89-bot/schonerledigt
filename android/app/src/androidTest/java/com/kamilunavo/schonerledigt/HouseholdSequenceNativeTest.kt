package com.kamilunavo.schonerledigt

import android.os.Build
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Exercises the real free-user UI. Never grants Pro, seeds records or calls billing transactions. */
@RunWith(AndroidJUnit4::class)
class HouseholdSequenceNativeTest {
    @get:Rule val ui = createAndroidComposeRule<MainActivity>()
    private val title = "QA Leaving Home ÄΔ"
    private val handoverNote = "QA Please finish Δ Σ ✓ Ende"
    private val cards = listOf("Front door locked", "Stove turned off", "Medication taken")
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private fun button(text: String) = ui.onNode(hasText(text) and hasClickAction())
    private fun field(label: String) = ui.onNode(hasText(label) and hasSetTextAction())
    private fun text(value: String) = ui.onNodeWithText(value)
    private fun scrollClick(value: String) { val node=button(value); if(!node.isDisplayed()) node.performScrollTo(); node.assertIsDisplayed().assertIsEnabled().performClick() }
    private fun progress(n: Int) { text("Steps confirmed in order: $n/3").performScrollTo().assertIsDisplayed() }
    private fun confirmOne() {
        val enabled = ui.onAllNodes(hasText("Confirm step") and hasClickAction() and isEnabled())
        enabled.assertCountEquals(1); enabled[0].performScrollTo().performClick()
    }
    private fun capture(name: String) {
        ui.waitForIdle()
        val file = File(context.filesDir,"native-proof/$name.png"); file.parentFile!!.mkdirs()
        assertTrue("Actual device screenshot",UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).takeScreenshot(file))
    }
    private fun ownedApi35() {
        assertEquals(35,Build.VERSION.SDK_INT)
        assertEquals("1",UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).executeShellCommand("getprop ro.kernel.qemu").trim())
        assertEquals("com.kamilunavo.schonerledigt",context.packageName)
        assertEquals("1.1.0",context.packageManager.getPackageInfo(context.packageName,0).versionName)
    }
    private fun archive() = SequenceArchive(File(context.filesDir,"SchonErledigt/sequences.json")).load().single()
    private fun enterSequences() { button("Sequences").performClick() }

    @Test fun createOrderedRoundHandoverAndArchiveThroughRealUi() {
        ownedApi35()
        button("Continue").performClick(); button("Continue").performClick(); button("Get started").performClick()
        // The real existing card callbacks create old confirmations before the new round exists.
        cards.forEach { card -> ui.onNode(hasText(card) and hasClickAction()).performScrollTo().performClick() }
        capture("01-legacy-cards")
        enterSequences(); button("New").performClick()
        field("Sequence name").performTextReplacement(title)
        cards.forEach { scrollClick("+ $it") }
        field("Optional roster: one person per line").performScrollTo().performTextReplacement("Alex\nSam")
        // Recreate the real Activity while the unsaved editor is open; saved draft state must survive.
        ui.activityRule.scenario.recreate(); ui.waitForIdle()
        field("Sequence name").assertTextContains(title)
        field("Optional roster: one person per line").assertTextContains("Alex\nSam")
        scrollClick("Save & start")
        progress(0); text("Responsible person: Alex").assertExists()
        button("Start next round").assertIsNotEnabled()
        assertEquals(0,archive().progress(RoutineStore(context).routines().map { SequenceCardState(it.id,it.title,it.completedAt?.let { at -> "${it.id}:$at" },it.completedAt?.toDouble(),it.completedAt) }))
        confirmOne(); progress(1)
        assertEquals(1,RoutineStore(context).history().size-3)
        scrollClick("Hand over unfinished sequence")
        field("Hand over to").performTextReplacement("Sam")
        field("Handover note").performTextReplacement(handoverNote)
        scrollClick("Save handover")
        text("Responsible person: Sam").assertExists(); progress(1)
        text(handoverNote).performScrollTo().assertIsDisplayed(); capture("02-partial-handover")
        assertEquals(2,archive().handovers.single().pendingIDs.size)
        confirmOne(); progress(2); confirmOne(); progress(3)
        capture("03-complete-round")
        scrollClick("Start next round"); button("Start").performClick()
        progress(0); text("Responsible person: Sam").assertExists()
        val saved = archive()
        assertEquals(1,saved.rounds.size); assertEquals(3,saved.rounds.single().completedIDs.size)
        assertEquals(2,saved.rounds.single().handovers.single().pendingIDs.size)
        assertEquals(handoverNote,saved.rounds.single().handovers.single().note)
        assertEquals(listOf("Alex","Sam"),saved.people); assertEquals("Sam",saved.responsiblePerson)
        assertTrue(saved.handovers.isEmpty()); assertEquals(6,RoutineStore(context).history().size)
        capture("04-next-round")
    }
    @Test fun coldReopenRetainsRoundHandoverAndOriginalCards() {
        ownedApi35()
        enterSequences(); text(title).assertExists(); button("Open sequence").performClick()
        progress(0); text("Responsible person: Sam").assertExists()
        text(handoverNote).performScrollTo().assertIsDisplayed()
        val saved=archive(); assertEquals(title,saved.name); assertEquals(1,saved.rounds.size)
        assertEquals(handoverNote,saved.rounds.single().handovers.single().note)
        assertEquals(3,saved.rounds.single().completedIDs.size); assertEquals(2,saved.rounds.single().handovers.single().pendingIDs.size)
        assertEquals(cards,RoutineStore(context).routines().map { it.title }); assertEquals(6,RoutineStore(context).history().size)
        capture("05-cold-reopened")
    }
}
