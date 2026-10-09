       IDENTIFICATION DIVISION.
       PROGRAM-ID. PCIMMS.
      *---------------------------------------------------------------*
      * cics-crucible  pseudo-conversational / pc-return-immediate    *
      * Original program (Apache-2.0).                                *
      * PC54, started with no terminal: RETURN IMMEDIATE has no       *
      * terminal to attach the next transaction to.                   *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-SLOG.
           05  FILLER            PIC X(3)  VALUE 'S1 '.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  SLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' 2='.
           05  SLOG-RESP2        PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RETURN TRANSID('PC52') IMMEDIATE
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO SLOG-RESP
           MOVE WS-RESP2 TO SLOG-RESP2
           EXEC CICS WRITEQ TS QUEUE('PCLOG') FROM(WS-SLOG)
                     LENGTH(13)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
