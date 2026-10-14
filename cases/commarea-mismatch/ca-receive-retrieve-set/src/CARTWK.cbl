       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARTWK.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-receive-retrieve-set    *
      * Original program (Apache-2.0).                                *
      * The background task (transaction CA0E, no terminal). It       *
      * RETRIEVEs SET into a POINTER variable, views the data with    *
      * SET ADDRESS OF, then RETRIEVEs again. Each result is a record *
      * in TS queue RSLOG; LENGTH and the view are read only on       *
      * NORMAL, and the loop ends at the first other response.        *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PTR                POINTER.
       01  WS-LEN                PIC S9(4) COMP VALUE 0.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-N                  PIC 9     VALUE 0.
       01  WS-MORE               PIC X     VALUE 'Y'.
           COPY RSLOG.
       LINKAGE SECTION.
       01  LS-DATA               PIC X(256).
       PROCEDURE DIVISION.
       MAIN-PARA.
           PERFORM UNTIL WS-MORE = 'N'
               ADD 1 TO WS-N
               INITIALIZE WS-LOG
               EXEC CICS RETRIEVE SET(WS-PTR) LENGTH(WS-LEN)
                         RESP(WS-RESP)
               END-EXEC
               MOVE 'RT0' TO LG-TAG(1:3)
               MOVE WS-N TO LG-TAG(4:1)
               MOVE WS-RESP TO LG-RESP
               IF WS-RESP = 0
                   SET ADDRESS OF LS-DATA TO WS-PTR
                   MOVE WS-LEN TO LG-LEN
                   MOVE LS-DATA(1:WS-LEN) TO LG-DATA
               ELSE
                   MOVE 'N' TO WS-MORE
               END-IF
               EXEC CICS WRITEQ TS QUEUE('RSLOG') FROM(WS-LOG)
               END-EXEC
           END-PERFORM
           EXEC CICS RETURN END-EXEC.
