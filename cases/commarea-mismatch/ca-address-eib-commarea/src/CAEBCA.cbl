       IDENTIFICATION DIVISION.
       PROGRAM-ID. CAEBCA.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-address-eib-commarea    *
      * Original program (Apache-2.0).                                *
      * CA0K, a mode typed after the transid:                         *
      *   Q  ADDRESS EIB and SET ADDRESS OF a view of the whole EIB,  *
      *      then READQ TD of a queue the CSD does not define         *
      *      (QIDERR): the view, read after the command, holds the    *
      *      command's EIBRESP                                        *
      *   W  LINK to CAEBSB with COMMAREA(WS-AREA): the callee reads  *
      *      EIBCALEN through its EIB view and writes through its     *
      *      ADDRESS COMMAREA view                                    *
      *   N  ADDRESS COMMAREA in the terminal task, which has none    *
      * No program names DFHCOMMAREA. ADDRESS is not an event: each   *
      * result is a breadcrumb in TS queue CALOG and in the report.   *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-PTR                POINTER.
       01  WS-PTR-X REDEFINES WS-PTR PIC X(4).
       01  WS-EPTR               POINTER.
       01  WS-PSTATE             PIC X(7)  VALUE SPACES.
       01  WS-SAME               PIC X     VALUE 'N'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP-D             PIC 9(4)  VALUE 0.
       01  WS-CALEN-D            PIC 9(4)  VALUE 0.
       01  WS-QN                 PIC X(4)  VALUE 'CANQ'.
       01  WS-QAREA              PIC X(8)  VALUE 'XXXXXXXX'.
       01  WS-QLEN               PIC S9(4) COMP VALUE 8.
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
           05  FILLER            PIC X(6)  VALUE ' SAME='.
           05  CLOG-SAME         PIC X     VALUE SPACE.
           05  FILLER            PIC X(5)  VALUE ' EYE='.
           05  CLOG-EYE          PIC X(4)  VALUE SPACES.
           05  FILLER            PIC X(5)  VALUE ' REQ='.
           05  CLOG-REQ          PIC X(8)  VALUE SPACES.
       01  WS-QLOG.
           05  QLOG-TAG          PIC X(3)  VALUE 'Q1 '.
           05  FILLER            PIC X(5)  VALUE 'RESP='.
           05  QLOG-RESP         PIC 9(4)  VALUE 0.
           05  FILLER            PIC X(6)  VALUE ' SAME='.
           05  QLOG-SAME         PIC X     VALUE SPACE.
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
           05  VE-AID            PIC X.
           05  VE-FN             PIC X(2).
           05  VE-RCODE          PIC X(6).
           05  VE-DS             PIC X(8).
           05  VE-REQID          PIC X(8).
           05  VE-RSRCE          PIC X(8).
           05  VE-FLAGS          PIC X(11).
           05  VE-ERRCD          PIC X(4).
           05  VE-SYNRB          PIC X.
           05  VE-NODAT          PIC X.
           05  VE-RESP           PIC S9(8) COMP.
           05  VE-RESP2          PIC S9(8) COMP.
           05  VE-RLDBK          PIC X.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'Q'
                   PERFORM QIDERR-PARA
               WHEN 'W'
                   PERFORM LINK-PARA
               WHEN 'N'
                   PERFORM NONE-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-REPORT) LENGTH(80) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       QIDERR-PARA.
           EXEC CICS ADDRESS EIB(WS-EPTR)
           END-EXEC
           SET ADDRESS OF LS-EIB TO WS-EPTR
           EXEC CICS READQ TD QUEUE(WS-QN) INTO(WS-QAREA)
                     LENGTH(WS-QLEN) RESP(WS-RESP)
           END-EXEC
           MOVE 'N' TO WS-SAME
           IF VE-RESP = EIBRESP AND VE-RESP = WS-RESP
               MOVE 'Y' TO WS-SAME
           END-IF
           MOVE VE-RESP TO QLOG-RESP
           MOVE WS-SAME TO QLOG-SAME
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-QLOG)
                     LENGTH(19)
           END-EXEC
           MOVE VE-RESP TO WS-RESP-D
           STRING 'MODE=Q RESP=' WS-RESP-D ' SAME=' WS-SAME
               DELIMITED BY SIZE INTO WS-REPORT.
       LINK-PARA.
           INITIALIZE WS-AREA
           MOVE 'CAEB' TO AD-EYE
           MOVE 'PING' TO AD-REQUEST
           EXEC CICS LINK PROGRAM('CAEBSB') COMMAREA(WS-AREA)
                     LENGTH(20)
           END-EXEC
           STRING 'MODE=W REPLY=' AD-REPLY
               DELIMITED BY SIZE INTO WS-REPORT.
       NONE-PARA.
           EXEC CICS ADDRESS EIB(WS-EPTR)
           END-EXEC
           SET ADDRESS OF LS-EIB TO WS-EPTR
           EXEC CICS ADDRESS COMMAREA(WS-PTR)
           END-EXEC
           IF WS-PTR-X = X'FF000000'
               MOVE 'ABSENT' TO WS-PSTATE
           ELSE
               MOVE 'PRESENT' TO WS-PSTATE
           END-IF
           MOVE 'N' TO WS-SAME
           IF VE-CALEN = EIBCALEN
               MOVE 'Y' TO WS-SAME
           END-IF
           MOVE 'N1 ' TO CLOG-TAG
           MOVE WS-PSTATE TO CLOG-P
           MOVE VE-CALEN TO CLOG-LEN
           MOVE WS-SAME TO CLOG-SAME
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-CLOG)
                     LENGTH(53)
           END-EXEC
           MOVE VE-CALEN TO WS-CALEN-D
           STRING 'MODE=N P=' WS-PSTATE ' CALEN=' WS-CALEN-D
               DELIMITED BY SIZE INTO WS-REPORT.
