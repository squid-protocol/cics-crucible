       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCINQP.
      *--------------------------------------------------------------- *
      * cics-crucible  condition-handling / hc-inquire-program         *
      * Original program (Apache-2.0).                                 *
      * HC96 inquires on two program names and logs RESP and the       *
      * STATUS value to TS queue HCLOG (INQUIRE is not an event):      *
      *   P1 HCINQP  this program (running, so available for use)      *
      *   P2 NOSUCHP not defined                                       *
      *--------------------------------------------------------------- *
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-NAME               PIC X(8)  VALUE SPACES.
       01  WS-STAT               PIC S9(8) COMP VALUE 0.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-LOG.
           05  LOG-TAG           PIC XX    VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  LOG-RESP          PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' S='.
           05  LOG-STAT          PIC 9(4)  VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE 'HCINQP' TO WS-NAME
           PERFORM INQ-PARA
           MOVE 'P1' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE 'NOSUCHP' TO WS-NAME
           PERFORM INQ-PARA
           MOVE 'P2' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       INQ-PARA.
           MOVE 0 TO WS-STAT
           EXEC CICS INQUIRE PROGRAM(WS-NAME)
                     STATUS(WS-STAT)
                     RESP(WS-RESP)
           END-EXEC
           IF WS-RESP NOT = 0
               MOVE 0 TO WS-STAT
           END-IF.
       LOG-PARA.
           MOVE WS-RESP TO LOG-RESP
           MOVE WS-STAT TO LOG-STAT
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG)
                     LENGTH(14)
           END-EXEC.
