       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCRDIN.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-file-into-browse       *
      * Original program (Apache-2.0).                                *
      * HC84, a mode typed after the transid, on file HCRI (records   *
      * of 16 bytes: key 4, name 8, quantity 4; keys K110 .. K150).   *
      * Every read is the INTO form with DATASET, LENGTH and a        *
      * KEYLENGTH of the full key (4); a browse's LENGTH is the       *
      * literal 16, a READ's is a data area (logged as L=):           *
      *   R  READ of K130, of the absent K135, of K150                *
      *   F  STARTBR GTEQ K115, READNEXT INTO until ENDFILE, ENDBR    *
      *   B  STARTBR GTEQ K140, READPREV INTO until ENDFILE, ENDBR    *
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
       01  WS-REC                PIC X(16) VALUE SPACES.
       01  WS-LEN                PIC S9(4) COMP VALUE 16.
       01  WS-N                  PIC 9     VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  CLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' S='.
           05  CLOG-RESP2        PIC 999   VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' K='.
           05  CLOG-KEY          PIC X(4)  VALUE SPACES.
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
               WHEN 'R'
                   PERFORM READ-PARA
               WHEN 'F'
                   PERFORM FWD-PARA
               WHEN 'B'
                   PERFORM BACK-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       READ-PARA.
           MOVE 'K130' TO WS-KEY
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRI') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY) KEYLENGTH(4)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R1 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'K135' TO WS-KEY
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRI') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY) KEYLENGTH(4)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R2 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'K150' TO WS-KEY
           MOVE 16 TO WS-LEN
           EXEC CICS READ DATASET('HCRI') INTO(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY) KEYLENGTH(4)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R3 ' TO CLOG-TAG
           PERFORM LOG-D.
       FWD-PARA.
           MOVE 'K115' TO WS-KEY
           EXEC CICS STARTBR DATASET('HCRI') RIDFLD(WS-KEY)
                     KEYLENGTH(4) GTEQ
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'F0 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM VARYING WS-N FROM 1 BY 1 UNTIL WS-N > 5
               EXEC CICS READNEXT DATASET('HCRI') INTO(WS-REC)
                         LENGTH(16) RIDFLD(WS-KEY) KEYLENGTH(4)
                         RESP(WS-RESP) RESP2(WS-RESP2)
               END-EXEC
               MOVE 'F  ' TO CLOG-TAG
               MOVE WS-N TO CLOG-TAG(2:1)
               PERFORM LOG-D
           END-PERFORM
           EXEC CICS ENDBR DATASET('HCRI')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'F6 ' TO CLOG-TAG
           PERFORM LOG-R.
       BACK-PARA.
           MOVE 'K140' TO WS-KEY
           EXEC CICS STARTBR DATASET('HCRI') RIDFLD(WS-KEY)
                     KEYLENGTH(4) GTEQ
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B0 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM VARYING WS-N FROM 1 BY 1 UNTIL WS-N > 5
               EXEC CICS READPREV DATASET('HCRI') INTO(WS-REC)
                         LENGTH(16) RIDFLD(WS-KEY) KEYLENGTH(4)
                         RESP(WS-RESP) RESP2(WS-RESP2)
               END-EXEC
               MOVE 'B  ' TO CLOG-TAG
               MOVE WS-N TO CLOG-TAG(2:1)
               PERFORM LOG-D
           END-PERFORM
           EXEC CICS ENDBR DATASET('HCRI')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B6 ' TO CLOG-TAG
           PERFORM LOG-R.
       LOG-D.
           MOVE SPACES TO CLOG-DATA
           MOVE SPACES TO CLOG-KEY
           MOVE 0 TO CLOG-LEN
           IF WS-RESP = 0
               MOVE WS-REC TO CLOG-DATA
               MOVE WS-KEY TO CLOG-KEY
               IF WS-MODE = 'R'
                   MOVE WS-LEN TO CLOG-LEN
               END-IF
           END-IF
           PERFORM LOG-W.
       LOG-R.
           MOVE SPACES TO CLOG-DATA
           MOVE SPACES TO CLOG-KEY
           MOVE 0 TO CLOG-LEN
           PERFORM LOG-W.
       LOG-W.
           MOVE WS-RESP TO CLOG-RESP
           MOVE 0 TO CLOG-RESP2
           IF WS-RESP NOT = 0
               MOVE WS-RESP2 TO CLOG-RESP2
           END-IF
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-CLOG)
                     LENGTH(45)
           END-EXEC.
