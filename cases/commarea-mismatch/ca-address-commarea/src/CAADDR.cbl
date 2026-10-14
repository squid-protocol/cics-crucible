       IDENTIFICATION DIVISION.
       PROGRAM-ID. CAADDR.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-address-commarea        *
      * Original program (Apache-2.0).                                *
      * CA02, a mode typed after the transid:                         *
      *   L  LINK to CAADSB with COMMAREA(WS-AREA): the callee gets   *
      *      the address (ADDRESS COMMAREA) and sees and writes the   *
      *      caller's bytes                                           *
      *   N  ADDRESS COMMAREA here (a task started from a terminal    *
      *      has no COMMAREA) and in a callee LINKed with none        *
      *   E  ADDRESS EIB, SET ADDRESS OF a view of the EIB, and       *
      *      compare the view with the DFHEIBLK fields                *
      * ADDRESS is not an event: each result is a breadcrumb in TS    *
      * queue CALOG and in the SEND TEXT report.                      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-PTR                POINTER.
       01  WS-PTR-X REDEFINES WS-PTR PIC X(4).
       01  WS-PSTATE             PIC X(7)  VALUE SPACES.
       01  WS-SAME               PIC X     VALUE 'N'.
       01  WS-CALEN-D            PIC 9(4)  VALUE 0.
       01  WS-REPORT             PIC X(80) VALUE SPACES.
       01  WS-AREA.
           05  AD-EYE            PIC X(4).
           05  AD-REQUEST        PIC X(8).
           05  AD-REPLY          PIC X(8).
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' P='.
           05  CLOG-P            PIC X(7)  VALUE SPACES.
           05  FILLER            PIC X(7)  VALUE ' CALEN='.
           05  CLOG-LEN          PIC 9(4)  VALUE 0.
           05  FILLER            PIC X(5)  VALUE ' EYE='.
           05  CLOG-EYE          PIC X(4)  VALUE SPACES.
           05  FILLER            PIC X(5)  VALUE ' REQ='.
           05  CLOG-REQ          PIC X(8)  VALUE SPACES.
       01  WS-ELOG.
           05  ELOG-TAG          PIC X(3)  VALUE 'E1 '.
           05  FILLER            PIC X(4)  VALUE 'TRN='.
           05  ELOG-TRN          PIC X(4)  VALUE SPACES.
           05  FILLER            PIC X(5)  VALUE ' TRM='.
           05  ELOG-TRM          PIC X(4)  VALUE SPACES.
           05  FILLER            PIC X(6)  VALUE ' SAME='.
           05  ELOG-SAME         PIC X     VALUE SPACE.
       LINKAGE SECTION.
       01  LS-EIB.
           05  VE-TIME           PIC S9(7) COMP-3.
           05  VE-DATE           PIC S9(7) COMP-3.
           05  VE-TRNID          PIC X(4).
           05  VE-TASKN          PIC S9(7) COMP-3.
           05  VE-TRMID          PIC X(4).
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'L'
                   PERFORM LINK-PARA
               WHEN 'N'
                   PERFORM NONE-PARA
               WHEN 'E'
                   PERFORM EIB-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-REPORT) LENGTH(80) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       LINK-PARA.
           INITIALIZE WS-AREA
           MOVE 'CADR' TO AD-EYE
           MOVE 'PING' TO AD-REQUEST
           EXEC CICS LINK PROGRAM('CAADSB') COMMAREA(WS-AREA)
                     LENGTH(20)
           END-EXEC
           STRING 'MODE=L REPLY=' AD-REPLY
               DELIMITED BY SIZE INTO WS-REPORT.
       NONE-PARA.
           EXEC CICS ADDRESS COMMAREA(WS-PTR)
           END-EXEC
           MOVE 'N1 ' TO CLOG-TAG
           MOVE EIBCALEN TO CLOG-LEN
           MOVE EIBCALEN TO WS-CALEN-D
           IF WS-PTR-X = X'FF000000'
               MOVE 'ABSENT' TO WS-PSTATE
           ELSE
               MOVE 'PRESENT' TO WS-PSTATE
           END-IF
           MOVE WS-PSTATE TO CLOG-P
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-CLOG)
                     LENGTH(46)
           END-EXEC
           EXEC CICS LINK PROGRAM('CAADSB')
           END-EXEC
           STRING 'MODE=N P=' WS-PSTATE ' CALEN=' WS-CALEN-D
               DELIMITED BY SIZE INTO WS-REPORT.
       EIB-PARA.
           EXEC CICS ADDRESS EIB(WS-PTR)
           END-EXEC
           SET ADDRESS OF LS-EIB TO WS-PTR
           MOVE 'N' TO WS-SAME
           IF VE-TRNID = EIBTRNID AND VE-TRMID = EIBTRMID
              AND VE-TASKN = EIBTASKN AND VE-TIME = EIBTIME
              AND VE-DATE = EIBDATE
               MOVE 'Y' TO WS-SAME
           END-IF
           MOVE VE-TRNID TO ELOG-TRN
           MOVE VE-TRMID TO ELOG-TRM
           MOVE WS-SAME TO ELOG-SAME
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-ELOG)
                     LENGTH(27)
           END-EXEC
           STRING 'MODE=E TRN=' VE-TRNID ' TRM=' VE-TRMID
                  ' SAME=' WS-SAME
               DELIMITED BY SIZE INTO WS-REPORT.
