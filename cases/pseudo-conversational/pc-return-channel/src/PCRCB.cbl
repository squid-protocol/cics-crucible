       IDENTIFICATION DIVISION.
       PROGRAM-ID. PCRCB.
      *---------------------------------------------------------------*
      * cics-crucible  pseudo-conversational / pc-return-channel      *
      * Original program (Apache-2.0).                                *
      * PC62, the transaction a RETURN CHANNEL starts. It names no    *
      * channel in its commands: it reads the container STATE through *
      * its current channel and acts on the stage byte:               *
      *   C  log and end                                              *
      *   1  replace STATE, add EXTRA, RETURN CHANNEL (current name)  *
      *   2  read and delete EXTRA, replace STATE, RETURN CHANNEL     *
      *   3  try EXTRA again (gone), log and end                      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CUR                PIC X(16).
       01  WS-STATE.
           05  ST-STAGE          PIC X.
           05  ST-TEXT           PIC X(7).
       01  WS-NEW1               PIC X(8)  VALUE '2CHANGED'.
       01  WS-NEW2               PIC X(8)  VALUE '3AGAIN-2'.
       01  WS-EXTRA              PIC X(5)  VALUE 'EXTRA'.
       01  WS-LEN                PIC S9(8) COMP.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY PCRLOG.
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
           EXEC CICS ASSIGN CHANNEL(WS-CUR) END-EXEC
           MOVE 'ASGB' TO LG-TAG
           MOVE WS-CUR TO LG-DATA
           PERFORM LOG-ENTRY
           MOVE 8 TO WS-LEN
           EXEC CICS GET CONTAINER('STATE') INTO(WS-STATE)
                     FLENGTH(WS-LEN) RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GETB' TO LG-TAG
           MOVE WS-LEN TO LG-LEN
           MOVE WS-STATE TO LG-DATA
           PERFORM LOG-RESP
           EVALUATE ST-STAGE
               WHEN '1'
                   PERFORM STAGE-1
               WHEN '2'
                   PERFORM STAGE-2
               WHEN '3'
                   PERFORM STAGE-3
           END-EVALUATE
           EXEC CICS RETURN END-EXEC.
       STAGE-1.
           EXEC CICS PUT CONTAINER('STATE') FROM(WS-NEW1) CHAR
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUTS' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS PUT CONTAINER('EXTRA') FROM(WS-EXTRA) CHAR
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUTX' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS RETURN TRANSID('PC62') CHANNEL(WS-CUR)
           END-EXEC.
       STAGE-2.
           PERFORM GET-EXTRA
           EXEC CICS DELETE CONTAINER('EXTRA')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'DELE' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS PUT CONTAINER('STATE') FROM(WS-NEW2) CHAR
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUTS' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS RETURN TRANSID('PC62') CHANNEL(WS-CUR)
           END-EXEC.
       STAGE-3.
           PERFORM GET-EXTRA.
       GET-EXTRA.
           MOVE 5 TO WS-LEN
           MOVE SPACES TO WS-EXTRA
           EXEC CICS GET CONTAINER('EXTRA') INTO(WS-EXTRA)
                     FLENGTH(WS-LEN) RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GETX' TO LG-TAG
           IF WS-RESP = 0
               MOVE WS-LEN TO LG-LEN
               MOVE WS-EXTRA TO LG-DATA
           END-IF
           PERFORM LOG-RESP.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           PERFORM LOG-ENTRY.
       LOG-ENTRY.
           EXEC CICS WRITEQ TS QUEUE('PCRLOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
