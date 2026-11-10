       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCASGA.
      *--------------------------------------------------------------- *
      * cics-crucible  condition-handling / hc-assign-region           *
      * Original program (Apache-2.0).                                 *
      * HC97 runs HCASGA, the first program of the task. It ASSIGNs    *
      * PROGRAM and INVOKINGPROG, logs them and RESP to TS queue HCLOG *
      * (ASSIGN is not an event), LINKs to HCASGB (which logs the      *
      * same), then ASSIGNs again and logs once more.                  *
      *--------------------------------------------------------------- *
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PGM                PIC X(8)  VALUE SPACES.
       01  WS-INV                PIC X(8)  VALUE 'XXXXXXXX'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-LOG.
           05  LOG-TAG           PIC XX    VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' P='.
           05  LOG-PGM           PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X(4)  VALUE ' I=['.
           05  LOG-INV           PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X     VALUE ']'.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  LOG-RESP          PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS ASSIGN PROGRAM(WS-PGM)
                     INVOKINGPROG(WS-INV)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'A1' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS LINK PROGRAM('HCASGB') END-EXEC
           MOVE 'XXXXXXXX' TO WS-INV
           EXEC CICS ASSIGN PROGRAM(WS-PGM)
                     INVOKINGPROG(WS-INV)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'A2' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       LOG-PARA.
           MOVE WS-PGM TO LOG-PGM
           MOVE WS-INV TO LOG-INV
           MOVE WS-RESP TO LOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG)
                     LENGTH(31)
           END-EXEC.
