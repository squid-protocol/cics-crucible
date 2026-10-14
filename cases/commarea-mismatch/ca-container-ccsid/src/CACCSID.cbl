       IDENTIFICATION DIVISION.
       PROGRAM-ID. CACCSID.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-container-ccsid         *
      * Original program (Apache-2.0).                                *
      * CHAR containers put with FROMCCSID (037, 1208) or none and    *
      * got with INTOCCSID (1208, 037) or none; the bytes each GET    *
      * returns go to TS queue CCRAW, the command results to CCLOG.   *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CHAN               PIC X(16) VALUE 'CCCHAN'.
       01  WS-SRC                PIC X(6)  VALUE 'ABC123'.
       01  WS-ASC                PIC X(6)  VALUE X'414243313233'.
       01  WS-C037               PIC S9(8) COMP VALUE 37.
       01  WS-C1208              PIC S9(8) COMP VALUE 1208.
       01  WS-OUT                PIC X(6).
       01  WS-LEN                PIC S9(8) COMP.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY CCLOG.
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
      * No CHANNEL, no current channel: INTOCCSID is not valid.
           MOVE 6 TO WS-LEN
           EXEC CICS GET CONTAINER('ONE') INTO(WS-OUT)
                     FLENGTH(WS-LEN) INTOCCSID(WS-C1208)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET0' TO LG-TAG
           PERFORM LOG-RESP
      * ONE: CHAR, put as CCSID 037.
           EXEC CICS PUT CONTAINER('ONE') CHANNEL(WS-CHAN)
                     FROM(WS-SRC) FROMCCSID(WS-C037)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT1' TO LG-TAG
           PERFORM LOG-RESP
           MOVE 6 TO WS-LEN
           EXEC CICS GET CONTAINER('ONE') CHANNEL(WS-CHAN)
                     INTO(WS-OUT) FLENGTH(WS-LEN)
                     INTOCCSID(WS-C1208)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET1' TO LG-TAG
           PERFORM LOG-GET
           MOVE 6 TO WS-LEN
           EXEC CICS GET CONTAINER('ONE') CHANNEL(WS-CHAN)
                     INTO(WS-OUT) FLENGTH(WS-LEN)
                     INTOCCSID(WS-C037)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET2' TO LG-TAG
           PERFORM LOG-GET
           MOVE 6 TO WS-LEN
           EXEC CICS GET CONTAINER('ONE') CHANNEL(WS-CHAN)
                     INTO(WS-OUT) FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET3' TO LG-TAG
           PERFORM LOG-GET
      * TWO: CHAR, put as CCSID 1208 from ASCII bytes.
           EXEC CICS PUT CONTAINER('TWO') CHANNEL(WS-CHAN)
                     FROM(WS-ASC) FROMCCSID(WS-C1208)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT2' TO LG-TAG
           PERFORM LOG-RESP
           MOVE 6 TO WS-LEN
           EXEC CICS GET CONTAINER('TWO') CHANNEL(WS-CHAN)
                     INTO(WS-OUT) FLENGTH(WS-LEN)
                     INTOCCSID(WS-C1208)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET4' TO LG-TAG
           PERFORM LOG-GET
           MOVE 6 TO WS-LEN
           EXEC CICS GET CONTAINER('TWO') CHANNEL(WS-CHAN)
                     INTO(WS-OUT) FLENGTH(WS-LEN)
                     INTOCCSID(WS-C037)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET5' TO LG-TAG
           PERFORM LOG-GET
           MOVE 6 TO WS-LEN
           EXEC CICS GET CONTAINER('TWO') CHANNEL(WS-CHAN)
                     INTO(WS-OUT) FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET6' TO LG-TAG
           PERFORM LOG-GET
      * THREE: DATATYPE(CHAR) and no CCSID: the region's CCSID.
           EXEC CICS PUT CONTAINER('THREE') CHANNEL(WS-CHAN)
                     FROM(WS-SRC) DATATYPE(CHAR)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT3' TO LG-TAG
           PERFORM LOG-RESP
           MOVE 6 TO WS-LEN
           EXEC CICS GET CONTAINER('THREE') CHANNEL(WS-CHAN)
                     INTO(WS-OUT) FLENGTH(WS-LEN)
                     INTOCCSID(WS-C1208)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET7' TO LG-TAG
           PERFORM LOG-GET
           EXEC CICS RETURN END-EXEC.
       LOG-GET.
           MOVE WS-LEN TO LG-LEN
           PERFORM LOG-RESP
           EXEC CICS WRITEQ TS QUEUE('CCRAW') FROM(WS-OUT) END-EXEC.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           EXEC CICS WRITEQ TS QUEUE('CCLOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
