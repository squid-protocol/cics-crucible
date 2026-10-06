       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTSTXS.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-send-text-terminal            *
      * Original program (Apache-2.0).                                *
      * GT42, started by GT41: asks ASSIGN FACILITY (with RESP) for   *
      * its principal facility. With one, it sends a line naming it   *
      * with SEND TEXT ... TERMINAL; with none, it logs that to TS    *
      * queue GTLOG and sends nothing.                                *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FAC                PIC X(4)  VALUE SPACES.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-LINE.
           05  FILLER            PIC X(13) VALUE 'GT42 SENT TO '.
           05  LINE-FAC          PIC X(4)  VALUE SPACES.
           05  FILLER            PIC X(13) VALUE SPACES.
       01  WS-NOTERM             PIC X(16) VALUE 'GT42 NO TERMINAL'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS ASSIGN FACILITY(WS-FAC) RESP(WS-RESP)
           END-EXEC
           IF WS-RESP = 0
               MOVE WS-FAC TO LINE-FAC
               EXEC CICS SEND TEXT FROM(WS-LINE)
                         TERMINAL WAIT
                         FREEKB
                         ERASE
               END-EXEC
           ELSE
               EXEC CICS WRITEQ TS QUEUE('GTLOG') FROM(WS-NOTERM)
                         LENGTH(16)
               END-EXEC
           END-IF
           EXEC CICS RETURN END-EXEC.
