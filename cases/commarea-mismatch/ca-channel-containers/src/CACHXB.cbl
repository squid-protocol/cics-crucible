       IDENTIFICATION DIVISION.
       PROGRAM-ID. CACHXB.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-channel-containers      *
      * Original program (Apache-2.0).                                *
      * XCTLed to with the channel: reads the reply the LINKed        *
      * program left, then makes a channel of its own.                *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CUR                PIC X(16).
       01  WS-AREA               PIC X(20).
       01  WS-OWN                PIC X(10) VALUE 'NEWCHANNEL'.
       01  WS-LEN                PIC S9(8) COMP.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY CALOG.
       PROCEDURE DIVISION.
       XB-MAIN.
           INITIALIZE WS-LOG
           EXEC CICS ASSIGN CHANNEL(WS-CUR) END-EXEC
           MOVE 'ASG2' TO LG-TAG
           MOVE WS-CUR TO LG-DATA
           PERFORM LOG-ENTRY
           MOVE 20 TO WS-LEN
           MOVE SPACES TO WS-AREA
           EXEC CICS GET CONTAINER('REPLY') INTO(WS-AREA)
                     FLENGTH(WS-LEN) RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET9' TO LG-TAG
           MOVE WS-LEN TO LG-LEN
           MOVE WS-AREA(1:WS-LEN) TO LG-DATA
           PERFORM LOG-RESP
           EXEC CICS PUT CONTAINER('FINAL') CHANNEL('CANEWCHAN')
                     FROM(WS-OWN) RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT6' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS GET CONTAINER('FINAL') CHANNEL('CANEWCHAN')
                     NODATA FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GETA' TO LG-TAG
           MOVE WS-LEN TO LG-LEN
           PERFORM LOG-RESP
           EXEC CICS RETURN END-EXEC.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           PERFORM LOG-ENTRY.
       LOG-ENTRY.
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
