       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCDSET.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-file-dataset-synonym   *
      * Original program (Apache-2.0).                                *
      * Every file command names its file with DATASET, the older     *
      * spelling of FILE. HC90, a mode typed after the transid, on    *
      * file HCDS (records of 16 bytes: key 4, name 8, quantity 4):   *
      *   W  WRITE of a new key, WRITE of a key already there,        *
      *      READ of both                                             *
      *   R  REWRITE with no READ UPDATE yet, READ UPDATE of K002,    *
      *      REWRITE of it, READ of K002                              *
      *   D  DELETE of K003, READ of K003, DELETE of K003 again,      *
      *      READ of K001                                             *
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
               WHEN 'W'
                   PERFORM WRITE-MODE
               WHEN 'R'
                   PERFORM REWRITE-MODE
               WHEN 'D'
                   PERFORM DELETE-MODE
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       WRITE-MODE.
           MOVE 'K004DELTA   0040' TO WS-REC
           MOVE 'K004' TO WS-KEY
           PERFORM WRITE-PARA
           MOVE 'W1 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'W2 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE 'K002NEWNAME 0099' TO WS-REC
           MOVE 'K002' TO WS-KEY
           PERFORM WRITE-PARA
           MOVE 'W3 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'W4 ' TO CLOG-TAG
           PERFORM LOG-D.
       REWRITE-MODE.
      * No READ UPDATE has been issued yet: REWRITE is INVREQ RESP2 30.
           MOVE 'K002BRAVO   0099' TO WS-REC
           EXEC CICS REWRITE DATASET('HCDS') FROM(WS-REC)
                     LENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R1 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'K002' TO WS-KEY
           EXEC CICS READ DATASET('HCDS') INTO(WS-REC) LENGTH(WS-LEN)
                     RIDFLD(WS-KEY) UPDATE
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R2 ' TO CLOG-TAG
           PERFORM LOG-D
           MOVE '0099' TO WS-REC(13:4)
           EXEC CICS REWRITE DATASET('HCDS') FROM(WS-REC)
                     LENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'R3 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'R4 ' TO CLOG-TAG
           PERFORM LOG-D.
       DELETE-MODE.
           MOVE 'K003' TO WS-KEY
           PERFORM DELETE-PARA
           MOVE 'D1 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'D2 ' TO CLOG-TAG
           PERFORM LOG-D
           PERFORM DELETE-PARA
           MOVE 'D3 ' TO CLOG-TAG
           PERFORM LOG-R
           MOVE 'K001' TO WS-KEY
           PERFORM READ-PARA
           MOVE 'D4 ' TO CLOG-TAG
           PERFORM LOG-D.
       WRITE-PARA.
           EXEC CICS WRITE DATASET('HCDS') FROM(WS-REC)
                     LENGTH(WS-LEN) RIDFLD(WS-KEY)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
      * IBM documents no RESP2 for DUPREC: the log never carries one.
           MOVE 0 TO WS-RESP2.
       DELETE-PARA.
           EXEC CICS DELETE DATASET('HCDS') RIDFLD(WS-KEY)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC.
       READ-PARA.
           MOVE SPACES TO WS-REC
           EXEC CICS READ DATASET('HCDS') INTO(WS-REC) LENGTH(WS-LEN)
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
