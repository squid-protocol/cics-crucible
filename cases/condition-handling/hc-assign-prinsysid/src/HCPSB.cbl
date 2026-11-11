       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCPSB.
      *--------------------------------------------------------------- *
      * cics-crucible  condition-handling / hc-assign-prinsysid        *
      * Original program (Apache-2.0).                                 *
      * LINKed from HCPSA with no COMMAREA. ASSIGNs PRINSYSID (the     *
      * same INVREQ as in HCPSA), logs RESP and RESP2, then ASSIGNs    *
      * SYSID and logs RESP alone: a failed ASSIGN does not spoil the  *
      * next command. Logs to TS queue HCLOG in HCPSA's layouts.       *
      *--------------------------------------------------------------- *
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PSYS               PIC X(4)  VALUE 'XXXX'.
       01  WS-SYS                PIC X(4)  VALUE 'XXXX'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-LOG.
           05  LOG-TAG           PIC XX    VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  LOG-RESP          PIC 99    VALUE 0.
           05  FILLER            PIC X(4)  VALUE ' R2='.
           05  LOG-RESP2         PIC 99    VALUE 0.
       01  WS-LOG-OK REDEFINES WS-LOG.
           05  OK-TAG            PIC XX.
           05  FILLER            PIC X(3).
           05  OK-RESP           PIC 99.
           05  FILLER            PIC X(6).
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS ASSIGN PRINSYSID(WS-PSYS)
                     RESP(WS-RESP)
                     RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B1' TO LOG-TAG
           MOVE WS-RESP TO LOG-RESP
           MOVE WS-RESP2 TO LOG-RESP2
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG)
                     LENGTH(13)
           END-EXEC
           EXEC CICS ASSIGN SYSID(WS-SYS)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'B2' TO OK-TAG
           MOVE WS-RESP TO OK-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG-OK)
                     LENGTH(7)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
