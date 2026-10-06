       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTRTRN.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-start-options                 *
      * Original program (Apache-2.0).                                *
      * GT23, started by GTOPTS with no terminal: RETRIEVEs with no   *
      * INTO, only RTRANSID, until the response is not NORMAL, and    *
      * logs each response to TS GTLOG.                               *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RTRAN              PIC X(4)  VALUE SPACES.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-MORE               PIC X     VALUE 'Y'.
       01  WS-LOG.
           05  FILLER            PIC X(2)  VALUE 'R='.
           05  LOG-RESP          PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' T='.
           05  LOG-RTRAN         PIC X(4)  VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           PERFORM UNTIL WS-MORE = 'N'
               MOVE SPACES TO WS-RTRAN
               EXEC CICS RETRIEVE RTRANSID(WS-RTRAN) RESP(WS-RESP)
               END-EXEC
               MOVE WS-RESP TO LOG-RESP
               IF WS-RESP = DFHRESP(NORMAL)
                   MOVE WS-RTRAN TO LOG-RTRAN
               ELSE
                   MOVE SPACES TO LOG-RTRAN
                   MOVE 'N' TO WS-MORE
               END-IF
               EXEC CICS WRITEQ TS QUEUE('GTLOG') FROM(WS-LOG)
                         LENGTH(11)
               END-EXEC
           END-PERFORM
           EXEC CICS RETURN END-EXEC.
