       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCPGMI.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-handle-pgmiderr        *
      * Original program (Apache-2.0).                                *
      * LINK or XCTL to HCGONE, a program with no CSD definition      *
      * (program autoinstall is off), so the command raises PGMIDERR. *
      *   HP01  HANDLE CONDITION PGMIDERR(NO-PROG), then LINK         *
      *   HP02  HANDLE CONDITION PGMIDERR(NO-PROG), then XCTL         *
      *   HP03  no handler, no RESP: LINK, the default action         *
      *   HP04  the handler is set but the LINK target is defined     *
      * The outcome goes to the screen with SEND TEXT.                *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TRAN               PIC X(4) VALUE SPACES.
       01  WS-OUT                PIC X(16) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE EIBTRNID TO WS-TRAN
           EVALUATE WS-TRAN
               WHEN 'HP01'
                   EXEC CICS HANDLE CONDITION PGMIDERR(NO-PROG)
                   END-EXEC
                   EXEC CICS LINK PROGRAM('HCGONE') END-EXEC
                   MOVE 'LINK RETURNED' TO WS-OUT
               WHEN 'HP02'
                   EXEC CICS HANDLE CONDITION PGMIDERR(NO-PROG)
                   END-EXEC
                   EXEC CICS XCTL PROGRAM('HCGONE') END-EXEC
                   MOVE 'XCTL RETURNED' TO WS-OUT
               WHEN 'HP04'
                   EXEC CICS HANDLE CONDITION PGMIDERR(NO-PROG)
                   END-EXEC
                   EXEC CICS LINK PROGRAM('HCPGMT') END-EXEC
                   MOVE 'LINK RETURNED' TO WS-OUT
               WHEN OTHER
                   EXEC CICS LINK PROGRAM('HCGONE') END-EXEC
                   MOVE 'LINK RETURNED' TO WS-OUT
           END-EVALUATE
           PERFORM SHOW-OUT.
       NO-PROG.
           MOVE 'AT LABEL' TO WS-OUT.
       SHOW-OUT.
           EXEC CICS SEND TEXT FROM(WS-OUT) LENGTH(16) ERASE END-EXEC
           EXEC CICS RETURN END-EXEC.
