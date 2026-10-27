       IDENTIFICATION DIVISION.
       PROGRAM-ID. CABRERR.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-channel-browse          *
      * Original program (Apache-2.0).                                *
      * Deletes a channel that does not exist with neither RESP nor   *
      * HANDLE CONDITION: CICS's default action.                      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATA               PIC X(8) VALUE 'ONLY-ONE'.
           COPY CALOG.
       PROCEDURE DIVISION.
       ERR-MAIN.
           INITIALIZE WS-LOG
           EXEC CICS PUT CONTAINER('ONE') CHANNEL('CABERRCHAN')
                     FROM(WS-DATA)
           END-EXEC
           MOVE 'PUTE' TO LG-TAG
           PERFORM LOG-ENTRY
           EXEC CICS DELETE CHANNEL('CABNOCHAN')
           END-EXEC
           MOVE 'BAD2' TO LG-TAG
           PERFORM LOG-ENTRY
           EXEC CICS RETURN END-EXEC.
       LOG-ENTRY.
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
