       IDENTIFICATION DIVISION.
       PROGRAM-ID. CALDSX.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-load-set                *
      * Original program (Apache-2.0).                                *
      * LOAD PROGRAM SET LENGTH of a program with no definition       *
      * (PGMIDERR). The pointer and LENGTH are not read after the     *
      * failure. A good LOAD of a defined program follows, to show    *
      * the failure changed nothing. Each result is a record in TS    *
      * queue LDLOG.                                                  *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PTR                POINTER.
       01  WS-LEN                PIC S9(4) COMP.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY LDLOG.
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
           SET WS-PTR TO NULL
           MOVE 0 TO WS-LEN
           EXEC CICS LOAD PROGRAM('CALDXX')
                     SET(WS-PTR) LENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PG01' TO LG-TAG
           MOVE '-' TO LG-PTR
           MOVE '-' TO LG-LEN
           PERFORM LOG-RESP
           EXEC CICS LOAD PROGRAM('CALDTG')
                     SET(WS-PTR) LENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'OK01' TO LG-TAG
           IF WS-PTR = NULL
              MOVE 'N' TO LG-PTR
           ELSE
              MOVE 'Y' TO LG-PTR
           END-IF
           IF WS-LEN > 0
              MOVE 'Y' TO LG-LEN
           ELSE
              MOVE 'N' TO LG-LEN
           END-IF
           PERFORM LOG-RESP
           EXEC CICS RELEASE PROGRAM('CALDTG')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'RL01' TO LG-TAG
           MOVE '-' TO LG-PTR
           MOVE '-' TO LG-LEN
           PERFORM LOG-RESP
           EXEC CICS RETURN END-EXEC.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           EXEC CICS WRITEQ TS QUEUE('LDLOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
