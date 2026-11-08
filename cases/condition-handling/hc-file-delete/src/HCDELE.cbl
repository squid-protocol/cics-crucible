       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCDELE.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-file-delete            *
      * Original program (Apache-2.0).                                *
      * HC93, a mode typed after the transid, on file HCDF (records   *
      * of 16 bytes: key 4, name 8, quantity 4):                      *
      *   K  DELETE by key (K002), READ K002, READ K003               *
      *   U  READ UPDATE K002, DELETE with no RIDFLD, READ K002       *
      *   M  DELETE of a key not in the file (K005), READ K003        *
      *   I  DELETE with no RIDFLD and no READ UPDATE, READ K001      *
      *   R  DELETE K002, WRITE a new K002, READ K002                 *
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
           05  FILLER            PIC X(3)  VALUE ' 2='.
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
                   PERFORM KEY-PARA
               WHEN 'U'
                   PERFORM HELD-PARA
               WHEN 'M'
                   PERFORM MISSING-PARA
               WHEN 'I'
                   PERFORM NOHOLD-PARA
               WHEN 'R'
                   PERFORM READD-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       KEY-PARA.
           MOVE 'K002' TO WS-KEY
           PERFORM DELKEY-PARA
           MOVE 'K1 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'K2 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'K003' TO WS-KEY
           PERFORM READ-PARA
           MOVE 'K3 ' TO CLOG-TAG
           PERFORM LOG-D.
       HELD-PARA.
           MOVE 'K002' TO WS-KEY
           EXEC CICS READ FILE('HCDF') INTO(WS-REC) LENGTH(WS-LEN)
                     RIDFLD(WS-KEY) UPDATE
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U1 ' TO CLOG-TAG
           PERFORM LOG-D
           EXEC CICS DELETE FILE('HCDF')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U2 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'U3 ' TO CLOG-TAG
           PERFORM LOG-D.
       MISSING-PARA.
           MOVE 'K005' TO WS-KEY
           PERFORM DELKEY-PARA
           MOVE 'M1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'K003' TO WS-KEY
           PERFORM READ-PARA
           MOVE 'M2 ' TO CLOG-TAG
           PERFORM LOG-D.
       NOHOLD-PARA.
           EXEC CICS DELETE FILE('HCDF')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'I1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'K001' TO WS-KEY
           PERFORM READ-PARA
           MOVE 'I2 ' TO CLOG-TAG
           PERFORM LOG-D.
       READD-PARA.
           MOVE 'K002' TO WS-KEY
           PERFORM DELKEY-PARA
           MOVE 'R1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'K002NEWNAME 0099' TO WS-REC
           EXEC CICS WRITE FILE('HCDF') FROM(WS-REC) LENGTH(WS-LEN)
                     RIDFLD(WS-KEY)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R2 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'R3 ' TO CLOG-TAG
           PERFORM LOG-D.
       DELKEY-PARA.
           EXEC CICS DELETE FILE('HCDF') RIDFLD(WS-KEY)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       READ-PARA.
           MOVE SPACES TO WS-REC
           EXEC CICS READ FILE('HCDF') INTO(WS-REC) LENGTH(WS-LEN)
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
      * RESP2 is read only after a non-NORMAL RESP: IBM states a
      * RESP2 per condition, not a value for NORMAL.
           MOVE 0 TO CLOG-RESP2
           IF WS-RESP NOT = 0
               MOVE WS-RESP2 TO CLOG-RESP2
           END-IF
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-CLOG)
                     LENGTH(33)
           END-EXEC.
