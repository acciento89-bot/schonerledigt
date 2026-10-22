package com.kamilunavo.schonerledigt

import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.nio.file.Files

class HouseholdSequenceTest {
    private val a = "00000000-0000-0000-0000-000000000001"
    private val b = "00000000-0000-0000-0000-000000000002"
    private val at = 1_800_000_000_000L
    private val steps get() = listOf(SequenceStep(a, "Door"), SequenceStep(b, "Lights"))
    private fun card(id: String, token: String?, order: Double?) = SequenceCardState(id, if (id == a) "Door" else "Lights", token, order, order?.let { at + it.toLong() })
    private val old get() = listOf(card(a,"a0",1.0),card(b,"b0",2.0))
    private fun create() = HouseholdSequence.create("Leaving home", steps, listOf("Alex","Sam"), old, at)

    @Test fun staleWrongOrderEqualOrderAndMissingCardsCannotCompleteRound() {
        val sequence = create()
        assertEquals(0,sequence.progress(old)); assertEquals(a, sequence.eligibleStepID(old))
        val wrong = listOf(card(a,"a1",4.0),card(b,"b1",3.0))
        assertEquals(1, sequence.progress(wrong)); assertEquals(b, sequence.eligibleStepID(wrong))
        assertEquals(1,sequence.progress(listOf(card(a,"a1",4.0),card(b,"b1",4.0))))
        assertEquals(2,sequence.progress(listOf(card(a,"a1",3.0),card(b,"b2",5.0))))
        assertNull(sequence.eligibleStepID(emptyList()))
        assertEquals(0,sequence.progress(listOf(card(a,null,null),card(b,"b2",5.0))))
    }
    @Test fun lateUnknownOldConfirmationsCannotSatisfyNewRound() {
        val sequence = HouseholdSequence.create("Fresh",steps,emptyList(),emptyList(),at)
        val oldStates = listOf(SequenceCardState(a,"Door","unknown-a",1.0,at-60000),SequenceCardState(b,"Lights","unknown-b",2.0,at-30000))
        assertEquals(0,sequence.progress(oldStates))
        assertEquals(0,sequence.progress(listOf(SequenceCardState(a,"Door","boundary",1.0,at))))
        val newStates = listOf(SequenceCardState(a,"Door","new-a",1.0,at+1),SequenceCardState(b,"Lights","new-b",2.0,at+2))
        assertEquals(2,sequence.progress(newStates))
    }
    @Test fun handoverPreservesPendingStepsAndIncompleteRoundCannotRotateAway() {
        val first = listOf(card(a,"a1",3.0),card(b,"b0",2.0))
        val sequence = create().handover("Sam","Please finish lights",first,at+10)
        assertEquals("Sam",sequence.responsiblePerson)
        assertEquals(listOf(b),sequence.handovers.last().pendingIDs)
        assertThrows(IllegalArgumentException::class.java) { sequence.nextRound(first,at+20) }
        val done = listOf(card(a,"a1",3.0),card(b,"b2",5.0))
        val next = sequence.nextRound(done,at+30)
        assertEquals(1,next.rounds.size); assertTrue(next.rounds[0].pendingIDs.isEmpty())
        assertEquals("Sam",next.responsiblePerson); assertEquals(0,next.progress(done))
        val repaired = next.reconfigure("Leaving home",listOf(steps[0]),listOf("Alex"),done,at+40)
        assertEquals(listOf(a,b),repaired.rounds.last().pendingIDs)
        assertEquals(1,repaired.steps.size)
    }
    @Test fun invalidGroupsRejectedAndResponsibilityCanBeUnassigned() {
        assertThrows(IllegalArgumentException::class.java) { HouseholdSequence.create("Bad", emptyList(),emptyList(),emptyList(),at) }
        assertThrows(IllegalArgumentException::class.java) { HouseholdSequence.create("Bad", listOf(steps[0],steps[0]),emptyList(),emptyList(),at) }
        assertThrows(IllegalArgumentException::class.java) { HouseholdSequence.create("Bad", steps,listOf("Alex","alex"),emptyList(),at) }
        assertThrows(IllegalArgumentException::class.java) { HouseholdSequence.create(" ",steps,emptyList(),emptyList(),at) }
        assertNull(HouseholdSequence.create("Solo",steps,emptyList(),emptyList(),at).responsiblePerson)
    }
    @Test fun actualArchiveRoundtripLegacyBytesMigrationCorruptionFutureVersionAndStoreFailure() {
        val directory = Files.createTempDirectory("schon-sequences").toFile()
        try {
            val legacy = File(directory,"app-state.json").apply { writeText("{\"legacy\":\"preservephotos/reminders/cloud\"}") }
            val legacyBytes = legacy.readBytes()
            val file = File(directory,"sequences.json")
            val archive = SequenceArchive(file)
            assertTrue(archive.load().isEmpty())
            val sequences = listOf(create())
            archive.save(sequences); assertEquals(sequences, SequenceArchive(file).load())
            assertArrayEquals(legacyBytes,legacy.readBytes())
            val document = file.readText()
            file.writeText(document.substringAfter("\"sequences\":").dropLast(1))
            assertEquals(sequences, archive.load()); archive.save(sequences)
            val store = SequenceStore(file); assertEquals(sequences,store.sequences)
            file.writeText("{broken")
            assertFalse(store.commit(emptyList())); assertEquals(sequences,store.sequences)
            assertEquals("{broken",file.readText())
            val blocked = SequenceStore(file); assertTrue(blocked.loadFailed); assertFalse(blocked.commit(emptyList()))
            file.writeText("{\"schemaVersion\":999,\"sequences\":[]}")
            assertThrows(Exception::class.java) { archive.save(emptyList()) }
            assertEquals("{\"schemaVersion\":999,\"sequences\":[]}",file.readText())
            assertArrayEquals(legacyBytes,legacy.readBytes())
        } finally { directory.deleteRecursively() }
    }
    @Test fun failedWriteRetainsUnrelatedData() {
        val directory = Files.createTempDirectory("schon-sequences-failure").toFile()
        try {
            val parent = File(directory,"blocked").apply { writeText("preserve") }
            assertThrows(Exception::class.java) { SequenceArchive(File(parent,"sequences.json")).save(emptyList()) }
            assertEquals("preserve",parent.readText())
        } finally { directory.deleteRecursively() }
    }
}
