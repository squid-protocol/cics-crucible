       IDENTIFICATION DIVISION.
       PROGRAM-ID. CACWAD.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-address-cwa             *
      * Original program (Apache-2.0).                                *
      * CA0K / CA0L, a mode typed after the transaction id:           *
      *   W  (CA0K) ADDRESS CWA, write a stamp through a view, LINK   *
      *      to CACWSB, which reaches the same CWA                    *
      *   S  (CA0K) ADDRESS CWA, write a stamp through a view         *
      *   R  (CA0L, a later task of another transaction) ADDRESS CWA, *
      *      read the stamp                                           *
      * ADDRESS is not an event: each result is a breadcrumb in TS    *
      * queue CALOG and in the SEND TEXT report.                      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-PTR                POINTER.
       01  WS-REPORT             PIC X(80) VALUE SPACES.
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' P='.
           05  CLOG-P            PIC X(7)  VALUE SPACES.
           05  FILLER            PIC X(4)  VALUE ' V1='.
           05  CLOG-V1           PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X(4)  VALUE ' V2='.
           05  CLOG-V2           PIC X(8)  VALUE SPACES.
       LINKAGE SECTION.
       01  LS-CWA.
           05  CW-STAMP          PIC X(8).
           05  CW-REPLY          PIC X(8).
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'W'
                   PERFORM CWA-LINK-PARA
               WHEN 'S'
                   PERFORM CWA-STORE-PARA
               WHEN 'R'
                   PERFORM CWA-READ-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-REPORT) LENGTH(80) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       CWA-LINK-PARA.
           EXEC CICS ADDRESS CWA(WS-PTR)
           END-EXEC
           SET ADDRESS OF LS-CWA TO WS-PTR
           MOVE 'CWAMARK1' TO CW-STAMP
           MOVE SPACES TO CW-REPLY
           EXEC CICS LINK PROGRAM('CACWSB')
           END-EXEC
           MOVE 'W1 ' TO CLOG-TAG
           MOVE 'PRESENT' TO CLOG-P
           MOVE CW-STAMP TO CLOG-V1
           MOVE CW-REPLY TO CLOG-V2
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-CLOG)
                     LENGTH(37)
           END-EXEC
           STRING 'MODE=W STAMP=' CW-STAMP ' REPLY=' CW-REPLY
               DELIMITED BY SIZE INTO WS-REPORT.
       CWA-STORE-PARA.
           EXEC CICS ADDRESS CWA(WS-PTR)
           END-EXEC
           SET ADDRESS OF LS-CWA TO WS-PTR
           MOVE 'CWASTAMP' TO CW-STAMP
           MOVE 'S1 ' TO CLOG-TAG
           MOVE 'PRESENT' TO CLOG-P
           MOVE CW-STAMP TO CLOG-V1
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-CLOG)
                     LENGTH(37)
           END-EXEC
           STRING 'MODE=S P=PRESENT WROTE=' CW-STAMP
               DELIMITED BY SIZE INTO WS-REPORT.
       CWA-READ-PARA.
           EXEC CICS ADDRESS CWA(WS-PTR)
           END-EXEC
           SET ADDRESS OF LS-CWA TO WS-PTR
           MOVE 'R1 ' TO CLOG-TAG
           MOVE 'PRESENT' TO CLOG-P
           MOVE CW-STAMP TO CLOG-V1
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-CLOG)
                     LENGTH(37)
           END-EXEC
           STRING 'MODE=R P=PRESENT SEEN=' CW-STAMP
               DELIMITED BY SIZE INTO WS-REPORT.
