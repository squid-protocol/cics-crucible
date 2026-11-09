       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCSYNC.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-syncpoint-rollback     *
      * Original program (Apache-2.0).                                *
      * HC91, a mode typed after the transid, on file HCSF (records   *
      * of 16 bytes: key 4, name 8, quantity 4; not recoverable):     *
      *   R  READ UPDATE of K002, REWRITE it (quantity 0099),         *
      *      SYNCPOINT ROLLBACK, READ it again                        *
      *   C  READ UPDATE of K002, SYNCPOINT (ends the hold), REWRITE  *
      *      (no hold: INVREQ), READ again                            *
      *   L  READ UPDATE of K002, REWRITE (0099), LINK to HCSYNB      *
      *      (which issues SYNCPOINT ROLLBACK), READ it again         *
      * Every result is a breadcrumb in TS queue HCLOG.               *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-LEN                PIC S9(4) COMP VALUE 16.
       01  WS-KEY                PIC X(4)  VALUE 'K002'.
       01  WS-REC                PIC X(16) VALUE SPACES.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  CLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' D='.
           05  CLOG-DATA         PIC X(16) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'R'
                   PERFORM ROLLBACK-PARA
               WHEN 'C'
                   PERFORM COMMIT-PARA
               WHEN 'L'
                   PERFORM LINKED-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       ROLLBACK-PARA.
           PERFORM HOLD-PARA
           MOVE 'R1 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE '0099' TO WS-REC(13:4)
           PERFORM REWRITE-PARA
           MOVE 'R2 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS SYNCPOINT ROLLBACK RESP(WS-RESP)
           END-EXEC
           MOVE 'R3 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'R4 ' TO CLOG-TAG
           PERFORM LOG-D.
       COMMIT-PARA.
           PERFORM HOLD-PARA
           MOVE 'C1 ' TO CLOG-TAG
           PERFORM LOG-D
           EXEC CICS SYNCPOINT RESP(WS-RESP)
           END-EXEC
           MOVE 'C2 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE '0099' TO WS-REC(13:4)
           PERFORM REWRITE-PARA
           MOVE 'C3 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'C4 ' TO CLOG-TAG
           PERFORM LOG-D.
       LINKED-PARA.
           PERFORM HOLD-PARA
           MOVE 'L1 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE '0099' TO WS-REC(13:4)
           PERFORM REWRITE-PARA
           MOVE 'L2 ' TO CLOG-TAG
           PERFORM LOG-R
           EXEC CICS LINK PROGRAM('HCSYNB') RESP(WS-RESP)
           END-EXEC
           MOVE 'L3 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'L4 ' TO CLOG-TAG
           PERFORM LOG-D.
       HOLD-PARA.
           EXEC CICS READ FILE('HCSF') INTO(WS-REC) LENGTH(WS-LEN)
                     RIDFLD(WS-KEY) UPDATE
                     RESP(WS-RESP)
           END-EXEC.
       REWRITE-PARA.
           EXEC CICS REWRITE FILE('HCSF') FROM(WS-REC) LENGTH(WS-LEN)
                     RESP(WS-RESP)
           END-EXEC.
       READ-PARA.
           EXEC CICS READ FILE('HCSF') INTO(WS-REC) LENGTH(WS-LEN)
                     RIDFLD(WS-KEY)
                     RESP(WS-RESP)
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
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-CLOG)
                     LENGTH(27)
           END-EXEC.
