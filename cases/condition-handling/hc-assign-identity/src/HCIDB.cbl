       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCIDB.
      *--------------------------------------------------------------- *
      * cics-crucible  condition-handling / hc-assign-identity         *
      * Original program (Apache-2.0).                                 *
      * LINKed from HCIDA with no COMMAREA. ASSIGNs SYSID alone, logs, *
      * then APPLID alone, logs: the option not asked for keeps the    *
      * sentinel it was preset to. Logs to TS queue HCLOG in HCIDA's   *
      * record layout.                                                 *
      *--------------------------------------------------------------- *
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-APPL               PIC X(8)  VALUE 'XXXXXXXX'.
       01  WS-SYS                PIC X(4)  VALUE 'XXXX'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-LOG.
           05  LOG-TAG           PIC XX    VALUE SPACES.
           05  FILLER            PIC X(4)  VALUE ' A=['.
           05  LOG-APPL          PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X(5)  VALUE '] S=['.
           05  LOG-SYS           PIC X(4)  VALUE SPACES.
           05  FILLER            PIC X     VALUE ']'.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  LOG-RESP          PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS ASSIGN SYSID(WS-SYS)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'B1' TO LOG-TAG
           PERFORM LOG-PARA
           MOVE 'XXXX' TO WS-SYS
           EXEC CICS ASSIGN APPLID(WS-APPL)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'B2' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS RETURN END-EXEC.
       LOG-PARA.
           MOVE WS-APPL TO LOG-APPL
           MOVE WS-SYS TO LOG-SYS
           MOVE WS-RESP TO LOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG)
                     LENGTH(29)
           END-EXEC.
