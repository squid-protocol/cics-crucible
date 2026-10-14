       IDENTIFICATION DIVISION.
       PROGRAM-ID. CAADSB.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-address-commarea        *
      * Original program (Apache-2.0).                                *
      * The callee never names DFHCOMMAREA. It asks CICS for the      *
      * COMMAREA's address (ADDRESS COMMAREA), writes one breadcrumb  *
      * to TS queue CALOG (ADDRESS is not an event), and, if there is *
      * a COMMAREA, SETs ADDRESS OF its own view to that pointer,     *
      * reads the caller's bytes and writes a reply through it.       *
      * CICS sets the pointer to X'FF000000' when there is no         *
      * COMMAREA, so the test is against that value.                  *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PTR                POINTER.
       01  WS-PTR-X REDEFINES WS-PTR PIC X(4).
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' P='.
           05  CLOG-P            PIC X(7)  VALUE SPACES.
           05  FILLER            PIC X(7)  VALUE ' CALEN='.
           05  CLOG-LEN          PIC 9(4)  VALUE 0.
           05  FILLER            PIC X(5)  VALUE ' EYE='.
           05  CLOG-EYE          PIC X(4)  VALUE SPACES.
           05  FILLER            PIC X(5)  VALUE ' REQ='.
           05  CLOG-REQ          PIC X(8)  VALUE SPACES.
       LINKAGE SECTION.
       01  LS-VIEW.
           05  VW-EYE            PIC X(4).
           05  VW-REQUEST        PIC X(8).
           05  VW-REPLY          PIC X(8).
       PROCEDURE DIVISION.
       SUB-MAIN.
           EXEC CICS ADDRESS COMMAREA(WS-PTR)
           END-EXEC
           MOVE 'C1 ' TO CLOG-TAG
           MOVE EIBCALEN TO CLOG-LEN
           IF WS-PTR-X = X'FF000000'
               MOVE 'ABSENT' TO CLOG-P
           ELSE
               MOVE 'PRESENT' TO CLOG-P
               SET ADDRESS OF LS-VIEW TO WS-PTR
               MOVE VW-EYE TO CLOG-EYE
               MOVE VW-REQUEST TO CLOG-REQ
               MOVE 'PONG' TO VW-REPLY
           END-IF
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-CLOG)
                     LENGTH(46)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
