       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCWKLN.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-file-write-keylength   *
      * Original program (Apache-2.0).                                *
      * HC99, a mode typed after the transid, on file HCWK (records   *
      * of 16 bytes: key 4, name 8, quantity 4). Every WRITE names    *
      * KEYLENGTH, the full key length (4):                           *
      *   N  WRITE a record with a new key (K004), READ it back       *
      *   D  WRITE a record whose key is in the file (K002), READ     *
      *      K002 back                                                *
      *   T  WRITE a new record (K006) twice, KEYLENGTH from a data   *
      *      item, READ it back                                       *
      * Every result is a breadcrumb in TS queue HCLOG.               *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-LEN                PIC S9(4) COMP VALUE 16.
       01  WS-KLEN               PIC S9(4) COMP VALUE 4.
       01  WS-KEY                PIC X(4)  VALUE SPACES.
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
               WHEN 'N'
                   PERFORM NEW-PARA
               WHEN 'D'
                   PERFORM DUP-PARA
               WHEN 'T'
                   PERFORM TWICE-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       NEW-PARA.
           MOVE 'K004' TO WS-KEY
           MOVE 'K004DELTA   0040' TO WS-REC
           PERFORM WRITE-PARA
           MOVE 'N1 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'N2 ' TO CLOG-TAG
           PERFORM LOG-D.
       DUP-PARA.
           MOVE 'K002' TO WS-KEY
           MOVE 'K002NEWNAME 0099' TO WS-REC
           PERFORM WRITE-PARA
           MOVE 'D1 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'D2 ' TO CLOG-TAG
           PERFORM LOG-D.
       TWICE-PARA.
           MOVE 'K006' TO WS-KEY
           MOVE 'K006FOXTROT 0060' TO WS-REC
           PERFORM WRITE-VAR-PARA
           MOVE 'T1 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM WRITE-VAR-PARA
           MOVE 'T2 ' TO CLOG-TAG
           PERFORM LOG-R
           PERFORM READ-PARA
           MOVE 'T3 ' TO CLOG-TAG
           PERFORM LOG-D.
       WRITE-PARA.
           EXEC CICS WRITE FILE('HCWK') FROM(WS-REC) LENGTH(WS-LEN)
                     RIDFLD(WS-KEY) KEYLENGTH(4)
                     RESP(WS-RESP)
           END-EXEC.
       WRITE-VAR-PARA.
           EXEC CICS WRITE FILE('HCWK') FROM(WS-REC) LENGTH(WS-LEN)
                     RIDFLD(WS-KEY) KEYLENGTH(WS-KLEN)
                     RESP(WS-RESP)
           END-EXEC.
       READ-PARA.
           MOVE SPACES TO WS-REC
           EXEC CICS READ FILE('HCWK') INTO(WS-REC) LENGTH(WS-LEN)
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
