       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCASGB.
      *--------------------------------------------------------------- *
      * cics-crucible  condition-handling / hc-assign-region           *
      * Original program (Apache-2.0).                                 *
      * LINKed from HCASGA with no COMMAREA. ASSIGNs PROGRAM and       *
      * INVOKINGPROG (which now name HCASGB and HCASGA) and logs them  *
      * to TS queue HCLOG in HCASGA's record layout.                   *
      *--------------------------------------------------------------- *
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PGM                PIC X(8)  VALUE SPACES.
       01  WS-INV                PIC X(8)  VALUE 'XXXXXXXX'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-LOG.
           05  LOG-TAG           PIC XX    VALUE 'B1'.
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
           MOVE WS-PGM TO LOG-PGM
           MOVE WS-INV TO LOG-INV
           MOVE WS-RESP TO LOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG)
                     LENGTH(31)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
