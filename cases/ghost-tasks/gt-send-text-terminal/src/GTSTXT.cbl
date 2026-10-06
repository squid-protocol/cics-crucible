       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTSTXT.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-send-text-terminal            *
      * Original program (Apache-2.0).                                *
      * GT41, a terminal task: SEND TEXT with TERMINAL (the default   *
      * output disposition, the task's principal facility), its RESP  *
      * logged to TS queue GTLOG, then the same SEND TEXT without     *
      * TERMINAL. Then START GT42 at terminal T001, and GT42 with no  *
      * terminal.                                                     *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-RESP               PIC S9(8) COMP VALUE -1.
       01  WS-LINE1              PIC X(30)
                                 VALUE 'GT41 SENT WITH TERMINAL'.
       01  WS-LINE2              PIC X(30)
                                 VALUE 'GT41 SENT WITHOUT TERMINAL'.
       01  WS-RLOG.
           05  FILLER            PIC X(7)  VALUE 'GT41 R='.
           05  RLOG-R            PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           EXEC CICS SEND TEXT FROM(WS-LINE1)
                     TERMINAL WAIT
                     FREEKB
                     ERASE
                     RESP(WS-RESP)
           END-EXEC
           MOVE WS-RESP TO RLOG-R
           EXEC CICS WRITEQ TS QUEUE('GTLOG') FROM(WS-RLOG)
                     LENGTH(9)
           END-EXEC
           EXEC CICS SEND TEXT FROM(WS-LINE2) LENGTH(30)
                     WAIT FREEKB ERASE
           END-EXEC
           EXEC CICS START TRANSID('GT42') INTERVAL(10)
                     TERMID('T001')
           END-EXEC
           EXEC CICS START TRANSID('GT42') INTERVAL(0)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
