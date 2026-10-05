       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCTERM.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-terminal-receive       *
      * Original program (Apache-2.0).                                *
      * Unformatted terminal input read with RECEIVE: a first RECEIVE *
      * MAXLENGTH(6) NOTRUNCATE takes the transaction id and a mode   *
      * letter and leaves the rest of the input for the next RECEIVE. *
      * Each mode reads that rest differently: LENGTH too short with  *
      * RESP (LENGERR), with HANDLE CONDITION LENGERR, with no        *
      * handler (the default action), in NOTRUNCATE pieces, and with  *
      * SET(ADDRESS OF). SEND CONTROL erases the screen first; one    *
      * mode sends a second SEND CONTROL with CURSOR and the other    *
      * device controls. Every path leaves a breadcrumb in WS-TRAIL,  *
      * sent with SEND TEXT at the end.                               *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TRAIL              PIC X(40) VALUE SPACES.
       01  WS-PTR                PIC S9(4) COMP VALUE 1.
       01  WS-HEAD               PIC X(6)  VALUE SPACES.
       01  WS-PART               PIC X(4)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 0.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP-D             PIC 99    VALUE 0.
       01  WS-LEN-D              PIC 99    VALUE 0.
       01  WS-CURSOR             PIC S9(4) COMP VALUE 85.
       LINKAGE SECTION.
       01  LS-INPUT              PIC X(20).
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS SEND CONTROL ERASE FREEKB END-EXEC
           EXEC CICS RECEIVE INTO(WS-HEAD) LENGTH(WS-INLEN)
                     MAXLENGTH(6) NOTRUNCATE RESP(WS-RESP)
           END-EXEC
           PERFORM NOTE-RESULT
           EVALUATE WS-HEAD(6:1)
               WHEN 'R'
                   PERFORM BY-RESP
               WHEN 'H'
                   PERFORM BY-HANDLE
               WHEN 'A'
                   PERFORM NO-HANDLER
               WHEN 'N'
                   PERFORM IN-PIECES
               WHEN 'S'
                   PERFORM BY-SET
               WHEN OTHER
                   PERFORM DEVICE-CTL
           END-EVALUATE
           GO TO SEND-TRAIL.
       NOTE-RESULT.
           MOVE WS-RESP TO WS-RESP-D
           MOVE WS-INLEN TO WS-LEN-D
           STRING WS-RESP-D '/' WS-LEN-D ' ' DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR.
      *    LENGTH(4) is the most the program accepts: LENGERR, RESP
       BY-RESP.
           MOVE 4 TO WS-INLEN
           EXEC CICS RECEIVE INTO(WS-PART) LENGTH(WS-INLEN)
                     RESP(WS-RESP)
           END-EXEC
           PERFORM NOTE-RESULT
           STRING WS-PART DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR.
      *    No LENGTH: WS-PART's own length; LENGERR goes to TOO-LONG
       BY-HANDLE.
           EXEC CICS HANDLE CONDITION LENGERR(TOO-LONG) END-EXEC
           EXEC CICS RECEIVE INTO(WS-PART) END-EXEC
           STRING 'n' DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR.
      *    No RESP, no handler: CICS's default action for LENGERR
       NO-HANDLER.
           EXEC CICS RECEIVE INTO(WS-PART) END-EXEC
           STRING 'n' DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR.
      *    Four bytes at a time until a shorter piece comes back
       IN-PIECES.
           PERFORM UNTIL WS-INLEN < 4
               EXEC CICS RECEIVE INTO(WS-PART) LENGTH(WS-INLEN)
                         MAXLENGTH(4) NOTRUNCATE RESP(WS-RESP)
               END-EXEC
               STRING WS-PART(1:WS-INLEN) '|' DELIMITED BY SIZE
                   INTO WS-TRAIL WITH POINTER WS-PTR
           END-PERFORM
           PERFORM NOTE-RESULT.
      *    SET: LS-INPUT addresses the data CICS received
       BY-SET.
           EXEC CICS RECEIVE SET(ADDRESS OF LS-INPUT)
                     LENGTH(WS-INLEN) MAXLENGTH(20) RESP(WS-RESP)
           END-EXEC
           PERFORM NOTE-RESULT
           STRING LS-INPUT(1:WS-INLEN) DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR.
       DEVICE-CTL.
           EXEC CICS SEND CONTROL CURSOR(WS-CURSOR) ALARM FRSET
                     ERASEAUP
           END-EXEC
           STRING 'c' DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR.
      *    The handler shows only that it ran and EIBRESP
       TOO-LONG.
           MOVE EIBRESP TO WS-RESP-D
           STRING 'L' WS-RESP-D DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR
           GO TO SEND-TRAIL.
       SEND-TRAIL.
           EXEC CICS SEND TEXT FROM(WS-TRAIL) LENGTH(40)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
