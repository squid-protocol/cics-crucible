       IDENTIFICATION DIVISION.
       PROGRAM-ID. CACHAN.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-channel-containers      *
      * Original program (Apache-2.0).                                *
      * Builds a channel instead of a COMMAREA: a CHAR container, an  *
      * APPEND to it, a BIT container; LINKs a program with the       *
      * channel, reads back what it changed, then XCTLs with it.      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CHAN               PIC X(16) VALUE 'CAREQUEST'.
       01  WS-CUR                PIC X(16).
       01  WS-REQ                PIC X(10) VALUE 'ABCDEFGHIJ'.
       01  WS-MORE               PIC X(3)  VALUE 'KLM'.
       01  WS-BIN                PIC S9(8) COMP VALUE 258.
       01  WS-AREA               PIC X(20).
       01  WS-LEN                PIC S9(8) COMP.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY CALOG.
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
           EXEC CICS ASSIGN CHANNEL(WS-CUR) END-EXEC
           MOVE 'ASG0' TO LG-TAG
           MOVE WS-CUR TO LG-DATA
           PERFORM LOG-ENTRY
           MOVE 20 TO WS-LEN
           EXEC CICS GET CONTAINER('REQUEST') INTO(WS-AREA)
                     FLENGTH(WS-LEN) RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET0' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS PUT CONTAINER('REQUEST') CHANNEL(WS-CHAN)
                     FROM(WS-REQ) CHAR RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT1' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS PUT CONTAINER('REQUEST') CHANNEL(WS-CHAN)
                     FROM(WS-MORE) APPEND
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT2' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS PUT CONTAINER('COUNT') CHANNEL(WS-CHAN)
                     FROM(WS-BIN) FLENGTH(LENGTH OF WS-BIN) BIT
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT3' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS LINK PROGRAM('CACHSUB') CHANNEL(WS-CHAN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'LNK1' TO LG-TAG
           PERFORM LOG-RESP
           MOVE 20 TO WS-LEN
           MOVE SPACES TO WS-AREA
           EXEC CICS GET CONTAINER('REPLY') CHANNEL(WS-CHAN)
                     INTO(WS-AREA) FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET1' TO LG-TAG
           MOVE WS-LEN TO LG-LEN
           MOVE WS-AREA(1:WS-LEN) TO LG-DATA
           PERFORM LOG-RESP
           EXEC CICS GET CONTAINER('COUNT') CHANNEL(WS-CHAN)
                     NODATA FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET2' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS XCTL PROGRAM('CACHXB') CHANNEL(WS-CHAN)
           END-EXEC
           MOVE 'BAD0' TO LG-TAG
           PERFORM LOG-ENTRY
           EXEC CICS RETURN END-EXEC.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           PERFORM LOG-ENTRY.
       LOG-ENTRY.
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
