       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCTOKN.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-file-token             *
      * Original program (Apache-2.0).                                *
      * HC70, a mode typed after the transid, on file HCTK (records   *
      * of 16 bytes: key 4, name 8, quantity 4):                      *
      *   R  REWRITE TOKEN with a token no READ UPDATE returned, READ *
      *      UPDATE TOKEN of A200, REWRITE TOKEN of it, READ of A200  *
      *   D  DELETE TOKEN with a token no READ UPDATE returned, READ  *
      *      UPDATE TOKEN of B100, DELETE TOKEN of it, READ of B100   *
      * WS-NOTOK is a fullword the program never passes to READ: it   *
      * stays zero. Every result is a breadcrumb in TS queue HCLOG.   *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-LEN                PIC S9(4) COMP VALUE 16.
       01  WS-KEY                PIC X(4)  VALUE SPACES.
       01  WS-REC                PIC X(16) VALUE SPACES.
       01  WS-TOK                PIC S9(8) COMP VALUE 0.
       01  WS-NOTOK              PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  CLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' S='.
           05  CLOG-RESP2        PIC 999   VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' D='.
           05  CLOG-DATA         PIC X(16) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'R'
                   PERFORM REWRITE-PARA
               WHEN 'D'
                   PERFORM DELETE-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       REWRITE-PARA.
           MOVE 'A200BRAVO   0099' TO WS-REC
           EXEC CICS REWRITE FILE('HCTK') FROM(WS-REC)
                     LENGTH(WS-LEN) TOKEN(WS-NOTOK)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'A200' TO WS-KEY
           PERFORM READU-PARA
           MOVE 'R2 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'A200BRAVO   0099' TO WS-REC
           EXEC CICS REWRITE FILE('HCTK') FROM(WS-REC)
                     LENGTH(WS-LEN) TOKEN(WS-TOK)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R3 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'R4 ' TO CLOG-TAG
           PERFORM LOG-D.
       DELETE-PARA.
           EXEC CICS DELETE FILE('HCTK') TOKEN(WS-NOTOK)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'D1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'B100' TO WS-KEY
           PERFORM READU-PARA
           MOVE 'D2 ' TO CLOG-TAG
           PERFORM LOG-D
           EXEC CICS DELETE FILE('HCTK') TOKEN(WS-TOK)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'D3 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'D4 ' TO CLOG-TAG
           PERFORM LOG-D.
       READU-PARA.
           MOVE SPACES TO WS-REC
           EXEC CICS READ FILE('HCTK') INTO(WS-REC) LENGTH(WS-LEN)
                     RIDFLD(WS-KEY) UPDATE TOKEN(WS-TOK)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       READ-PARA.
           MOVE SPACES TO WS-REC
           EXEC CICS READ FILE('HCTK') INTO(WS-REC) LENGTH(WS-LEN)
                     RIDFLD(WS-KEY)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       LOG-D.
           MOVE SPACES TO CLOG-DATA
           IF WS-RESP = 0
               MOVE WS-REC TO CLOG-DATA
           END-IF
           PERFORM LOG-W.
       LOG-R.
           MOVE SPACES TO CLOG-DATA
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
