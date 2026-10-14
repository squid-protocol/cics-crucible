       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCDCNT.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-dcounters              *
      * Original program (Apache-2.0).                                *
      * HC72, a mode typed after the transid:                         *
      *   L  the life of a doubleword named counter: GET / DELETE of  *
      *      a counter that is not there, DEFINE DCOUNTER, GET,       *
      *      QUERY, DELETE, GET and QUERY of the deleted counter      *
      *   B  values past 2**31 and 2**32 kept exactly: DEFINE at the  *
      *      edge, GET across it, QUERY, and GET with a doubleword    *
      *      INCREMENT of 2**32                                       *
      * Every result is a breadcrumb in TS queue HCLOG (the named     *
      * counter commands are not events). The 8-byte unsigned value   *
      * is logged as 16 hexadecimal digits.                           *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-DV                 PIC 9(18) COMP VALUE 0.
       01  WS-DVB REDEFINES WS-DV.
           05  WS-DVBYTE         PIC X OCCURS 8 TIMES.
       01  WS-START              PIC 9(18) COMP VALUE 0.
       01  WS-INC                PIC 9(18) COMP VALUE 0.
       01  WS-POOL               PIC X(8)  VALUE 'HCPOOL'.
       01  WS-C1                 PIC X(16) VALUE 'HCDCN1'.
       01  WS-C2                 PIC X(16) VALUE 'HCDCN2'.
       01  WS-C3                 PIC X(16) VALUE 'HCDCN3'.
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
               WHEN 'L'
                   PERFORM LIFE-PARA
               WHEN 'B'
                   PERFORM BIG-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       LIFE-PARA.
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L1 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS DELETE DCOUNTER(WS-C1) POOL(WS-POOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L2 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 5 TO WS-START
           EXEC CICS DEFINE DCOUNTER(WS-C1) POOL(WS-POOL)
                     VALUE(WS-START)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L3 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L4 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L5 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS QUERY DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L6 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L7 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS QUERY DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L8 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS DELETE DCOUNTER(WS-C1) POOL(WS-POOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L9 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L10' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS QUERY DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'L11' TO CLOG-TAG
           PERFORM LOG-V.
       BIG-PARA.
      * B1-B6: the counter starts at 2**31 - 1 (X'7FFFFFFF')
           MOVE 2147483647 TO WS-START
           EXEC CICS DEFINE DCOUNTER(WS-C1) POOL(WS-POOL)
                     VALUE(WS-START)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B1 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B2 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B3 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS QUERY DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B4 ' TO CLOG-TAG
           PERFORM LOG-V
      * B5-B9: the counter starts at 2**32 - 1 (X'FFFFFFFF')
           MOVE 4294967295 TO WS-START
           EXEC CICS DEFINE DCOUNTER(WS-C2) POOL(WS-POOL)
                     VALUE(WS-START)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B5 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS GET DCOUNTER(WS-C2) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B6 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS GET DCOUNTER(WS-C2) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B7 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS QUERY DCOUNTER(WS-C2) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B8 ' TO CLOG-TAG
           PERFORM LOG-V
      * B9-B13: a counter at 5 stepped by a doubleword INCREMENT 2**32
           MOVE 5 TO WS-START
           EXEC CICS DEFINE DCOUNTER(WS-C3) POOL(WS-POOL)
                     VALUE(WS-START)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B9 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 4294967296 TO WS-INC
           EXEC CICS GET DCOUNTER(WS-C3) POOL(WS-POOL) VALUE(WS-DV)
                     INCREMENT(WS-INC)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B10' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS GET DCOUNTER(WS-C3) POOL(WS-POOL) VALUE(WS-DV)
                     INCREMENT(WS-INC)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B11' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS QUERY DCOUNTER(WS-C3) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B12' TO CLOG-TAG
           PERFORM LOG-V.
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
