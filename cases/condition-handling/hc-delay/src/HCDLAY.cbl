       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCDLAY.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-delay                  *
      * Original program (Apache-2.0).                                *
      * HC93 issues six DELAY commands, each with RESP, and logs the  *
      * RESP of each to TS queue HCLOG (DELAY is not an event):       *
      *   D1 no options (the default, INTERVAL(0))                    *
      *   D2 INTERVAL(0) in packed decimal                            *
      *   D3 INTERVAL(0000002) in packed decimal (hhmmss)             *
      *   D4 FOR SECONDS(90): SECONDS alone may exceed 59             *
      *   D5 FOR MINUTES(75): MINUTES alone may exceed 59             *
      *   D6 FOR HOURS(1) MINUTES(2) SECONDS(3)                       *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INT0               PIC S9(7) COMP-3 VALUE 0.
       01  WS-INT2               PIC S9(7) COMP-3 VALUE 2.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-LOG.
           05  LOG-TAG           PIC XX    VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  LOG-RESP          PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS DELAY RESP(WS-RESP)
           END-EXEC
           MOVE 'D1' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS DELAY INTERVAL(WS-INT0) RESP(WS-RESP)
           END-EXEC
           MOVE 'D2' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS DELAY INTERVAL(WS-INT2) RESP(WS-RESP)
           END-EXEC
           MOVE 'D3' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS DELAY FOR SECONDS(90) RESP(WS-RESP)
           END-EXEC
           MOVE 'D4' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS DELAY FOR MINUTES(75) RESP(WS-RESP)
           END-EXEC
           MOVE 'D5' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS DELAY FOR HOURS(1) MINUTES(2) SECONDS(3)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'D6' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       LOG-PARA.
           MOVE WS-RESP TO LOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG)
                     LENGTH(7)
           END-EXEC.
