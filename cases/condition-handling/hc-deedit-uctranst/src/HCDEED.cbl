       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCDEED.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-deedit-uctranst        *
      * Original program (Apache-2.0).                                *
      * HC41, modes typed after the transid:                          *
      *   D  EXEC CICS BIF DEEDIT on five fields and LENGERR for a    *
      *      LENGTH of zero (with RESP)                               *
      *   U  INQUIRE TERMINAL / SET TERMINAL UCTRANST, with DFHVALUE  *
      *      and with a bad CVDA and a terminal that is not defined   *
      *   L  BIF DEEDIT with LENGTH zero and no RESP: LENGERR's       *
      *      default action                                           *
      * Every result is a breadcrumb in TS queue HCLOG (BIF DEEDIT,   *
      * INQUIRE and SET are not events).                              *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-ZERO               PIC S9(8) COMP VALUE 0.
       01  WS-BAD                PIC S9(8) COMP VALUE 999.
       01  WS-UCT                PIC S9(8) COMP VALUE 0.
       01  WS-R-D                PIC 99    VALUE 0.
       01  WS-F1                 PIC X(9)  VALUE '14-6704/B'.
       01  WS-F2                 PIC X(9)  VALUE '$25.68   '.
       01  WS-F3                 PIC X(4)  VALUE '123-'.
       01  WS-F4                 PIC X(1)  VALUE 'A'.
       01  WS-F5                 PIC X(8)  VALUE 'ab12cd3C'.
       01  WS-F6                 PIC X(9)  VALUE 'x7y8z9 q1'.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-DLOG.
           05  DLOG-TAG          PIC X(3)  VALUE SPACES.
           05  DLOG-TEXT         PIC X(9)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  DLOG-RESP         PIC 99    VALUE 0.
       01  WS-ULOG.
           05  ULOG-TAG          PIC X(3)  VALUE SPACES.
           05  ULOG-NUM          PIC 9(9)  VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  ULOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' 2='.
           05  ULOG-RESP2        PIC XX    VALUE '--'.
       01  WS-LLOG               PIC X(9)  VALUE 'L1 BEFORE'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'D'
                   PERFORM DEEDIT-PARA
               WHEN 'U'
                   PERFORM UCTRANST-PARA
               WHEN 'L'
                   PERFORM LENGERR-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       DEEDIT-PARA.
           EXEC CICS BIF DEEDIT FIELD(WS-F1) LENGTH(9)
           END-EXEC
           MOVE 'D1 ' TO DLOG-TAG
           MOVE WS-F1 TO DLOG-TEXT
           PERFORM LOG-D
           EXEC CICS BIF DEEDIT FIELD(WS-F2) LENGTH(9)
           END-EXEC
           MOVE 'D2 ' TO DLOG-TAG
           MOVE WS-F2 TO DLOG-TEXT
           PERFORM LOG-D
           EXEC CICS BIF DEEDIT FIELD(WS-F3) LENGTH(4)
           END-EXEC
           MOVE 'D3 ' TO DLOG-TAG
           MOVE WS-F3 TO DLOG-TEXT
           PERFORM LOG-D
           EXEC CICS BIF DEEDIT FIELD(WS-F4) LENGTH(1)
           END-EXEC
           MOVE 'D4 ' TO DLOG-TAG
           MOVE WS-F4 TO DLOG-TEXT
           PERFORM LOG-D
           EXEC CICS BIF DEEDIT FIELD(WS-F5) LENGTH(8)
           END-EXEC
           MOVE 'D5 ' TO DLOG-TAG
           MOVE WS-F5 TO DLOG-TEXT
           PERFORM LOG-D
           EXEC CICS BIF DEEDIT FIELD(WS-F6) LENGTH(WS-ZERO)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'D6 ' TO DLOG-TAG
           MOVE SPACES TO DLOG-TEXT
           MOVE WS-RESP TO DLOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-DLOG)
                     LENGTH(17)
           END-EXEC.
       LOG-D.
           MOVE 0 TO DLOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-DLOG)
                     LENGTH(17)
           END-EXEC.
       UCTRANST-PARA.
           MOVE 0 TO WS-UCT
           EXEC CICS INQUIRE TERMINAL(EIBTRMID) UCTRANST(WS-UCT)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U1 ' TO ULOG-TAG
           PERFORM LOG-U-OK
           EXEC CICS SET TERMINAL(EIBTRMID)
                     UCTRANST(DFHVALUE(NOUCTRAN))
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U2 ' TO ULOG-TAG
           MOVE 0 TO WS-UCT
           PERFORM LOG-U-OK
           EXEC CICS INQUIRE TERMINAL(EIBTRMID) UCTRANST(WS-UCT)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U3 ' TO ULOG-TAG
           PERFORM LOG-U-OK
           EXEC CICS SET TERMINAL(EIBTRMID)
                     UCTRANST(DFHVALUE(TRANIDONLY))
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U4 ' TO ULOG-TAG
           MOVE 0 TO WS-UCT
           PERFORM LOG-U-OK
           EXEC CICS INQUIRE TERMINAL(EIBTRMID) UCTRANST(WS-UCT)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U5 ' TO ULOG-TAG
           PERFORM LOG-U-OK
           EXEC CICS SET TERMINAL(EIBTRMID) UCTRANST(WS-BAD)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U6 ' TO ULOG-TAG
           MOVE 0 TO WS-UCT
           PERFORM LOG-U-FAIL
           EXEC CICS INQUIRE TERMINAL('ZZZZ') UCTRANST(WS-UCT)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U7 ' TO ULOG-TAG
           PERFORM LOG-U-FAIL
           EXEC CICS SET TERMINAL('ZZZZ')
                     UCTRANST(DFHVALUE(UCTRAN))
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U8 ' TO ULOG-TAG
           PERFORM LOG-U-FAIL.
       LOG-U-OK.
           MOVE WS-UCT TO ULOG-NUM
           MOVE WS-RESP TO ULOG-RESP
           MOVE '--' TO ULOG-RESP2
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-ULOG)
                     LENGTH(22)
           END-EXEC.
       LOG-U-FAIL.
           MOVE 0 TO ULOG-NUM
           MOVE WS-RESP TO ULOG-RESP
           MOVE WS-RESP2 TO WS-R-D
           MOVE WS-R-D TO ULOG-RESP2
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-ULOG)
                     LENGTH(22)
           END-EXEC.
       LENGERR-PARA.
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LLOG)
                     LENGTH(9)
           END-EXEC
           EXEC CICS BIF DEEDIT FIELD(WS-F6) LENGTH(WS-ZERO)
           END-EXEC
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LLOG)
                     LENGTH(9)
           END-EXEC.
