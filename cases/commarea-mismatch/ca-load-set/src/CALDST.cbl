       IDENTIFICATION DIVISION.
       PROGRAM-ID. CALDST.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-load-set                *
      * Original program (Apache-2.0).                                *
      * LOAD PROGRAM SET(ptr) LENGTH(len) of a defined program: the   *
      * pointer (preset to null) and the halfword LENGTH (preset 0)   *
      * are set, then RELEASE PROGRAM. Neither value is logged, only  *
      * whether the pointer is non-null and the length above zero;    *
      * the loaded bytes are never read. Each result is a record in   *
      * TS queue LDLOG.                                               *
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
           EXEC CICS LOAD PROGRAM('CALDTG')
                     SET(WS-PTR) LENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'LD01' TO LG-TAG
           PERFORM LOG-LOAD
           EXEC CICS RELEASE PROGRAM('CALDTG')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'RL01' TO LG-TAG
           MOVE '-' TO LG-PTR
           MOVE '-' TO LG-LEN
           PERFORM LOG-RESP
           EXEC CICS RETURN END-EXEC.
       LOG-LOAD.
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
           PERFORM LOG-RESP.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           EXEC CICS WRITEQ TS QUEUE('LDLOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
