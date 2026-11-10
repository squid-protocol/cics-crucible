       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCCRWU.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-counter-rewind-update  *
      * Original program (Apache-2.0).                                *
      * HC75, a mode typed after the transid:                         *
      *   R  REWIND DCOUNTER: of a counter that is not there, of one  *
      *      that has not reached its limit, of one that has (limits  *
      *      1 and 3), and with a bad pool and a bad name             *
      *   U  UPDATE DCOUNTER VALUE: within the limits (10 and 20),    *
      *      below the minimum, above the maximum plus 1, at the      *
      *      maximum plus 1 and at the minimum                        *
      *   C  the fullword forms, REWIND COUNTER and UPDATE COUNTER,   *
      *      with the default limits                                  *
      * Every result is a breadcrumb in TS queue HCLOG. The 8-byte    *
      * unsigned value is a PIC X(8) area, logged as 16 hex digits;   *
      * a fullword value is logged as 16 decimal digits.              *
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
       01  WS-MIN                PIC X(8)  VALUE LOW-VALUES.
       01  WS-MINB REDEFINES WS-MIN.
           05  WS-MINBYTE        PIC X OCCURS 8 TIMES.
       01  WS-MAX                PIC X(8)  VALUE LOW-VALUES.
       01  WS-MAXB REDEFINES WS-MAX.
           05  WS-MAXBYTE        PIC X OCCURS 8 TIMES.
       01  WS-NEW                PIC X(8)  VALUE LOW-VALUES.
       01  WS-NEWB REDEFINES WS-NEW.
           05  WS-NEWBYTE        PIC X OCCURS 8 TIMES.
       01  WS-VAL                PIC S9(8) COMP VALUE 0.
       01  WS-POOL               PIC X(8)  VALUE 'HCPOOL'.
       01  WS-BADPOOL            PIC X(8)  VALUE 'HC-POOL'.
       01  WS-C1                 PIC X(16) VALUE 'HCRWU1'.
       01  WS-LOWER              PIC X(16) VALUE 'hcrwu1'.
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
           05  CLOG-DEC REDEFINES CLOG-VAL PIC 9(16).
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'R'
                   PERFORM REWIND-PARA
               WHEN 'U'
                   PERFORM UPDATE-PARA
               WHEN 'C'
                   PERFORM FULLWORD-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       REWIND-PARA.
      * R1-R11: limits 1 and 3
           PERFORM REWIND-D
           MOVE 'R1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE X'01' TO WS-STBYTE(8)
           MOVE X'01' TO WS-MINBYTE(8)
           MOVE X'03' TO WS-MAXBYTE(8)
           PERFORM DEF-D
           MOVE 'R2 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM REWIND-D
           MOVE 'R3 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM GET-D
           MOVE 'R4 ' TO CLOG-TAG
           PERFORM LOG-V
           PERFORM GET-D
           MOVE 'R5 ' TO CLOG-TAG
           PERFORM LOG-V
           PERFORM GET-D
           MOVE 'R6 ' TO CLOG-TAG
           PERFORM LOG-V
           PERFORM REWIND-D
           MOVE 'R7 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM GET-D
           MOVE 'R8 ' TO CLOG-TAG
           PERFORM LOG-V
           PERFORM REWIND-D
           MOVE 'R9 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS REWIND DCOUNTER(WS-C1) POOL(WS-BADPOOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R10' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS REWIND DCOUNTER(WS-LOWER) POOL(WS-POOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R11' TO CLOG-TAG
           PERFORM LOG-R.
       UPDATE-PARA.
      * U1-U12: limits 10 and 20
           MOVE X'0F' TO WS-NEWBYTE(8)
           PERFORM UPDATE-D
           MOVE 'U1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE X'0A' TO WS-STBYTE(8)
           MOVE X'0A' TO WS-MINBYTE(8)
           MOVE X'14' TO WS-MAXBYTE(8)
           PERFORM DEF-D
           MOVE 'U2 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM UPDATE-D
           MOVE 'U3 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM QUERY-D
           MOVE 'U4 ' TO CLOG-TAG
           PERFORM LOG-V
           PERFORM GET-D
           MOVE 'U5 ' TO CLOG-TAG
           PERFORM LOG-V
           MOVE X'09' TO WS-NEWBYTE(8)
           PERFORM UPDATE-D
           MOVE 'U6 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE X'16' TO WS-NEWBYTE(8)
           PERFORM UPDATE-D
           MOVE 'U7 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE X'15' TO WS-NEWBYTE(8)
           PERFORM UPDATE-D
           MOVE 'U8 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE X'0A' TO WS-NEWBYTE(8)
           PERFORM UPDATE-D
           MOVE 'U9 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM GET-D
           MOVE 'U10' TO CLOG-TAG
           PERFORM LOG-V
           EXEC CICS UPDATE DCOUNTER(WS-C1) POOL(WS-BADPOOL)
                     VALUE(WS-NEW)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U11' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS UPDATE DCOUNTER(WS-LOWER) POOL(WS-POOL)
                     VALUE(WS-NEW)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U12' TO CLOG-TAG
           PERFORM LOG-R.
       FULLWORD-PARA.
      * C1-C11: fullword counter, default limits
           EXEC CICS REWIND COUNTER(WS-C1) POOL(WS-POOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'C1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 5 TO WS-VAL
           EXEC CICS UPDATE COUNTER(WS-C1) POOL(WS-POOL)
                     VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'C2 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS DEFINE COUNTER(WS-C1) POOL(WS-POOL) VALUE(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'C3 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS REWIND COUNTER(WS-C1) POOL(WS-POOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'C4 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS UPDATE COUNTER(WS-C1) POOL(WS-POOL)
                     VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'C5 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS QUERY COUNTER(WS-C1) POOL(WS-POOL)
                     VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'C6 ' TO CLOG-TAG
           PERFORM LOG-F
           EXEC CICS GET COUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'C7 ' TO CLOG-TAG
           PERFORM LOG-F
           EXEC CICS QUERY COUNTER(WS-C1) POOL(WS-POOL)
                     VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'C8 ' TO CLOG-TAG
           PERFORM LOG-F
           EXEC CICS REWIND COUNTER(WS-C1) POOL(WS-POOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'C9 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS UPDATE COUNTER(WS-C1) POOL(WS-BADPOOL)
                     VALUE(WS-VAL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'C10' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS REWIND COUNTER(WS-LOWER) POOL(WS-POOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'C11' TO CLOG-TAG
           PERFORM LOG-R.
       DEF-D.
           EXEC CICS DEFINE DCOUNTER(WS-C1) POOL(WS-POOL)
                     VALUE(WS-START) MINIMUM(WS-MIN) MAXIMUM(WS-MAX)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       REWIND-D.
           EXEC CICS REWIND DCOUNTER(WS-C1) POOL(WS-POOL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       UPDATE-D.
           EXEC CICS UPDATE DCOUNTER(WS-C1) POOL(WS-POOL)
                     VALUE(WS-NEW)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       GET-D.
           EXEC CICS GET DCOUNTER(WS-C1) POOL(WS-POOL) VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       QUERY-D.
           EXEC CICS QUERY DCOUNTER(WS-C1) POOL(WS-POOL)
                     VALUE(WS-DV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       LOG-V.
           MOVE ALL '0' TO CLOG-VAL
           IF WS-RESP = 0
               PERFORM HEX-VAL
           END-IF
           PERFORM LOG-W.
       LOG-F.
           MOVE ALL '0' TO CLOG-VAL
           IF WS-RESP = 0
               MOVE WS-VAL TO CLOG-DEC
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
