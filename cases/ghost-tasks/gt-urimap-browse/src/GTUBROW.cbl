       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTUBROW.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-urimap-browse                 *
      * Original program (Apache-2.0).                                *
      * Browses the URIMAP definitions installed in the region with   *
      * INQUIRE URIMAP START / NEXT / END, counts what it sees in     *
      * ways that do not depend on the order of the browse, starts    *
      * the alias transaction of the one definition whose name and    *
      * path both qualify, tells the console, and logs to TS queue    *
      * GTUBLOG:                                                      *
      *   1  the RESP of a START, and of a second START while the     *
      *      browse is open (ILLOGIC, RESP2 1)                        *
      *   2  definitions seen / name qualifies / path qualifies /     *
      *      both (and the RESP of the START it issued)               *
      *   3  the RESP of the NEXT that found no more (END, RESP2 2),  *
      *      of the END, and of the WRITE OPERATOR                    *
      *---------------------------------------------------------------*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RESP                 PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                PIC S9(8) COMP VALUE 0.
       01  WS-DONE                 PIC X     VALUE 'N'.
       01  WS-URIMAP.
           05  WS-PREFIX           PIC X(2)  VALUE SPACES.
           05  WS-REST             PIC X(6)  VALUE SPACES.
       01  WS-PATH                 PIC X(255) VALUE SPACES.
       01  WS-TRAN                 PIC X(4)  VALUE SPACES.
       01  WS-SEEN                 PIC 99    VALUE 0.
       01  WS-NAMED                PIC 99    VALUE 0.
       01  WS-PATHED               PIC 99    VALUE 0.
       01  WS-BOTH                 PIC 99    VALUE 0.
       01  WS-ST                   PIC S9(8) COMP VALUE 99.
       01  WS-WTO                  PIC S9(8) COMP VALUE 99.
       01  WS-END-RESP             PIC S9(8) COMP VALUE 0.
       01  WS-END-RESP2            PIC S9(8) COMP VALUE 0.
       01  WS-CLOSE                PIC S9(8) COMP VALUE 99.
       01  WS-OPMSG                PIC X(24)
                                   VALUE 'GTUBROW browse finished'.
       01  WS-LOG1.
           05  FILLER              PIC X(10) VALUE 'START 1/2='.
           05  L1-R1               PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  L1-R2               PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE ':'.
           05  L1-R2B              PIC 9(4)  VALUE 0.
       01  WS-LOG2.
           05  FILLER              PIC X(5)  VALUE 'DEFS='.
           05  L2-SEEN             PIC 99    VALUE 0.
           05  FILLER              PIC X(4)  VALUE ' ZC='.
           05  L2-NAMED            PIC 99    VALUE 0.
           05  FILLER              PIC X(6)  VALUE ' PATH='.
           05  L2-PATHED           PIC 99    VALUE 0.
           05  FILLER              PIC X(6)  VALUE ' BOTH='.
           05  L2-BOTH             PIC 99    VALUE 0.
           05  FILLER              PIC X(4)  VALUE ' ST='.
           05  L2-ST               PIC 99    VALUE 0.
       01  WS-LOG3.
           05  FILLER              PIC X(4)  VALUE 'END='.
           05  L3-RESP             PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE ':'.
           05  L3-RESP2            PIC 9(4)  VALUE 0.
           05  FILLER              PIC X(7)  VALUE ' CLOSE='.
           05  L3-CLOSE            PIC 99    VALUE 0.
           05  FILLER              PIC X(5)  VALUE ' WTO='.
           05  L3-WTO              PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS INQUIRE URIMAP START
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO L1-R1
           EXEC CICS INQUIRE URIMAP START
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO L1-R2
           MOVE WS-RESP2 TO L1-R2B
           EXEC CICS WRITEQ TS QUEUE('GTUBLOG') FROM(WS-LOG1)
                     LENGTH(20)
           END-EXEC
           PERFORM UNTIL WS-DONE = 'Y'
               EXEC CICS INQUIRE URIMAP(WS-URIMAP) PATH(WS-PATH)
                         TRANSACTION(WS-TRAN) NEXT
                         RESP(WS-RESP) RESP2(WS-RESP2)
               END-EXEC
               IF WS-RESP = DFHRESP(NORMAL)
                   PERFORM CHECK-ONE
               ELSE
                   MOVE WS-RESP TO WS-END-RESP
                   MOVE WS-RESP2 TO WS-END-RESP2
                   MOVE 'Y' TO WS-DONE
               END-IF
           END-PERFORM
           EXEC CICS INQUIRE URIMAP END
                     RESP(WS-CLOSE)
           END-EXEC
           EXEC CICS WRITE OPERATOR TEXT(WS-OPMSG)
                     RESP(WS-WTO)
           END-EXEC
           MOVE WS-SEEN TO L2-SEEN
           MOVE WS-NAMED TO L2-NAMED
           MOVE WS-PATHED TO L2-PATHED
           MOVE WS-BOTH TO L2-BOTH
           MOVE WS-ST TO L2-ST
           EXEC CICS WRITEQ TS QUEUE('GTUBLOG') FROM(WS-LOG2)
                     LENGTH(35)
           END-EXEC
           MOVE WS-END-RESP TO L3-RESP
           MOVE WS-END-RESP2 TO L3-RESP2
           MOVE WS-CLOSE TO L3-CLOSE
           MOVE WS-WTO TO L3-WTO
           EXEC CICS WRITEQ TS QUEUE('GTUBLOG') FROM(WS-LOG3)
                     LENGTH(27)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       CHECK-ONE.
           ADD 1 TO WS-SEEN
           IF WS-PREFIX = 'ZC'
               ADD 1 TO WS-NAMED
           END-IF
           IF WS-PATH(1:6) = '/zecs/'
               ADD 1 TO WS-PATHED
           END-IF
           IF WS-PREFIX = 'ZC' AND WS-PATH(1:6) = '/zecs/'
               ADD 1 TO WS-BOTH
               EXEC CICS START TRANSID('GT62') INTERVAL(0)
                         FROM(WS-TRAN) LENGTH(4)
                         RESP(WS-ST)
               END-EXEC
           END-IF.
