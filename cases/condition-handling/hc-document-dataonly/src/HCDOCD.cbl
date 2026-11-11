       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCDOCD.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-document-dataonly      *
      * Original program (Apache-2.0).                                *
      * HC89 creates two documents from TEXT, then retrieves them     *
      * with DOCUMENT RETRIEVE ... DATAONLY and logs RESP, RESP2,     *
      * LENGTH (and the bytes) to TS queue HCLOG (DOCUMENT is not an  *
      * event):                                                       *
      *   D1 RETRIEVE doc A into a 40-byte area, MAXLENGTH(40)        *
      *   D2 RETRIEVE doc A into a 5-byte area, MAXLENGTH(5):         *
      *      too short, LENGERR RESP2 2, LENGTH = size needed         *
      *   D3 RETRIEVE doc A into a 1-byte dummy area, MAXLENGTH(0),   *
      *      the size probe IBM describes: LENGERR RESP2 2            *
      *   D4 RETRIEVE doc B (the later document) into the 40-byte area*
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TEXT-A             PIC X(12) VALUE 'ORDER 000417'.
       01  WS-TEXT-B             PIC X(9)  VALUE 'SHIPPED 9'.
       01  WS-TOKEN-A            PIC X(16) VALUE LOW-VALUES.
       01  WS-TOKEN-B            PIC X(16) VALUE LOW-VALUES.
       01  WS-BUF                PIC X(40) VALUE SPACES.
       01  WS-SMALL              PIC X(5)  VALUE SPACES.
       01  WS-DUMMY              PIC X     VALUE SPACE.
       01  WS-LEN                PIC S9(8) COMP VALUE 0.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-LOG.
           05  LOG-TAG           PIC XX    VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  LOG-RESP          PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' E='.
           05  LOG-RESP2         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' L='.
           05  LOG-LEN           PIC 9(4)  VALUE 0.
       01  WS-LOGD.
           05  LOGD-TAG          PIC XX    VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' D='.
           05  LOGD-DATA         PIC X(12) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS DOCUMENT CREATE DOCTOKEN(WS-TOKEN-A)
                     TEXT(WS-TEXT-A) LENGTH(12)
           END-EXEC
           EXEC CICS DOCUMENT CREATE DOCTOKEN(WS-TOKEN-B)
                     TEXT(WS-TEXT-B) LENGTH(9)
           END-EXEC
           MOVE SPACES TO WS-BUF
           MOVE 77 TO WS-LEN
           EXEC CICS DOCUMENT RETRIEVE DOCTOKEN(WS-TOKEN-A)
                     INTO(WS-BUF) LENGTH(WS-LEN) MAXLENGTH(40)
                     DATAONLY
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'D1' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE 'D1' TO LOGD-TAG
           MOVE WS-BUF(1:12) TO LOGD-DATA
           PERFORM LOGD-PARA
           MOVE 77 TO WS-LEN
           EXEC CICS DOCUMENT RETRIEVE DOCTOKEN(WS-TOKEN-A)
                     INTO(WS-SMALL) LENGTH(WS-LEN) MAXLENGTH(5)
                     DATAONLY
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'D2' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE 77 TO WS-LEN
           EXEC CICS DOCUMENT RETRIEVE DOCTOKEN(WS-TOKEN-A)
                     INTO(WS-DUMMY) LENGTH(WS-LEN) MAXLENGTH(0)
                     DATAONLY
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'D3' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE SPACES TO WS-BUF
           MOVE 77 TO WS-LEN
           EXEC CICS DOCUMENT RETRIEVE DOCTOKEN(WS-TOKEN-B)
                     INTO(WS-BUF) LENGTH(WS-LEN) MAXLENGTH(40)
                     DATAONLY
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'D4' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE 'D4' TO LOGD-TAG
           MOVE WS-BUF(1:12) TO LOGD-DATA
           PERFORM LOGD-PARA
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       LOG-PARA.
           MOVE WS-RESP TO LOG-RESP
           MOVE WS-RESP2 TO LOG-RESP2
           MOVE WS-LEN TO LOG-LEN
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG)
                     LENGTH(19)
           END-EXEC.
       LOGD-PARA.
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOGD)
                     LENGTH(17)
           END-EXEC.
