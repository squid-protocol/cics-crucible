       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCWQTS.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-writeq-ts-forms        *
      * Original program (Apache-2.0).                                *
      * HC97 issues seven WRITEQ TS commands, each with RESP, and     *
      * after each one logs the ITEM and NUMITEMS areas and the RESP  *
      * to TS queue HCLOG (the areas are not events). Log item:       *
      *   tag (2), ' I=', item (2), ' N=', numitems (2), ' R=', resp  *
      *   1 new queue HCQA, NOSUSPEND, ITEM                           *
      *   2 same queue, NOSUSPEND, ITEM and NUMITEMS                  *
      *   3 new queue HCQB, AUXILIARY, ITEM and NUMITEMS              *
      *   4 new queue HCQC, MAIN, ITEM                                *
      *   5 REWRITE ITEM(2) of HCQA, NOSUSPEND                        *
      *   6 REWRITE ITEM(7) of HCQA: past the last item (ITEMERR)     *
      *   7 REWRITE ITEM(1) of HCNOQ: no such queue (QIDERR)          *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A                  PIC X(5)  VALUE 'AAAAA'.
       01  WS-B                  PIC X(5)  VALUE 'BBBBB'.
       01  WS-C                  PIC X(5)  VALUE 'CCCCC'.
       01  WS-R                  PIC X(5)  VALUE 'RRRRR'.
       01  WS-ITEM               PIC S9(4) COMP VALUE 0.
       01  WS-NUM                PIC S9(4) COMP VALUE 0.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-LOG.
           05  LOG-TAG           PIC XX    VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' I='.
           05  LOG-ITEM          PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' N='.
           05  LOG-NUM           PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  LOG-RESP          PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE 0 TO WS-ITEM
           MOVE 0 TO WS-NUM
           EXEC CICS WRITEQ TS QUEUE('HCQA') FROM(WS-A) LENGTH(5)
                     NOSUSPEND ITEM(WS-ITEM) RESP(WS-RESP)
           END-EXEC
           MOVE 'W1' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE 0 TO WS-ITEM
           MOVE 0 TO WS-NUM
           EXEC CICS WRITEQ TS QUEUE('HCQA') FROM(WS-B) LENGTH(5)
                     NOSUSPEND ITEM(WS-ITEM) NUMITEMS(WS-NUM)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'W2' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE 0 TO WS-ITEM
           MOVE 0 TO WS-NUM
           EXEC CICS WRITEQ TS QUEUE('HCQB') FROM(WS-C) LENGTH(5)
                     AUXILIARY ITEM(WS-ITEM) NUMITEMS(WS-NUM)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'W3' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE 0 TO WS-ITEM
           MOVE 0 TO WS-NUM
           EXEC CICS WRITEQ TS QUEUE('HCQC') FROM(WS-C) LENGTH(5)
                     MAIN ITEM(WS-ITEM) RESP(WS-RESP)
           END-EXEC
           MOVE 'W4' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE 2 TO WS-ITEM
           MOVE 0 TO WS-NUM
           EXEC CICS WRITEQ TS QUEUE('HCQA') FROM(WS-R) LENGTH(5)
                     REWRITE ITEM(WS-ITEM) NOSUSPEND RESP(WS-RESP)
           END-EXEC
           MOVE 'W5' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE 7 TO WS-ITEM
           MOVE 0 TO WS-NUM
           EXEC CICS WRITEQ TS QUEUE('HCQA') FROM(WS-R) LENGTH(5)
                     REWRITE ITEM(WS-ITEM) NOSUSPEND RESP(WS-RESP)
           END-EXEC
           MOVE 'W6' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE 1 TO WS-ITEM
           MOVE 0 TO WS-NUM
           EXEC CICS WRITEQ TS QUEUE('HCNOQ') FROM(WS-R) LENGTH(5)
                     REWRITE ITEM(WS-ITEM) RESP(WS-RESP)
           END-EXEC
           MOVE 'W7' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       LOG-PARA.
           MOVE WS-ITEM TO LOG-ITEM
           MOVE WS-NUM TO LOG-NUM
           MOVE WS-RESP TO LOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG)
                     LENGTH(17)
           END-EXEC.
