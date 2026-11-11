       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCIDA.
      *--------------------------------------------------------------- *
      * cics-crucible  condition-handling / hc-assign-identity         *
      * Original program (Apache-2.0).                                 *
      * HCID runs HCIDA. It ASSIGNs APPLID and SYSID in one command,   *
      * logs them and RESP to TS queue HCLOG (ASSIGN is not an event), *
      * LINKs to HCIDB (which ASSIGNs each option alone), then ASSIGNs *
      * SYSID and APPLID in the other order and logs once more.        *
      *--------------------------------------------------------------- *
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-APPL               PIC X(8)  VALUE 'XXXXXXXX'.
       01  WS-SYS                PIC X(4)  VALUE 'XXXX'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
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
           EXEC CICS ASSIGN APPLID(WS-APPL)
                     SYSID(WS-SYS)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'A1' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS LINK PROGRAM('HCIDB') END-EXEC
           MOVE 'XXXXXXXX' TO WS-APPL
           MOVE 'XXXX' TO WS-SYS
           EXEC CICS ASSIGN SYSID(WS-SYS)
                     APPLID(WS-APPL)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'A2' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       LOG-PARA.
           MOVE WS-APPL TO LOG-APPL
           MOVE WS-SYS TO LOG-SYS
           MOVE WS-RESP TO LOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG)
                     LENGTH(29)
           END-EXEC.
