       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCCNSP.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-counter-shared-ns    *
      * Original program (Apache-2.0).                                *
      * HC74, a mode typed after the transid:                         *
      *   B  DCOUNTERs at 2**31, 2**32, 2**33 read by COUNTER commands*
      *   F  a DCOUNTER walked across the fullword boundary           *
      *   D  DEFINE COUNTER / DEFINE DCOUNTER of a name already used  *
      * Every result is a breadcrumb in TS queue HCLOG. Values are    *
      * logged as 16 hex digits (a fullword is right-aligned).        *
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
       01  WS-FW                 PIC X(4)  VALUE LOW-VALUES.
       01  WS-FWV                PIC S9(8) COMP VALUE 9.
       01  WS-POOL               PIC X(8)  VALUE 'HCPOOL'.
       01  WS-C1                 PIC X(16) VALUE 'HCNSP1'.
       01  WS-C2                 PIC X(16) VALUE 'HCNSP2'.
       01  WS-C3                 PIC X(16) VALUE 'HCNSP3'.
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
               WHEN 'B'
                   PERFORM BIG-PARA
               WHEN 'F'
                   PERFORM FIT-PARA
               WHEN 'D'
                   PERFORM DUP-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       BIG-PARA.
      * B1-B7: DCOUNTERs at 2**31, 2**32, 2**33 read by COUNTER
           MOVE LOW-VALUES TO WS-START
           MOVE X'80' TO WS-STBYTE(5)
           PERFORM DEF-C1
           MOVE 'B1 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM QUERY-FW-C1
           MOVE 'B2 ' TO CLOG-TAG
           PERFORM LOG-FW
           MOVE LOW-VALUES TO WS-START
           MOVE X'01' TO WS-STBYTE(4)
           PERFORM DEF-C2
           MOVE 'B3 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM QUERY-FW-C2
           MOVE 'B4 ' TO CLOG-TAG
           PERFORM LOG-FW
           MOVE LOW-VALUES TO WS-START
           MOVE X'02' TO WS-STBYTE(4)
           PERFORM DEF-C3
           MOVE 'B5 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM QUERY-FW-C3
           MOVE 'B6 ' TO CLOG-TAG
           PERFORM LOG-FW
           EXEC CICS GET COUNTER(WS-C2) POOL(WS-POOL) VALUE(WS-FW)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B7 ' TO CLOG-TAG
           PERFORM LOG-FW
           EXEC CICS QUERY DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B8 ' TO CLOG-TAG
           PERFORM LOG-V.
       FIT-PARA.
      * F1-F8: a DCOUNTER at 2**31 - 2 crosses the fullword boundary
           MOVE LOW-VALUES TO WS-START
           MOVE X'7F' TO WS-STBYTE(5)
           MOVE X'FF' TO WS-STBYTE(6)
           MOVE X'FF' TO WS-STBYTE(7)
           MOVE X'FE' TO WS-STBYTE(8)
           PERFORM DEF-C1
           MOVE 'F1 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM QUERY-FW-C1
           MOVE 'F2 ' TO CLOG-TAG
           PERFORM LOG-FW
           EXEC CICS GET COUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-FW)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'F3 ' TO CLOG-TAG
           PERFORM LOG-FW
           PERFORM QUERY-FW-C1
           MOVE 'F4 ' TO CLOG-TAG
           PERFORM LOG-FW
           PERFORM GET-PLAIN
           MOVE 'F5 ' TO CLOG-TAG
           PERFORM LOG-V
           PERFORM QUERY-FW-C1
           MOVE 'F6 ' TO CLOG-TAG
           PERFORM LOG-FW
           EXEC CICS QUERY DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'F7 ' TO CLOG-TAG
           PERFORM LOG-V.
       DUP-PARA.
      * D1-D8: DEFINE of a name that exists under the other command
           MOVE LOW-VALUES TO WS-START
           MOVE X'05' TO WS-STBYTE(8)
           PERFORM DEF-C1
           MOVE 'D1 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS DEFINE COUNTER(WS-C1) POOL(WS-POOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'D2 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS DEFINE COUNTER(WS-C1) POOL(WS-POOL) VALUE(7)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'D3 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS QUERY DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'D4 ' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS DEFINE COUNTER(WS-C2) POOL(WS-POOL)
                     VALUE(WS-FWV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'D5 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE LOW-VALUES TO WS-START
           PERFORM DEF-C2
           MOVE 'D6 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM QUERY-FW-C2
           MOVE 'D7 ' TO CLOG-TAG
           PERFORM LOG-FW
           EXEC CICS QUERY DCOUNTER(WS-C2) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'D8 ' TO CLOG-TAG
           PERFORM LOG-V.
       DEF-C1.
           EXEC CICS DEFINE DCOUNTER(WS-C1) POOL(WS-POOL)
                     VALUE(WS-START)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       DEF-C2.
           EXEC CICS DEFINE DCOUNTER(WS-C2) POOL(WS-POOL)
                     VALUE(WS-START)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       DEF-C3.
           EXEC CICS DEFINE DCOUNTER(WS-C3) POOL(WS-POOL)
                     VALUE(WS-START)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       QUERY-FW-C1.
           EXEC CICS QUERY COUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-FW)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       QUERY-FW-C2.
           EXEC CICS QUERY COUNTER(WS-C2) POOL(WS-POOL) VALUE(WS-FW)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       QUERY-FW-C3.
           EXEC CICS QUERY COUNTER(WS-C3) POOL(WS-POOL) VALUE(WS-FW)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       LOG-FW.
      * a fullword result, right-aligned in the 8-byte area
           MOVE LOW-VALUES TO WS-DV
           MOVE WS-FW TO WS-DV(5:4)
           PERFORM LOG-V.
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
