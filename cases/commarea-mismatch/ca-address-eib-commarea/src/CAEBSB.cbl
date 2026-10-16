       IDENTIFICATION DIVISION.
       PROGRAM-ID. CAEBSB.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-address-eib-commarea    *
      * Original program (Apache-2.0).                                *
      * The callee of CAEBCA mode W. It names no DFHCOMMAREA. It      *
      * asks CICS for the EIB (ADDRESS EIB) and the COMMAREA          *
      * (ADDRESS COMMAREA), reads EIBCALEN through the EIB view,      *
      * reads the caller's bytes and writes a reply through the       *
      * COMMAREA view. CICS sets a missing COMMAREA's pointer to      *
      * X'FF000000', so the test is against that value.               *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PTR                POINTER.
       01  WS-PTR-X REDEFINES WS-PTR PIC X(4).
       01  WS-EPTR               POINTER.
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' P='.
           05  CLOG-P            PIC X(7)  VALUE SPACES.
           05  FILLER            PIC X(7)  VALUE ' CALEN='.
           05  CLOG-LEN          PIC 9(4)  VALUE 0.
           05  FILLER            PIC X(6)  VALUE ' SAME='.
           05  CLOG-SAME         PIC X     VALUE 'N'.
           05  FILLER            PIC X(5)  VALUE ' EYE='.
           05  CLOG-EYE          PIC X(4)  VALUE SPACES.
           05  FILLER            PIC X(5)  VALUE ' REQ='.
           05  CLOG-REQ          PIC X(8)  VALUE SPACES.
       LINKAGE SECTION.
       01  LS-EIB.
           05  VE-TIME           PIC S9(7) COMP-3.
           05  VE-DATE           PIC S9(7) COMP-3.
           05  VE-TRNID          PIC X(4).
           05  VE-TASKN          PIC S9(7) COMP-3.
           05  VE-TRMID          PIC X(4).
           05  VE-GDI            PIC S9(4) COMP.
           05  VE-CPOSN          PIC S9(4) COMP.
           05  VE-CALEN          PIC S9(4) COMP.
       01  LS-VIEW.
           05  VW-EYE            PIC X(4).
           05  VW-REQUEST        PIC X(8).
           05  VW-REPLY          PIC X(8).
       PROCEDURE DIVISION.
       SUB-MAIN.
           EXEC CICS ADDRESS EIB(WS-EPTR)
           END-EXEC
           SET ADDRESS OF LS-EIB TO WS-EPTR
           EXEC CICS ADDRESS COMMAREA(WS-PTR)
           END-EXEC
           MOVE 'C1 ' TO CLOG-TAG
           MOVE VE-CALEN TO CLOG-LEN
           IF VE-CALEN = EIBCALEN
               MOVE 'Y' TO CLOG-SAME
           END-IF
           IF WS-PTR-X = X'FF000000'
               MOVE 'ABSENT' TO CLOG-P
           ELSE
               MOVE 'PRESENT' TO CLOG-P
               SET ADDRESS OF LS-VIEW TO WS-PTR
               MOVE VW-EYE TO CLOG-EYE
               MOVE VW-REQUEST TO CLOG-REQ
               MOVE 'PONG' TO VW-REPLY
           END-IF
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-CLOG)
                     LENGTH(53)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
