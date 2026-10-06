       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTASAB.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-assign-startcode              *
      * Original program (Apache-2.0).                                *
      * GT34, started by GT31 with no terminal: ASSIGN FACILITY with  *
      * no RESP and no handler. INVREQ's default action ends the task *
      * abnormally, so the second log item is never written.          *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FAC                PIC X(4)  VALUE SPACES.
       01  WS-RAN                PIC X(9)  VALUE 'GT34 RAN'.
       01  WS-DONE               PIC X(9)  VALUE 'GT34 DONE'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS WRITEQ TS QUEUE('GTLOG') FROM(WS-RAN)
                     LENGTH(9)
           END-EXEC
           EXEC CICS ASSIGN FACILITY(WS-FAC)
           END-EXEC
           EXEC CICS WRITEQ TS QUEUE('GTLOG') FROM(WS-DONE)
                     LENGTH(9)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
