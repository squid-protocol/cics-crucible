       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCRDST.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-file-read-set          *
      * Original program (Apache-2.0).                                *
      * HC83, a mode typed after the transid, on file HCRS (records   *
      * of 16 bytes: key 4, name 8, quantity 4; keys K010 .. K050):   *
      *   R  READ SET of K030, of the absent K035, of K050            *
      *   F  STARTBR GTEQ K015, READNEXT SET until ENDFILE, ENDBR     *
      *   B  STARTBR GTEQ K040, READPREV SET until ENDFILE, ENDBR     *
      *   N  STARTBR of K060 (GTEQ) and of K025 (EQUAL): NOTFND;      *
      *      STARTBR EQUAL K030, READNEXT SET, ENDBR                  *
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
           05  FILLER            PIC X(3)  VALUE ' D='.
           05  CLOG-DATA         PIC X(16) VALUE SPACES.
       LINKAGE SECTION.
       01  LS-REC                PIC X(16).
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
               WHEN 'N'
                   PERFORM NOTFND-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       READ-PARA.
           MOVE 'K030' TO WS-KEY
           EXEC CICS READ FILE('HCRS') SET(ADDRESS OF LS-REC)
                     RIDFLD(WS-KEY)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R1 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'K035' TO WS-KEY
           EXEC CICS READ FILE('HCRS') SET(ADDRESS OF LS-REC)
                     RIDFLD(WS-KEY)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R2 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'K050' TO WS-KEY
           EXEC CICS READ FILE('HCRS') SET(ADDRESS OF LS-REC)
                     RIDFLD(WS-KEY)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R3 ' TO CLOG-TAG
           PERFORM LOG-D.
       FWD-PARA.
           MOVE 'K015' TO WS-KEY
           EXEC CICS STARTBR FILE('HCRS') RIDFLD(WS-KEY) GTEQ
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'F0 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM VARYING WS-N FROM 1 BY 1 UNTIL WS-N > 5
               EXEC CICS READNEXT FILE('HCRS')
                         SET(ADDRESS OF LS-REC) RIDFLD(WS-KEY)
                         RESP(WS-RESP) RESP2(WS-RESP2)
               END-EXEC
               MOVE 'F  ' TO CLOG-TAG
               MOVE WS-N TO CLOG-TAG(2:1)
               PERFORM LOG-D
           END-PERFORM
           EXEC CICS ENDBR FILE('HCRS')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'F6 ' TO CLOG-TAG
           PERFORM LOG-R.
       BACK-PARA.
           MOVE 'K040' TO WS-KEY
           EXEC CICS STARTBR FILE('HCRS') RIDFLD(WS-KEY) GTEQ
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B0 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM VARYING WS-N FROM 1 BY 1 UNTIL WS-N > 5
               EXEC CICS READPREV FILE('HCRS')
                         SET(ADDRESS OF LS-REC) RIDFLD(WS-KEY)
                         RESP(WS-RESP) RESP2(WS-RESP2)
               END-EXEC
               MOVE 'B  ' TO CLOG-TAG
               MOVE WS-N TO CLOG-TAG(2:1)
               PERFORM LOG-D
           END-PERFORM
           EXEC CICS ENDBR FILE('HCRS')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B6 ' TO CLOG-TAG
           PERFORM LOG-R.
       NOTFND-PARA.
           MOVE 'K060' TO WS-KEY
           EXEC CICS STARTBR FILE('HCRS') RIDFLD(WS-KEY) GTEQ
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'K025' TO WS-KEY
           EXEC CICS STARTBR FILE('HCRS') RIDFLD(WS-KEY) EQUAL
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N2 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'K030' TO WS-KEY
           EXEC CICS STARTBR FILE('HCRS') RIDFLD(WS-KEY) EQUAL
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N3 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS READNEXT FILE('HCRS')
                     SET(ADDRESS OF LS-REC) RIDFLD(WS-KEY)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N4 ' TO CLOG-TAG
           PERFORM LOG-D
           EXEC CICS ENDBR FILE('HCRS')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N5 ' TO CLOG-TAG
           PERFORM LOG-R.
       LOG-D.
           MOVE SPACES TO CLOG-DATA
           MOVE SPACES TO CLOG-KEY
           IF WS-RESP = 0
               MOVE LS-REC TO CLOG-DATA
               MOVE WS-KEY TO CLOG-KEY
           END-IF
           PERFORM LOG-W.
       LOG-R.
           MOVE SPACES TO CLOG-DATA
           MOVE SPACES TO CLOG-KEY
           PERFORM LOG-W.
       LOG-W.
           MOVE WS-RESP TO CLOG-RESP
           MOVE 0 TO CLOG-RESP2
           IF WS-RESP NOT = 0
               MOVE WS-RESP2 TO CLOG-RESP2
           END-IF
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-CLOG)
                     LENGTH(40)
           END-EXEC.
