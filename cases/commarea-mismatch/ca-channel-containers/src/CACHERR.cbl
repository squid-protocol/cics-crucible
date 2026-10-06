       IDENTIFICATION DIVISION.
       PROGRAM-ID. CACHERR.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-channel-containers      *
      * Original program (Apache-2.0).                                *
      * Reads a container its channel does not have, with neither     *
      * RESP nor HANDLE CONDITION: CICS's default action.             *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATA               PIC X(8) VALUE 'ONLY-ONE'.
       01  WS-AREA               PIC X(8).
           COPY CALOG.
       PROCEDURE DIVISION.
       ERR-MAIN.
           INITIALIZE WS-LOG
           EXEC CICS PUT CONTAINER('ONE') CHANNEL('CAERRCHAN')
                     FROM(WS-DATA)
           END-EXEC
           MOVE 'PUTE' TO LG-TAG
           PERFORM LOG-ENTRY
           EXEC CICS GET CONTAINER('TWO') CHANNEL('CAERRCHAN')
                     INTO(WS-AREA)
           END-EXEC
           MOVE 'BAD2' TO LG-TAG
           PERFORM LOG-ENTRY
           EXEC CICS RETURN END-EXEC.
       LOG-ENTRY.
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
