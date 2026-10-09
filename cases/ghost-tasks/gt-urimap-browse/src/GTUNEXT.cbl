       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTUNEXT.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-urimap-browse                 *
      * Original program (Apache-2.0).                                *
      * The background task GTUBROW starts (transaction GT62): it     *
      * RETRIEVEs the alias transaction name the browse returned and  *
      * logs it to TS queue GTUGO.                                    *
      *---------------------------------------------------------------*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATA                 PIC X(4)  VALUE SPACES.
       01  WS-LEN                  PIC S9(4) COMP VALUE 4.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RETRIEVE INTO(WS-DATA) LENGTH(WS-LEN)
           END-EXEC
           EXEC CICS WRITEQ TS QUEUE('GTUGO') FROM(WS-DATA)
                     LENGTH(4)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
