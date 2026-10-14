       IDENTIFICATION DIVISION.
       PROGRAM-ID. CABOFFX.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-container-byteoffset    *
      * Original program (Apache-2.0).                                *
      * GET CONTAINER BYTEOFFSET at and past the end of a 10-byte     *
      * BIT container: the last byte (NORMAL), offset = length and    *
      * offset > length (LENGERR), then a read from 0 to show the     *
      * container is unchanged. Bytes go to BORAW, results to BOLOG.  *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CHAN               PIC X(16) VALUE 'BOCHAN'.
       01  WS-SRC                PIC X(10) VALUE 'ABCDEFGHIJ'.
       01  WS-OUT                PIC X(16).
       01  WS-OFF                PIC S9(8) COMP.
       01  WS-LEN                PIC S9(8) COMP.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY CCLOG.
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
           EXEC CICS PUT CONTAINER('DATA') CHANNEL(WS-CHAN)
                     FROM(WS-SRC) BIT
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT1' TO LG-TAG
           PERFORM LOG-RESP
           MOVE 9 TO WS-OFF
           MOVE 16 TO WS-LEN
           PERFORM GET-AT
           MOVE 'GET1' TO LG-TAG
           PERFORM LOG-GET
      * Offset equal to the length: LENGERR, nothing logged but codes.
           MOVE 10 TO WS-OFF
           MOVE 16 TO WS-LEN
           PERFORM GET-AT
           MOVE 'GET2' TO LG-TAG
           PERFORM LOG-RESP
      * Offset past the length.
           MOVE 15 TO WS-OFF
           MOVE 16 TO WS-LEN
           PERFORM GET-AT
           MOVE 'GET3' TO LG-TAG
           PERFORM LOG-RESP
      * The container is as it was.
           MOVE 0 TO WS-OFF
           MOVE 16 TO WS-LEN
           PERFORM GET-AT
           MOVE 'GET4' TO LG-TAG
           PERFORM LOG-GET
           EXEC CICS RETURN END-EXEC.
       GET-AT.
           MOVE SPACES TO WS-OUT
           EXEC CICS GET CONTAINER('DATA') CHANNEL(WS-CHAN)
                     INTO(WS-OUT) FLENGTH(WS-LEN)
                     BYTEOFFSET(WS-OFF)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       LOG-GET.
           MOVE WS-LEN TO LG-LEN
           PERFORM LOG-RESP
           EXEC CICS WRITEQ TS QUEUE('BORAW') FROM(WS-OUT)
                     LENGTH(WS-LEN) END-EXEC.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           EXEC CICS WRITEQ TS QUEUE('BOLOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
