       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCRGTQ.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-file-read-gteq         *
      * Original program (Apache-2.0).                                *
      * HC85, a mode typed after the transid, on file HCRG (records   *
      * of 16 bytes: key 4, name 8, quantity 4; keys A100 A200 A300   *
      * B100 B300). Every read is the INTO form with LENGTH; RIDFLD   *
      * is a field of exactly KEYLENGTH bytes (a short one for a      *
      * generic key); the program never reads it after a READ:        *
      *   G  READ GTEQ of A150, B100, B400, A000                      *
      *   P  READ GENERIC KEYLENGTH 1, 2 or 3, with and without GTEQ  *
      * Every result is a breadcrumb in TS queue HCLOG.               *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-KEY                PIC X(4)  VALUE SPACES.
       01  WS-KEY1              PIC X(1)  VALUE SPACES.
       01  WS-KEY2              PIC X(2)  VALUE SPACES.
       01  WS-KEY3              PIC X(3)  VALUE SPACES.
       01  WS-REC                PIC X(16) VALUE SPACES.
       01  WS-LEN                PIC S9(4) COMP VALUE 16.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  CLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' S='.
           05  CLOG-RESP2        PIC 999   VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' L='.
           05  CLOG-LEN          PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' D='.
           05  CLOG-DATA         PIC X(16) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'G'
                   PERFORM GTEQ-PARA
               WHEN 'P'
                   PERFORM GEN-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       GTEQ-PARA.
           MOVE 'A150' TO WS-KEY
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRG') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY)
                     GTEQ KEYLENGTH(4)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'G1 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'B100' TO WS-KEY
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRG') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY)
                     GTEQ KEYLENGTH(4)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'G2 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'B400' TO WS-KEY
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRG') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY)
                     GTEQ KEYLENGTH(4)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'G3 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'A000' TO WS-KEY
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRG') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY)
                     GTEQ KEYLENGTH(4)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'G4 ' TO CLOG-TAG
           PERFORM LOG-D.
       GEN-PARA.
           MOVE 'A' TO WS-KEY1
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRG') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY1)
                     GENERIC KEYLENGTH(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'P1 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'B' TO WS-KEY1
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRG') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY1)
                     GENERIC KEYLENGTH(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'P2 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'C' TO WS-KEY1
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRG') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY1)
                     GENERIC KEYLENGTH(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'P3 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'A2' TO WS-KEY2
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRG') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY2)
                     GENERIC GTEQ KEYLENGTH(2)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'P4 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'A4' TO WS-KEY2
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRG') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY2)
                     GENERIC KEYLENGTH(2)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'P5 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'A4' TO WS-KEY2
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRG') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY2)
                     GENERIC GTEQ KEYLENGTH(2)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'P6 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'B2' TO WS-KEY2
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRG') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY2)
                     GENERIC GTEQ KEYLENGTH(2)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'P7 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'A20' TO WS-KEY3
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRG') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY3)
                     GENERIC KEYLENGTH(3)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'P8 ' TO CLOG-TAG
           PERFORM LOG-D.
       LOG-D.
           MOVE SPACES TO CLOG-DATA
           MOVE 0 TO CLOG-LEN
           IF WS-RESP = 0
               MOVE WS-REC TO CLOG-DATA
               MOVE WS-LEN TO CLOG-LEN
           END-IF
           MOVE WS-RESP TO CLOG-RESP
           MOVE 0 TO CLOG-RESP2
           IF WS-RESP NOT = 0
               MOVE WS-RESP2 TO CLOG-RESP2
           END-IF
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-CLOG)
                     LENGTH(38)
           END-EXEC.
