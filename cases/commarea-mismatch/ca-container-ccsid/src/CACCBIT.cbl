       IDENTIFICATION DIVISION.
       PROGRAM-ID. CACCBIT.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-container-ccsid         *
      * Original program (Apache-2.0).                                *
      * A BIT container: INTOCCSID on a GET, FROMCCSID on a PUT. The  *
      * bytes the GETs return go to TS queue CCRAW, results to CCLOG. *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CHAN               PIC X(16) VALUE 'CCBITCHN'.
       01  WS-SRC                PIC X(6)  VALUE 'ABC123'.
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
           EXEC CICS PUT CONTAINER('RAWB') CHANNEL(WS-CHAN)
                     FROM(WS-SRC) BIT
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT1' TO LG-TAG
           PERFORM LOG-RESP
      * INTOCCSID on a BIT container: CCSIDERR, data unconverted.
           MOVE 6 TO WS-LEN
           MOVE SPACES TO WS-OUT
           EXEC CICS GET CONTAINER('RAWB') CHANNEL(WS-CHAN)
                     INTO(WS-OUT) FLENGTH(WS-LEN)
                     INTOCCSID(WS-C1208)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET1' TO LG-TAG
           PERFORM LOG-GET
      * No INTOCCSID: nothing to convert, NORMAL.
           MOVE 6 TO WS-LEN
           MOVE SPACES TO WS-OUT
           EXEC CICS GET CONTAINER('RAWB') CHANNEL(WS-CHAN)
                     INTO(WS-OUT) FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET2' TO LG-TAG
           PERFORM LOG-GET
      * BIT with FROMCCSID on a PUT is invalid.
           EXEC CICS PUT CONTAINER('BADB') CHANNEL(WS-CHAN)
                     FROM(WS-SRC) BIT FROMCCSID(WS-C037)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT2' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS RETURN END-EXEC.
       LOG-GET.
           PERFORM LOG-RESP
           EXEC CICS WRITEQ TS QUEUE('CCRAW') FROM(WS-OUT) END-EXEC.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           EXEC CICS WRITEQ TS QUEUE('CCLOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
