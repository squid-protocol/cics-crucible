       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCDELF.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-file-delete            *
      * Original program (Apache-2.0).                                *
      * HC98, a mode typed after the transid, on file HCDL (records   *
      * of 16 bytes: key 4, name 8, quantity 4):                      *
      *   K  DELETE RIDFLD of K A200, READ it, DELETE it again,       *
      *      DELETE of an absent key, READ of a neighbour             *
      *   U  DELETE with no RIDFLD and no READ UPDATE yet, then READ  *
      *      UPDATE of A300, DELETE with no RIDFLD, READ of A300      *
      *   G  DELETE GENERIC KEYLENGTH 1 (A), READ, the same DELETE    *
      *      again, DELETE GENERIC KEYLENGTH 2 (B1), READ of B300     *
      * Every result is a breadcrumb in TS queue HCLOG.               *
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
       01  WS-KEY1               PIC X(1)  VALUE SPACES.
       01  WS-KEY2               PIC X(2)  VALUE SPACES.
       01  WS-REC                PIC X(16) VALUE SPACES.
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
               WHEN 'K'
                   PERFORM KEYED-PARA
               WHEN 'U'
                   PERFORM UPDATE-PARA
               WHEN 'G'
                   PERFORM GENERIC-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       KEYED-PARA.
           MOVE 'A200' TO WS-KEY
           PERFORM DELETE-PARA
           MOVE 'K1 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'K2 ' TO CLOG-TAG
           PERFORM LOG-D
           PERFORM DELETE-PARA
           MOVE 'K3 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'Z999' TO WS-KEY
           PERFORM DELETE-PARA
           MOVE 'K4 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'A100' TO WS-KEY
           PERFORM READ-PARA
           MOVE 'K5 ' TO CLOG-TAG
           PERFORM LOG-D.
       UPDATE-PARA.
      * No READ UPDATE has been issued yet: DELETE with no RIDFLD is
      * INVREQ RESP2 31. Then READ UPDATE of A300 and DELETE it.
           EXEC CICS DELETE FILE('HCDL')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'A300' TO WS-KEY
           EXEC CICS READ FILE('HCDL') INTO(WS-REC) LENGTH(WS-LEN)
                     RIDFLD(WS-KEY) UPDATE
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U2 ' TO CLOG-TAG
           PERFORM LOG-D
           EXEC CICS DELETE FILE('HCDL')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U3 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'U4 ' TO CLOG-TAG
           PERFORM LOG-D.
       GENERIC-PARA.
           MOVE 'A' TO WS-KEY1
           PERFORM GDEL1-PARA
           MOVE 'G1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'A100' TO WS-KEY
           PERFORM READ-PARA
           MOVE 'G2 ' TO CLOG-TAG
           PERFORM LOG-D
           PERFORM GDEL1-PARA
           MOVE 'G3 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'B1' TO WS-KEY2
           EXEC CICS DELETE FILE('HCDL') RIDFLD(WS-KEY2)
                     GENERIC KEYLENGTH(2)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'G4 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'B300' TO WS-KEY
           PERFORM READ-PARA
           MOVE 'G5 ' TO CLOG-TAG
           PERFORM LOG-D.
       GDEL1-PARA.
           EXEC CICS DELETE FILE('HCDL') RIDFLD(WS-KEY1)
                     GENERIC KEYLENGTH(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       DELETE-PARA.
           EXEC CICS DELETE FILE('HCDL') RIDFLD(WS-KEY)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       READ-PARA.
           MOVE SPACES TO WS-REC
           EXEC CICS READ FILE('HCDL') INTO(WS-REC) LENGTH(WS-LEN)
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
