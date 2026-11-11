       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCPSA.
      *--------------------------------------------------------------- *
      * cics-crucible  condition-handling / hc-assign-prinsysid        *
      * Original program (Apache-2.0).                                 *
      * HCPS runs HCPSA on terminal T001. It ASSIGNs PRINSYSID (the    *
      * principal facility is a 3270, not an MRO / LU6.1 / APPC        *
      * session) and logs RESP and RESP2 to TS queue HCLOG (ASSIGN is  *
      * not an event). It LINKs to HCPSB, then ASSIGNs SYSID and logs  *
      * RESP alone. The PRINSYSID area is never read back.             *
      *--------------------------------------------------------------- *
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PSYS               PIC X(4)  VALUE 'XXXX'.
       01  WS-SYS                PIC X(4)  VALUE 'XXXX'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
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
           MOVE 'A1' TO LOG-TAG
           MOVE WS-RESP TO LOG-RESP
           MOVE WS-RESP2 TO LOG-RESP2
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG)
                     LENGTH(13)
           END-EXEC
           EXEC CICS LINK PROGRAM('HCPSB') END-EXEC
           EXEC CICS ASSIGN SYSID(WS-SYS)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'A2' TO OK-TAG
           MOVE WS-RESP TO OK-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG-OK)
                     LENGTH(7)
           END-EXEC
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
