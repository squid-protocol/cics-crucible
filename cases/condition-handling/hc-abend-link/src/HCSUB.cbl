       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCSUB.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-abend-link             *
      * Original program (Apache-2.0).                                *
      * LINKed from HCMAIN. It sets no HANDLE CONDITION of its own.   *
      * Mode N: RESP on a failing READQ. Mode Q: the same READQ       *
      * without RESP, so QIDERR's default action (abend AEYH) runs.   *
      * Mode A: its own HANDLE ABEND LABEL, an ABEND, and recovery by *
      * RETURN.                                                       *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-JUNK               PIC X(8)  VALUE SPACES.
       01  WS-JLEN               PIC S9(4) COMP VALUE 8.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-ABCODE             PIC X(4)  VALUE SPACES.
       LINKAGE SECTION.
       01  DFHCOMMAREA.
           COPY HCLINKCA.
       PROCEDURE DIVISION.
       SUB-MAIN.
           MOVE 's' TO CA-TRAIL(1:1)
           ADD 1 TO CA-COUNT
           EVALUATE CA-MODE
               WHEN 'Q'
                   EXEC CICS READQ TS QUEUE('HCNONE') INTO(WS-JUNK)
                             LENGTH(WS-JLEN) ITEM(1)
                   END-EXEC
                   MOVE 'x' TO CA-TRAIL(2:1)
               WHEN 'A'
                   EXEC CICS HANDLE ABEND LABEL(SUB-ABEND) END-EXEC
                   MOVE 'h' TO CA-TRAIL(2:1)
                   EXEC CICS ABEND ABCODE('HCX1') END-EXEC
                   MOVE 'x' TO CA-TRAIL(3:1)
               WHEN OTHER
                   EXEC CICS READQ TS QUEUE('HCNONE') INTO(WS-JUNK)
                             LENGTH(WS-JLEN) ITEM(1) RESP(WS-RESP)
                   END-EXEC
                   IF WS-RESP = DFHRESP(QIDERR)
                       MOVE 'QIDR' TO CA-RESULT
                   END-IF
                   MOVE 'n' TO CA-TRAIL(2:1)
           END-EVALUATE
           EXEC CICS RETURN END-EXEC.
       SUB-ABEND.
           EXEC CICS ASSIGN ABCODE(WS-ABCODE) END-EXEC
           MOVE WS-ABCODE TO CA-RESULT
           MOVE 'a' TO CA-TRAIL(3:1)
           EXEC CICS RETURN END-EXEC.
