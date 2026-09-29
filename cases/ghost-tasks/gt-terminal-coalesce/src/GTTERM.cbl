       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTTERM.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-terminal-coalesce             *
      * Original program (Apache-2.0).                                *
      * Starts GT12 on its own terminal. Modes typed after the        *
      * transid:                                                      *
      *   3  three STARTs, INTERVAL(0): one GT12 task gets all three  *
      *   S  INTERVAL(0) and INTERVAL(10): two GT12 tasks             *
      *   C  INTERVAL(30) with REQID('GTREQ001')                      *
      *   K  CANCEL REQID('GTREQ001')                                 *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-TERM               PIC X(4)  VALUE SPACES.
       01  WS-A                  PIC X(10) VALUE 'ALPHA'.
       01  WS-B                  PIC X(10) VALUE 'BRAVO'.
       01  WS-C                  PIC X(10) VALUE 'CHARLIE'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP-D             PIC 99    VALUE 0.
       01  WS-TEXT               PIC X(20) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           MOVE EIBTRMID TO WS-TERM
           EVALUATE WS-MODE
               WHEN '3'
                   EXEC CICS START TRANSID('GT12') TERMID(WS-TERM)
                             INTERVAL(0) FROM(WS-A) LENGTH(10)
                   END-EXEC
                   EXEC CICS START TRANSID('GT12') TERMID(WS-TERM)
                             INTERVAL(0) FROM(WS-B) LENGTH(10)
                   END-EXEC
                   EXEC CICS START TRANSID('GT12') TERMID(WS-TERM)
                             INTERVAL(0) FROM(WS-C) LENGTH(10)
                   END-EXEC
                   MOVE 'QUEUED 3' TO WS-TEXT
               WHEN 'S'
                   EXEC CICS START TRANSID('GT12') TERMID(WS-TERM)
                             INTERVAL(0) FROM(WS-A) LENGTH(10)
                   END-EXEC
                   EXEC CICS START TRANSID('GT12') TERMID(WS-TERM)
                             INTERVAL(10) FROM(WS-B) LENGTH(10)
                   END-EXEC
                   MOVE 'QUEUED STAGGERED' TO WS-TEXT
               WHEN 'C'
                   EXEC CICS START TRANSID('GT12') TERMID(WS-TERM)
                             INTERVAL(30) FROM(WS-A) LENGTH(10)
                             REQID('GTREQ001')
                   END-EXEC
                   MOVE 'QUEUED GTREQ001' TO WS-TEXT
               WHEN OTHER
                   EXEC CICS CANCEL REQID('GTREQ001') RESP(WS-RESP)
                   END-EXEC
                   MOVE WS-RESP TO WS-RESP-D
                   STRING 'CANCEL RESP=' WS-RESP-D
                       DELIMITED BY SIZE INTO WS-TEXT
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-TEXT) LENGTH(20) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
