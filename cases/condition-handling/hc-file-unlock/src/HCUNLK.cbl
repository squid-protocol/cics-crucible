       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCUNLK.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-file-unlock            *
      * Original program (Apache-2.0).                                *
      * HC81, a mode typed after the transid, on file HCUF (records   *
      * of 16 bytes: key 4, name 8, quantity 4):                      *
      *   R  READ UPDATE of K002, REWRITE it, READ it again           *
      *   U  READ UPDATE of K002, UNLOCK, REWRITE (nothing is held),  *
      *      READ it again                                            *
      *   N  UNLOCK with no READ UPDATE, REWRITE with no READ UPDATE, *
      *      READ of K001                                             *
      *   S  READ of K002 with LENGTH 8 (the record is 16: LENGERR),  *
      *      then READ of K002 with LENGTH 16                         *
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
               WHEN 'R'
                   PERFORM REWRITE-PARA
               WHEN 'U'
                   PERFORM UNLOCK-PARA
               WHEN 'N'
                   PERFORM NOTHING-PARA
               WHEN 'S'
                   PERFORM SHORT-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       REWRITE-PARA.
           MOVE 'K002' TO WS-KEY
           EXEC CICS READ FILE('HCUF') INTO(WS-REC) LENGTH(WS-LEN)
                     RIDFLD(WS-KEY) UPDATE
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R1 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE '0099' TO WS-REC(13:4)
           EXEC CICS REWRITE FILE('HCUF') FROM(WS-REC) LENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R2 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'R3 ' TO CLOG-TAG
           PERFORM LOG-D.
       UNLOCK-PARA.
           MOVE 'K002' TO WS-KEY
           EXEC CICS READ FILE('HCUF') INTO(WS-REC) LENGTH(WS-LEN)
                     RIDFLD(WS-KEY) UPDATE
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U1 ' TO CLOG-TAG
           PERFORM LOG-D
           EXEC CICS UNLOCK FILE('HCUF')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U2 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE '0099' TO WS-REC(13:4)
           EXEC CICS REWRITE FILE('HCUF') FROM(WS-REC) LENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U3 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'U4 ' TO CLOG-TAG
           PERFORM LOG-D.
       NOTHING-PARA.
           EXEC CICS UNLOCK FILE('HCUF')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'K001ALPHA   0099' TO WS-REC
           EXEC CICS REWRITE FILE('HCUF') FROM(WS-REC) LENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'N2 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'K001' TO WS-KEY
           PERFORM READ-PARA
           MOVE 'N3 ' TO CLOG-TAG
           PERFORM LOG-D.
       SHORT-PARA.
      * LENGTH 8 is below the 16-byte record: LENGERR. RESP2 and the
      * truncated INTO are not logged (the case does not rely on them).
           MOVE 'K002' TO WS-KEY
           MOVE 8 TO WS-LEN
           EXEC CICS READ FILE('HCUF') INTO(WS-REC) LENGTH(WS-LEN)
                     RIDFLD(WS-KEY)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'S1 ' TO CLOG-TAG
           MOVE SPACES TO CLOG-DATA
           MOVE WS-RESP TO CLOG-RESP
           MOVE 0 TO CLOG-RESP2
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-CLOG)
                     LENGTH(33)
           END-EXEC
           MOVE 16 TO WS-LEN
           MOVE SPACES TO WS-REC
           PERFORM READ-PARA
           MOVE 'S2 ' TO CLOG-TAG
           PERFORM LOG-D.
       READ-PARA.
           EXEC CICS READ FILE('HCUF') INTO(WS-REC) LENGTH(WS-LEN)
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
