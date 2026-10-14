       IDENTIFICATION DIVISION.
       PROGRAM-ID. CABOFF.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-container-byteoffset    *
      * Original program (Apache-2.0).                                *
      * Partial reads of a BIT container with GET CONTAINER           *
      * BYTEOFFSET: from the start, the middle, the last byte, with   *
      * FLENGTH above what is left, a negative offset; then a PUT     *
      * with PREPEND and two more reads. The bytes each GET returns   *
      * go to TS queue BORAW, results to BOLOG.                       *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CHAN               PIC X(16) VALUE 'BOCHAN'.
       01  WS-SRC                PIC X(10) VALUE 'ABCDEFGHIJ'.
       01  WS-PRE                PIC X(2)  VALUE 'XY'.
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
      * From the start: the whole container.
           MOVE 0 TO WS-OFF
           MOVE 16 TO WS-LEN
           PERFORM GET-AT
           MOVE 'GET1' TO LG-TAG
           PERFORM LOG-GET
      * From the middle.
           MOVE 3 TO WS-OFF
           MOVE 16 TO WS-LEN
           PERFORM GET-AT
           MOVE 'GET2' TO LG-TAG
           PERFORM LOG-GET
      * The last byte, offset length - 1.
           MOVE 9 TO WS-OFF
           MOVE 16 TO WS-LEN
           PERFORM GET-AT
           MOVE 'GET3' TO LG-TAG
           PERFORM LOG-GET
      * FLENGTH above the 3 bytes left from offset 7.
           MOVE 7 TO WS-OFF
           MOVE 16 TO WS-LEN
           PERFORM GET-AT
           MOVE 'GET4' TO LG-TAG
           PERFORM LOG-GET
      * A negative offset: zero is assumed.
           MOVE -1 TO WS-OFF
           MOVE 16 TO WS-LEN
           PERFORM GET-AT
           MOVE 'GET5' TO LG-TAG
           PERFORM LOG-GET
      * PREPEND to the existing container.
           EXEC CICS PUT CONTAINER('DATA') CHANNEL(WS-CHAN)
                     FROM(WS-PRE) BIT PREPEND
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT2' TO LG-TAG
           PERFORM LOG-RESP
           MOVE 0 TO WS-OFF
           MOVE 16 TO WS-LEN
           PERFORM GET-AT
           MOVE 'GET6' TO LG-TAG
           PERFORM LOG-GET
      * Offset 10 is now inside the container, at the old last bytes.
           MOVE 10 TO WS-OFF
           MOVE 16 TO WS-LEN
           PERFORM GET-AT
           MOVE 'GET7' TO LG-TAG
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
