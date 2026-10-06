       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTCHLD.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-start-options                 *
      * Original program (Apache-2.0).                                *
      * GT24, a RUN TRANSID child of GTOPTS: logs that it ran to TS   *
      * GTLOG and returns.                                            *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-LOG                PIC X(9)  VALUE 'CHILD RAN'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS WRITEQ TS QUEUE('GTLOG') FROM(WS-LOG)
                     LENGTH(9)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
