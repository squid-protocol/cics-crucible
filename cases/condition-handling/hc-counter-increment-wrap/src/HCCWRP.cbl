       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCCWRP.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-counter-increment-wrap *
      * Original program (Apache-2.0).                                *
      * HC73, a mode typed after the transid:                         *
      *   I  GET DCOUNTER with INCREMENT(5), twice, then QUERY        *
      *   W  a counter walked up to its default maximum (8 bytes of   *
      *      X'FF'); GET WRAP at the limit rewinds it to the minimum  *
      *   L  the same walk, but GET without WRAP at the limit         *
      * Every result is a breadcrumb in TS queue HCLOG. The 8-byte    *
      * unsigned value is a PIC X(8) area, logged as 16 hex digits.   *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-DV                 PIC X(8)  VALUE LOW-VALUES.
       01  WS-DVB REDEFINES WS-DV.
           05  WS-DVBYTE         PIC X OCCURS 8 TIMES.
       01  WS-START              PIC X(8)  VALUE LOW-VALUES.
       01  WS-STARTB REDEFINES WS-START.
           05  WS-STBYTE         PIC X OCCURS 8 TIMES.
       01  WS-INC                PIC 9(18) COMP VALUE 0.
       01  WS-POOL               PIC X(8)  VALUE 'HCPOOL'.
       01  WS-C1                 PIC X(16) VALUE 'HCWRP1'.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-HEXDIG             PIC X(16) VALUE '0123456789ABCDEF'.
       01  WS-BW.
           05  FILLER            PIC X     VALUE LOW-VALUE.
           05  WS-BWB            PIC X     VALUE LOW-VALUE.
       01  WS-BN REDEFINES WS-BW PIC 9(4) COMP.
       01  WS-HI                 PIC 9(4)  COMP VALUE 0.
       01  WS-LO                 PIC 9(4)  COMP VALUE 0.
       01  WS-I                  PIC 9(4)  COMP VALUE 0.
       01  WS-P                  PIC 9(4)  COMP VALUE 0.
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  CLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' S='.
           05  CLOG-RESP2        PIC 999   VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' V='.
           05  CLOG-VAL          PIC X(16) VALUE ALL '0'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'I'
                   PERFORM INCR-PARA
               WHEN 'W'
                   PERFORM WRAP-PARA
               WHEN 'L'
                   PERFORM LIMIT-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       INCR-PARA.
      * I1-I5: start at 10, step by INCREMENT(5)
           MOVE LOW-VALUES TO WS-START
           MOVE X'0A' TO WS-STBYTE(8)
           PERFORM DEF-C1
           MOVE 'I1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 5 TO WS-INC
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     INCREMENT(WS-INC)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'I2 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     INCREMENT(WS-INC)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'I3 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS QUERY DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'I4 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'I5 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS QUERY DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'I6 ' TO CLOG-TAG
           PERFORM LOG-V.
       WRAP-PARA.
      * W1-W7: start at max - 2, three GETs take the counter to the
      * maximum, the fourth GET carries WRAP
           MOVE HIGH-VALUES TO WS-START
           MOVE X'FD' TO WS-STBYTE(8)
           PERFORM DEF-C1
           MOVE 'W1 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM GET-PLAIN
           MOVE 'W2 ' TO CLOG-TAG
           PERFORM LOG-V
           PERFORM GET-PLAIN
           MOVE 'W3 ' TO CLOG-TAG
           PERFORM LOG-V
           PERFORM GET-PLAIN
           MOVE 'W4 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     WRAP
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'W5 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS QUERY DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'W6 ' TO CLOG-TAG
           PERFORM LOG-V
           PERFORM GET-PLAIN
           MOVE 'W7 ' TO CLOG-TAG
           PERFORM LOG-V.
       LIMIT-PARA.
      * L1-L8: start at max - 1, two GETs take the counter to the
      * maximum, then GETs without WRAP, then one with WRAP
           MOVE HIGH-VALUES TO WS-START
           MOVE X'FE' TO WS-STBYTE(8)
           PERFORM DEF-C1
           MOVE 'L1 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM GET-PLAIN
           MOVE 'L2 ' TO CLOG-TAG
           PERFORM LOG-V
           PERFORM GET-PLAIN
           MOVE 'L3 ' TO CLOG-TAG
           PERFORM LOG-V
           PERFORM GET-PLAIN
           MOVE 'L4 ' TO CLOG-TAG
           PERFORM LOG-V
           PERFORM GET-PLAIN
           MOVE 'L5 ' TO CLOG-TAG
           PERFORM LOG-V
           MOVE 5 TO WS-INC
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     INCREMENT(WS-INC)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L6 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     WRAP
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L7 ' TO CLOG-TAG
           PERFORM LOG-V
           PERFORM GET-PLAIN
           MOVE 'L8 ' TO CLOG-TAG
           PERFORM LOG-V.
       DEF-C1.
           EXEC CICS DEFINE DCOUNTER(WS-C1) POOL(WS-POOL)
                     VALUE(WS-START)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       GET-PLAIN.
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       LOG-V.
           MOVE ALL '0' TO CLOG-VAL
           IF WS-RESP = 0
               PERFORM HEX-VAL
           END-IF
           PERFORM LOG-W.
       LOG-R.
           MOVE ALL '0' TO CLOG-VAL
           PERFORM LOG-W.
       LOG-W.
           MOVE WS-RESP TO CLOG-RESP
           MOVE 0 TO CLOG-RESP2
           IF WS-RESP NOT = 0
               MOVE WS-RESP2 TO CLOG-RESP2
           END-IF
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-CLOG)
                     LENGTH(33)
           END-EXEC.
       HEX-VAL.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 8
               MOVE WS-DVBYTE(WS-I) TO WS-BWB
               DIVIDE WS-BN BY 16 GIVING WS-HI REMAINDER WS-LO
               COMPUTE WS-P = WS-I * 2 - 1
               MOVE WS-HEXDIG(WS-HI + 1:1) TO CLOG-VAL(WS-P:1)
               MOVE WS-HEXDIG(WS-LO + 1:1) TO CLOG-VAL(WS-P + 1:1)
           END-PERFORM.
