       IDENTIFICATION DIVISION.
       PROGRAM-ID. CACHSUB.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-channel-containers      *
      * Original program (Apache-2.0).                                *
      * LINKed with a channel: reads its containers through the       *
      * current channel (no CHANNEL option), short and missing ones   *
      * included, deletes one and adds a reply for its caller.        *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CUR                PIC X(16).
       01  WS-AREA               PIC X(20).
       01  WS-SHORT              PIC X(4).
       01  WS-BIN                PIC S9(8) COMP VALUE 0.
       01  WS-REPLY              PIC X(11) VALUE 'DONE-BY-SUB'.
       01  WS-LEN                PIC S9(8) COMP.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY CALOG.
       PROCEDURE DIVISION.
       SUB-MAIN.
           INITIALIZE WS-LOG
           EXEC CICS ASSIGN CHANNEL(WS-CUR) END-EXEC
           MOVE 'ASG1' TO LG-TAG
           MOVE WS-CUR TO LG-DATA
           PERFORM LOG-ENTRY
           MOVE 20 TO WS-LEN
           MOVE SPACES TO WS-AREA
           EXEC CICS GET CONTAINER('REQUEST') INTO(WS-AREA)
                     FLENGTH(WS-LEN) RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET3' TO LG-TAG
           MOVE WS-LEN TO LG-LEN
           MOVE WS-AREA(1:WS-LEN) TO LG-DATA
           PERFORM LOG-RESP
           MOVE 4 TO WS-LEN
           EXEC CICS GET CONTAINER('REQUEST') INTO(WS-SHORT)
                     FLENGTH(WS-LEN) RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET4' TO LG-TAG
           MOVE WS-LEN TO LG-LEN
           MOVE WS-SHORT TO LG-DATA
           PERFORM LOG-RESP
           EXEC CICS GET CONTAINER('COUNT') NODATA FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET5' TO LG-TAG
           MOVE WS-LEN TO LG-LEN
           PERFORM LOG-RESP
           MOVE 4 TO WS-LEN
           EXEC CICS GET CONTAINER('COUNT') INTO(WS-BIN)
                     FLENGTH(WS-LEN) RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET6' TO LG-TAG
           MOVE WS-BIN TO LG-LEN
           PERFORM LOG-RESP
           EXEC CICS GET CONTAINER('NOSUCH') INTO(WS-AREA)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET7' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS GET CONTAINER('REQUEST') CHANNEL('CAOTHER')
                     INTO(WS-AREA) RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET8' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS DELETE CONTAINER('COUNT')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'DEL1' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS PUT CONTAINER('REPLY') FROM(WS-REPLY)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT5' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS HANDLE CONDITION CONTAINERERR(SUB-NOCONT)
           END-EXEC
           EXEC CICS DELETE CONTAINER('COUNT') END-EXEC
           MOVE 'BAD1' TO LG-TAG
           PERFORM LOG-ENTRY
           EXEC CICS RETURN END-EXEC.
       SUB-NOCONT.
           MOVE 'HND1' TO LG-TAG
           MOVE EIBRESP TO LG-RESP
           MOVE EIBRESP2 TO LG-RESP2
           PERFORM LOG-ENTRY
           EXEC CICS RETURN END-EXEC.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           PERFORM LOG-ENTRY.
       LOG-ENTRY.
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
