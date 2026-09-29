       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTSHOW.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-terminal-coalesce             *
      * Original program (Apache-2.0).                                *
      * Transaction GT12, started on a terminal by START TERMID.      *
      * RETRIEVEs every data record it can get and shows them.        *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATA               PIC X(10) VALUE SPACES.
       01  WS-LEN                PIC S9(4) COMP VALUE 0.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-COUNT              PIC 9     VALUE 0.
       01  WS-SHOW               PIC X(40) VALUE 'SHOW:'.
       01  WS-PTR                PIC S9(4) COMP VALUE 6.
       PROCEDURE DIVISION.
       MAIN-PARA.
           PERFORM WITH TEST AFTER
                   UNTIL WS-RESP NOT = DFHRESP(NORMAL)
               MOVE SPACES TO WS-DATA
               MOVE 10 TO WS-LEN
               EXEC CICS RETRIEVE INTO(WS-DATA) LENGTH(WS-LEN)
                         RESP(WS-RESP)
               END-EXEC
               IF WS-RESP = DFHRESP(NORMAL)
                   IF WS-COUNT > 0
                       STRING ',' DELIMITED BY SIZE INTO WS-SHOW
                           WITH POINTER WS-PTR
                   END-IF
                   STRING WS-DATA DELIMITED BY SPACE INTO WS-SHOW
                       WITH POINTER WS-PTR
                   ADD 1 TO WS-COUNT
               END-IF
           END-PERFORM
           EXEC CICS SEND TEXT FROM(WS-SHOW) LENGTH(40) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
