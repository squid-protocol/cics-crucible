       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTPOST.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-post-wait-event               *
      * Original program (Apache-2.0).                                *
      * GT61 <mode>: a first RECEIVE MAXLENGTH(6) NOTRUNCATE takes    *
      * the transaction id and the mode letter and keeps the rest of  *
      * the input. One line per run goes to TS queue GTLOG.           *
      *   W  POST AFTER SECONDS(5) with a REQID and SET, the area     *
      *      read before and after WAIT EVENT ECADDR, then CANCEL of  *
      *      that REQID                                               *
      *   N  WAIT EVENT ECADDR on a null pointer                      *
      *   P  POST TIME(090000) at 10:00:00, already past              *
      *   F  CONVERSE whose reply fits the TOLENGTH given (10)        *
      *   C  CONVERSE whose reply is cut by the TOLENGTH given (4)    *
      * The reply of CONVERSE is the rest of the operator's input.    *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-HEAD               PIC X(6)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 0.
       01  WS-RESP               PIC S9(8) COMP VALUE -1.
       01  WS-RESP2              PIC S9(8) COMP VALUE -1.
       01  WS-PTR                POINTER.
       01  WS-NPTR               POINTER.
       01  WS-D1                 PIC 99    VALUE 0.
       01  WS-D2                 PIC 99    VALUE 0.
       01  WS-D3                 PIC 99    VALUE 0.
       01  WS-BEF                PIC X(4)  VALUE 'OTHR'.
       01  WS-AFT                PIC X(6)  VALUE 'NOTPST'.
       01  WS-PROMPT             PIC X(8)  VALUE 'GT61 ASK'.
       01  WS-REPLY              PIC X(10) VALUE '..........'.
       01  WS-TOLEN              PIC S9(4) COMP VALUE 0.
       01  WS-TOLEN-D            PIC 9(4)  VALUE 0.
       01  WS-LINE               PIC X(40) VALUE SPACES.
       01  WS-LPTR               PIC S9(4) COMP VALUE 1.
       01  WS-LLEN               PIC S9(4) COMP VALUE 0.
       LINKAGE SECTION.
       01  LS-TEC                PIC X(4).
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-HEAD) LENGTH(WS-INLEN)
                     MAXLENGTH(6) NOTRUNCATE
           END-EXEC
           EVALUATE WS-HEAD(6:1)
               WHEN 'W'
                   PERFORM POST-WAIT-CANCEL
               WHEN 'N'
                   PERFORM WAIT-NULL
               WHEN 'P'
                   PERFORM POST-PAST
               WHEN 'F'
                   MOVE 10 TO WS-TOLEN
                   PERFORM CONVERSE-REPLY
               WHEN OTHER
                   MOVE 4 TO WS-TOLEN
                   PERFORM CONVERSE-REPLY
           END-EVALUATE
           COMPUTE WS-LLEN = WS-LPTR - 1
           EXEC CICS WRITEQ TS QUEUE('GTLOG') FROM(WS-LINE)
                     LENGTH(WS-LLEN)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       POST-WAIT-CANCEL.
           EXEC CICS POST AFTER SECONDS(5) REQID('GTPOSTW')
                     SET(WS-PTR) RESP(WS-RESP)
           END-EXEC
           MOVE WS-RESP TO WS-D1
           SET ADDRESS OF LS-TEC TO WS-PTR
           IF LS-TEC = LOW-VALUES
               MOVE 'ZERO' TO WS-BEF
           END-IF
           EXEC CICS WAIT EVENT ECADDR(WS-PTR) RESP(WS-RESP)
           END-EXEC
           MOVE WS-RESP TO WS-D2
           IF LS-TEC(1:1) = X'40' AND LS-TEC(3:1) = X'80'
               MOVE 'POSTED' TO WS-AFT
           END-IF
           EXEC CICS CANCEL REQID('GTPOSTW') RESP(WS-RESP)
           END-EXEC
           MOVE WS-RESP TO WS-D3
           STRING 'W POST=' WS-D1 ' ' WS-BEF ' WAIT=' WS-D2 ' '
                  WS-AFT ' CANCEL=' WS-D3
               DELIMITED BY SIZE INTO WS-LINE WITH POINTER WS-LPTR.
       WAIT-NULL.
           SET WS-NPTR TO NULL
           EXEC CICS WAIT EVENT ECADDR(WS-NPTR) RESP(WS-RESP)
                     RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO WS-D1
           MOVE WS-RESP2 TO WS-D2
           STRING 'N WAIT=' WS-D1 ' R2=' WS-D2
               DELIMITED BY SIZE INTO WS-LINE WITH POINTER WS-LPTR.
       POST-PAST.
           EXEC CICS POST TIME(090000) REQID('GTPOSTP')
                     SET(WS-PTR) RESP(WS-RESP)
           END-EXEC
           MOVE WS-RESP TO WS-D1
           STRING 'P POST=' WS-D1
               DELIMITED BY SIZE INTO WS-LINE WITH POINTER WS-LPTR.
       CONVERSE-REPLY.
           EXEC CICS CONVERSE FROM(WS-PROMPT) FROMLENGTH(8)
                     INTO(WS-REPLY) TOLENGTH(WS-TOLEN)
                     RESP(WS-RESP)
           END-EXEC
           MOVE WS-RESP TO WS-D1
           MOVE WS-TOLEN TO WS-TOLEN-D
           STRING WS-HEAD(6:1) ' CONV=' WS-D1 ' TOLEN=' WS-TOLEN-D
                  ' ' WS-REPLY
               DELIMITED BY SIZE INTO WS-LINE WITH POINTER WS-LPTR.
