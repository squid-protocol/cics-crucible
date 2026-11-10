       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCFCHD.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-fetch-child            *
      * Original program (Apache-2.0).                                *
      * HCFD, a RUN TRANSID child of HCFPAR: logs that it ran to TS   *
      * HCFCLOG and returns normally.                                 *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-LOG                PIC X(9)  VALUE 'CHILD RAN'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS WRITEQ TS QUEUE('HCFCLOG') FROM(WS-LOG)
                     LENGTH(9)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
