       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWORK.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-start-retrieve                *
      * Original program (Apache-2.0).                                *
      * The background task (transaction GT02, no terminal). It       *
      * RETRIEVEs until the response is neither NORMAL nor LENGERR,   *
      * and logs each response to TS queue GTLOG.                     *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATA               PIC X(20) VALUE SPACES.
       01  WS-LEN                PIC S9(4) COMP VALUE 0.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-MORE               PIC X     VALUE 'Y'.
       01  WS-LOG.
           05  FILLER            PIC X(2)  VALUE 'R='.
           05  LOG-RESP          PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' L='.
           05  LOG-LEN           PIC 9(4)  VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' D='.
           05  LOG-DATA          PIC X(20) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           PERFORM UNTIL WS-MORE = 'N'
               MOVE SPACES TO WS-DATA
               MOVE 20 TO WS-LEN
               EXEC CICS RETRIEVE INTO(WS-DATA) LENGTH(WS-LEN)
                         RESP(WS-RESP)
               END-EXEC
               MOVE WS-RESP TO LOG-RESP
               IF WS-RESP = DFHRESP(NORMAL)
                  OR WS-RESP = DFHRESP(LENGERR)
                   MOVE WS-LEN TO LOG-LEN
                   MOVE WS-DATA TO LOG-DATA
               ELSE
                   MOVE 0 TO LOG-LEN
                   MOVE SPACES TO LOG-DATA
                   MOVE 'N' TO WS-MORE
               END-IF
               EXEC CICS WRITEQ TS QUEUE('GTLOG') FROM(WS-LOG)
                         LENGTH(34)
               END-EXEC
           END-PERFORM
           EXEC CICS RETURN END-EXEC.
