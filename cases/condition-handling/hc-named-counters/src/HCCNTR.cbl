       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCCNTR.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-named-counters         *
      * Original program (Apache-2.0).                                *
      * HC71, a mode typed after the transid:                         *
      *   L  the life of named counters: GET / DELETE of a counter    *
      *      that is not there, DEFINE (with and without VALUE), a    *
      *      second DEFINE, GET, QUERY, DELETE, and the same name in  *
      *      another pool                                             *
      *   N  names outside IBM's rules (DEFINE / GET / DELETE) and a  *
      *      counter whose name and pool use every allowed character  *
      * Every result is a breadcrumb in TS queue HCLOG (the named     *
      * counter commands are not events).                             *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-VAL                PIC S9(8) COMP VALUE 0.
       01  WS-START              PIC S9(8) COMP VALUE 5.
       01  WS-POOL               PIC X(8)  VALUE 'HCPOOL'.
       01  WS-C1                 PIC X(16) VALUE 'HCCNT1'.
       01  WS-C2                 PIC X(16) VALUE 'HCCNT2'.
       01  WS-LOWER              PIC X(16) VALUE 'hccnt1'.
       01  WS-DIGIT              PIC X(16) VALUE '1HCCNT'.
       01  WS-SPACED             PIC X(16) VALUE 'HC CNT'.
       01  WS-ALLCH              PIC X(16) VALUE 'A_1$#@'.
       01  WS-POOLCH             PIC X(8)  VALUE 'P_1$#@'.
       01  WS-BADPOOL            PIC X(8)  VALUE 'HC-POOL'.
       01  WS-SPCPOOL            PIC X(8)  VALUE 'HC POOL'.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  CLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' S='.
           05  CLOG-RESP2        PIC 999   VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' V='.
           05  CLOG-VAL          PIC 9(9)  VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'L'
                   PERFORM LIFE-PARA
               WHEN 'N'
                   PERFORM NAMES-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       LIFE-PARA.
           EXEC CICS GET COUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L1 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS DELETE COUNTER(WS-C1) POOL(WS-POOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L2 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS DEFINE COUNTER(WS-C1) POOL(WS-POOL)
                     VALUE(WS-START)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L3 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS DEFINE COUNTER(WS-C1) POOL(WS-POOL) VALUE(7)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L4 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS GET COUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L5 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS GET COUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L6 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS QUERY COUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L7 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS GET COUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L8 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS DEFINE COUNTER(WS-C2) POOL(WS-POOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L9 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS GET COUNTER(WS-C2) POOL(WS-POOL) VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L10' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS DELETE COUNTER(WS-C1) POOL(WS-POOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L11' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS GET COUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L12' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS DEFINE COUNTER(WS-C1) VALUE(9)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L13' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS GET COUNTER(WS-C1) VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L14' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS GET COUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L15' TO CLOG-TAG
           PERFORM LOG-V.
       NAMES-PARA.
           EXEC CICS DEFINE COUNTER(WS-LOWER) POOL(WS-POOL) VALUE(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N1 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS DEFINE COUNTER(WS-DIGIT) POOL(WS-POOL) VALUE(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N2 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS DEFINE COUNTER(WS-SPACED) POOL(WS-POOL) VALUE(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N3 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS DEFINE COUNTER(WS-C1) POOL(WS-BADPOOL) VALUE(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N4 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS GET COUNTER(WS-C1) POOL(WS-SPCPOOL) VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N5 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS DEFINE COUNTER(WS-ALLCH) POOL(WS-POOLCH) VALUE(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N6 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS GET COUNTER(WS-ALLCH) POOL(WS-POOLCH)
                     VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N7 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS DELETE COUNTER(WS-ALLCH) POOL(WS-BADPOOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N8 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS DELETE COUNTER(WS-ALLCH) POOL(WS-POOLCH)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N9 ' TO CLOG-TAG
           PERFORM LOG-R.
       LOG-V.
           MOVE 0 TO CLOG-VAL
           IF WS-RESP = 0
               MOVE WS-VAL TO CLOG-VAL
           END-IF
           PERFORM LOG-W.
       LOG-R.
           MOVE 0 TO CLOG-VAL
           PERFORM LOG-W.
       LOG-W.
           MOVE WS-RESP TO CLOG-RESP
           MOVE 0 TO CLOG-RESP2
           IF WS-RESP NOT = 0
               MOVE WS-RESP2 TO CLOG-RESP2
           END-IF
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-CLOG)
                     LENGTH(26)
           END-EXEC.
