       IDENTIFICATION DIVISION.
       PROGRAM-ID. CATWAD.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-address-twa-tctua       *
      * Original program (Apache-2.0).                                *
      * CA0H / CA0I / CA0J, a mode typed after the transid:           *
      *   W  (CA0H, TWASIZE 32) ADDRESS TWA, write a stamp through a  *
      *      view, LINK to CATWSB, which reaches the same TWA         *
      *   Z  (CA0I, TWASIZE 0) ADDRESS TWA: no TWA, null pointer      *
      *   S  (CA0J) ADDRESS TCTUA, write a stamp through a view       *
      *   R  (CA0J, a later task) ADDRESS TCTUA, read the stamp       *
      * ADDRESS is not an event: each result is a breadcrumb in TS    *
      * queue CALOG and in the SEND TEXT report.                      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-PTR                POINTER.
       01  WS-PTR-X REDEFINES WS-PTR PIC X(4).
       01  WS-PSTATE             PIC X(7)  VALUE SPACES.
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
       01  LS-TWA.
           05  TW-STAMP          PIC X(8).
           05  TW-REPLY          PIC X(8).
       01  LS-UA.
           05  UA-STAMP          PIC X(8).
           05  UA-SPARE          PIC X(8).
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'W'
                   PERFORM TWA-LINK-PARA
               WHEN 'Z'
                   PERFORM TWA-NONE-PARA
               WHEN 'S'
                   PERFORM UA-STORE-PARA
               WHEN 'R'
                   PERFORM UA-READ-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-REPORT) LENGTH(80) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       TWA-LINK-PARA.
           EXEC CICS ADDRESS TWA(WS-PTR)
           END-EXEC
           SET ADDRESS OF LS-TWA TO WS-PTR
           MOVE 'TWAMARK1' TO TW-STAMP
           MOVE SPACES TO TW-REPLY
           EXEC CICS LINK PROGRAM('CATWSB')
           END-EXEC
           MOVE 'W1 ' TO CLOG-TAG
           MOVE 'PRESENT' TO CLOG-P
           MOVE TW-STAMP TO CLOG-V1
           MOVE TW-REPLY TO CLOG-V2
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-CLOG)
                     LENGTH(37)
           END-EXEC
           STRING 'MODE=W STAMP=' TW-STAMP ' REPLY=' TW-REPLY
               DELIMITED BY SIZE INTO WS-REPORT.
       TWA-NONE-PARA.
           EXEC CICS ADDRESS TWA(WS-PTR)
           END-EXEC
           IF WS-PTR-X = X'FF000000'
               MOVE 'ABSENT' TO WS-PSTATE
           ELSE
               MOVE 'PRESENT' TO WS-PSTATE
           END-IF
           MOVE 'Z1 ' TO CLOG-TAG
           MOVE WS-PSTATE TO CLOG-P
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-CLOG)
                     LENGTH(37)
           END-EXEC
           STRING 'MODE=Z P=' WS-PSTATE
               DELIMITED BY SIZE INTO WS-REPORT.
       UA-STORE-PARA.
           EXEC CICS ADDRESS TCTUA(WS-PTR)
           END-EXEC
           SET ADDRESS OF LS-UA TO WS-PTR
           MOVE 'TCTUASTP' TO UA-STAMP
           MOVE 'S1 ' TO CLOG-TAG
           MOVE 'PRESENT' TO CLOG-P
           MOVE UA-STAMP TO CLOG-V1
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-CLOG)
                     LENGTH(37)
           END-EXEC
           STRING 'MODE=S P=PRESENT WROTE=' UA-STAMP
               DELIMITED BY SIZE INTO WS-REPORT.
       UA-READ-PARA.
           EXEC CICS ADDRESS TCTUA(WS-PTR)
           END-EXEC
           SET ADDRESS OF LS-UA TO WS-PTR
           MOVE 'R1 ' TO CLOG-TAG
           MOVE 'PRESENT' TO CLOG-P
           MOVE UA-STAMP TO CLOG-V1
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-CLOG)
                     LENGTH(37)
           END-EXEC
           STRING 'MODE=R P=PRESENT SEEN=' UA-STAMP
               DELIMITED BY SIZE INTO WS-REPORT.
