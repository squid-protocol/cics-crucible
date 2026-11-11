       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCNSCH.
      * condition-handling / hc-fetch-nosuspend
      * Original code only (cics-crucible AGENTS.md rule 1).
      * HCNC, a RUN TRANSID child of HCNSPR: waits 5 seconds, logs
      * that it ran to TS HCNCLOG and returns normally.
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-LOG                PIC X(9)  VALUE 'CHILD RAN'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS DELAY INTERVAL(5) END-EXEC
           EXEC CICS WRITEQ TS QUEUE('HCNCLOG') FROM(WS-LOG)
                     LENGTH(9)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
