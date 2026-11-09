       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCSYNB.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-syncpoint-rollback     *
      * Original program (Apache-2.0). LINKed from HCSYNC (mode L):   *
      * a breadcrumb, SYNCPOINT ROLLBACK, a breadcrumb, RETURN.       *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  CLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' D='.
           05  CLOG-DATA         PIC X(16) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE 'B1 ' TO CLOG-TAG
           PERFORM LOG-W
           EXEC CICS SYNCPOINT ROLLBACK RESP(WS-RESP)
           END-EXEC
           MOVE 'B2 ' TO CLOG-TAG
           PERFORM LOG-W
           EXEC CICS RETURN END-EXEC.
       LOG-W.
           MOVE WS-RESP TO CLOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-CLOG)
                     LENGTH(27)
           END-EXEC.
