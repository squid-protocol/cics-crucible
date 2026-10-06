       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTREAD.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-start-options                 *
      * Original program (Apache-2.0).                                *
      * GT22, started by GTOPTS with no terminal: one RETRIEVE that   *
      * names INTO and all three data options, logged to TS GTLOG.    *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATA               PIC X(20) VALUE SPACES.
       01  WS-LEN                PIC S9(4) COMP VALUE 20.
       01  WS-RTRAN              PIC X(4)  VALUE SPACES.
       01  WS-RTERM              PIC X(4)  VALUE SPACES.
       01  WS-QUEUE              PIC X(8)  VALUE SPACES.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-LOG.
           05  FILLER            PIC X(2)  VALUE 'R='.
           05  LOG-RESP          PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' L='.
           05  LOG-LEN           PIC 9(4)  VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' T='.
           05  LOG-RTRAN         PIC X(4)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' M='.
           05  LOG-RTERM         PIC X(4)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' Q='.
           05  LOG-QUEUE         PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' D='.
           05  LOG-DATA          PIC X(20) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RETRIEVE INTO(WS-DATA) LENGTH(WS-LEN)
                     RTRANSID(WS-RTRAN) RTERMID(WS-RTERM)
                     QUEUE(WS-QUEUE) RESP(WS-RESP)
           END-EXEC
           MOVE WS-RESP TO LOG-RESP
           IF WS-RESP = DFHRESP(NORMAL)
              OR WS-RESP = DFHRESP(LENGERR)
               MOVE WS-LEN TO LOG-LEN
               MOVE WS-RTRAN TO LOG-RTRAN
               MOVE WS-RTERM TO LOG-RTERM
               MOVE WS-QUEUE TO LOG-QUEUE
               MOVE WS-DATA TO LOG-DATA
           END-IF
           EXEC CICS WRITEQ TS QUEUE('GTLOG') FROM(WS-LOG)
                     LENGTH(59)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
