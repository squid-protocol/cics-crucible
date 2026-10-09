       IDENTIFICATION DIVISION.
       PROGRAM-ID. PCIMMA.
      *---------------------------------------------------------------*
      * cics-crucible  pseudo-conversational / pc-return-immediate    *
      * Original program (Apache-2.0).                                *
      * PC51, a mode typed after the transid:                         *
      *   I  RETURN TRANSID(PC52) COMMAREA(8) IMMEDIATE               *
      *   L  LINK PCIMML with a COMMAREA and SYNCONRETURN             *
      *   N  LINK PCIMML with no COMMAREA (it tries IMMEDIATE)        *
      *   S  START PC54, a task with no terminal (it tries IMMEDIATE) *
      * Every result is a breadcrumb in TS queue PCLOG.               *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-R-D                PIC 99    VALUE 0.
       01  WS-CA.
           05  CA-STAGE          PIC X     VALUE '1'.
           05  CA-TEXT           PIC X(7)  VALUE 'MENU-A1'.
       01  WS-ALOG.
           05  ALOG-TAG          PIC X(3)  VALUE SPACES.
           05  ALOG-TEXT         PIC X(7)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  ALOG-RESP         PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'I'
                   PERFORM IMMEDIATE-PARA
               WHEN 'L'
                   PERFORM LINK-PARA
               WHEN 'N'
                   PERFORM NOCA-PARA
               WHEN 'S'
                   PERFORM START-PARA
           END-EVALUATE
           EXEC CICS RETURN END-EXEC.
       IMMEDIATE-PARA.
           MOVE 'A1 ' TO ALOG-TAG
           MOVE CA-TEXT TO ALOG-TEXT
           MOVE 0 TO ALOG-RESP
           PERFORM LOG-A
           EXEC CICS RETURN TRANSID('PC52') COMMAREA(WS-CA)
                     LENGTH(8) IMMEDIATE
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'A1X' TO ALOG-TAG
           MOVE SPACES TO ALOG-TEXT
           MOVE WS-RESP TO ALOG-RESP
           PERFORM LOG-A.
       LINK-PARA.
           MOVE 'LINK-A1' TO CA-TEXT
           EXEC CICS LINK PROGRAM('PCIMML') COMMAREA(WS-CA)
                     LENGTH(8) SYNCONRETURN
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'A2 ' TO ALOG-TAG
           MOVE CA-TEXT TO ALOG-TEXT
           MOVE WS-RESP TO ALOG-RESP
           PERFORM LOG-A.
       NOCA-PARA.
           EXEC CICS LINK PROGRAM('PCIMML')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'A3 ' TO ALOG-TAG
           MOVE 'BACK' TO ALOG-TEXT
           MOVE WS-RESP TO ALOG-RESP
           PERFORM LOG-A.
       START-PARA.
           EXEC CICS START TRANSID('PC54') INTERVAL(0)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'A4 ' TO ALOG-TAG
           MOVE 'STARTED' TO ALOG-TEXT
           MOVE WS-RESP TO ALOG-RESP
           PERFORM LOG-A.
       LOG-A.
           EXEC CICS WRITEQ TS QUEUE('PCLOG') FROM(WS-ALOG)
                     LENGTH(15)
           END-EXEC.
