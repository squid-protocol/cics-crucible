       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCDOCU.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-document               *
      * Original program (Apache-2.0).                                *
      * HC95 creates two documents from TEXT, then retrieves each by  *
      * its token, logging RESP and the bytes to TS queue HCLOG       *
      * (DOCUMENT is not an event):                                   *
      *   C1 CREATE doc A  TEXT 'ORDER 000417' (12 bytes)             *
      *   C2 CREATE doc B  TEXT 'SHIPPED 9' (9 bytes), with DOCSIZE   *
      *   R1 RETRIEVE doc A (the older document) INTO, LENGTH,        *
      *      MAXLENGTH                                                *
      *   R2 RETRIEVE doc B the same way                              *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TEXT-A             PIC X(12) VALUE 'ORDER 000417'.
       01  WS-TEXT-B             PIC X(9)  VALUE 'SHIPPED 9'.
       01  WS-TOKEN-A            PIC X(16) VALUE LOW-VALUES.
       01  WS-TOKEN-B            PIC X(16) VALUE LOW-VALUES.
       01  WS-SIZE               PIC S9(8) COMP VALUE 0.
       01  WS-BUF                PIC X(40) VALUE SPACES.
       01  WS-LEN                PIC S9(8) COMP VALUE 0.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-LOG.
           05  LOG-TAG           PIC XX    VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  LOG-RESP          PIC 99    VALUE 0.
       01  WS-LOGD.
           05  LOGD-TAG          PIC XX    VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' L='.
           05  LOGD-LEN          PIC 9(4)  VALUE 0.
           05  FILLER            PIC X     VALUE SPACE.
           05  LOGD-DATA         PIC X(12) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS DOCUMENT CREATE DOCTOKEN(WS-TOKEN-A)
                     TEXT(WS-TEXT-A) LENGTH(12)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'C1' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS DOCUMENT CREATE DOCTOKEN(WS-TOKEN-B)
                     TEXT(WS-TEXT-B) LENGTH(9)
                     DOCSIZE(WS-SIZE)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'C2' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE SPACES TO WS-BUF
           MOVE 40 TO WS-LEN
           EXEC CICS DOCUMENT RETRIEVE DOCTOKEN(WS-TOKEN-A)
                     INTO(WS-BUF) LENGTH(WS-LEN) MAXLENGTH(40)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'R1' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE 'R1' TO LOGD-TAG
           PERFORM LOGD-PARA
           MOVE SPACES TO WS-BUF
           MOVE 40 TO WS-LEN
           EXEC CICS DOCUMENT RETRIEVE DOCTOKEN(WS-TOKEN-B)
                     INTO(WS-BUF) LENGTH(WS-LEN) MAXLENGTH(40)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'R2' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE 'R2' TO LOGD-TAG
           PERFORM LOGD-PARA
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       LOG-PARA.
           MOVE WS-RESP TO LOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG)
                     LENGTH(7)
           END-EXEC.
       LOGD-PARA.
           MOVE WS-LEN TO LOGD-LEN
           MOVE WS-BUF(1:12) TO LOGD-DATA
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOGD)
                     LENGTH(22)
           END-EXEC.
