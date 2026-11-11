       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCNSPR.
      * condition-handling / hc-fetch-nosuspend
      * Original code only (cics-crucible AGENTS.md rule 1).
      * HCNS reads its mode from the terminal input (HCNS C,A,N) and
      * logs one 24-byte record per FETCH to TS HCNLOG:
      *   R=rrr/sss C=c A=aaaa T=t
      *   (RESP, RESP2, COMPSTATUS N or A, ABCODE, token match)
      *   C  RUN HCNC, FETCH CHILD NOSUSPEND at once, DELAY 10,
      *      FETCH CHILD NOSUSPEND again
      *   A  the same with FETCH ANY NOSUSPEND, then a third one once
      *      the one child has been fetched
      *   N  FETCH ANY NOSUSPEND with no children
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-TOK                PIC X(16) VALUE LOW-VALUES.
       01  WS-TOK2               PIC X(16) VALUE LOW-VALUES.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-CS                 PIC S9(8) COMP VALUE 0.
       01  CV-NORMAL             PIC S9(8) COMP VALUE 1016.
       01  CV-ABEND              PIC S9(8) COMP VALUE 900.
       01  WS-AB                 PIC X(4)  VALUE SPACES.
       01  WS-TM                 PIC X     VALUE '-'.
       01  WS-DONE               PIC X(4)  VALUE 'DONE'.
       01  WS-REC.
           05  FILLER            PIC XX    VALUE 'R='.
           05  REC-RESP          PIC 999   VALUE 0.
           05  FILLER            PIC X     VALUE '/'.
           05  REC-RESP2         PIC 999   VALUE 0.
           05  FILLER            PIC XXX   VALUE ' C='.
           05  REC-CS            PIC X     VALUE '-'.
           05  FILLER            PIC XXX   VALUE ' A='.
           05  REC-AB            PIC X(4)  VALUE SPACES.
           05  FILLER            PIC XXX   VALUE ' T='.
           05  REC-TOK           PIC X     VALUE '-'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'C'
                   EXEC CICS RUN TRANSID('HCNC') CHILD(WS-TOK)
                   END-EXEC
                   PERFORM FETCH-CHILD-NOS
                   EXEC CICS DELAY INTERVAL(10) END-EXEC
                   PERFORM FETCH-CHILD-NOS
               WHEN 'A'
                   EXEC CICS RUN TRANSID('HCNC') CHILD(WS-TOK)
                   END-EXEC
                   PERFORM FETCH-ANY-NOS
                   EXEC CICS DELAY INTERVAL(10) END-EXEC
                   PERFORM FETCH-ANY-NOS
                   PERFORM FETCH-ANY-NOS
               WHEN 'N'
                   PERFORM FETCH-ANY-NOS
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(4) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       FETCH-CHILD-NOS.
           MOVE 0 TO WS-CS
           MOVE SPACES TO WS-AB
           EXEC CICS FETCH CHILD(WS-TOK) NOSUSPEND COMPSTATUS(WS-CS)
                     ABCODE(WS-AB) RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           PERFORM LOG-FETCH.
       FETCH-ANY-NOS.
           MOVE 0 TO WS-CS
           MOVE SPACES TO WS-AB
           MOVE LOW-VALUES TO WS-TOK2
           EXEC CICS FETCH ANY(WS-TOK2) NOSUSPEND COMPSTATUS(WS-CS)
                     ABCODE(WS-AB) RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-RESP = DFHRESP(NORMAL)
               IF WS-TOK2 = WS-TOK
                   MOVE 'Y' TO WS-TM
               ELSE
                   MOVE 'N' TO WS-TM
               END-IF
           END-IF
           PERFORM LOG-FETCH.
       LOG-FETCH.
           MOVE WS-TM TO REC-TOK
           MOVE '-' TO WS-TM
           MOVE '-' TO REC-CS
           MOVE SPACES TO REC-AB
           IF WS-RESP = DFHRESP(NORMAL)
               IF WS-CS = CV-NORMAL
                   MOVE 'N' TO REC-CS
               END-IF
               IF WS-CS = CV-ABEND
                   MOVE 'A' TO REC-CS
               END-IF
               MOVE WS-AB TO REC-AB
           END-IF
           MOVE WS-RESP TO REC-RESP
           MOVE WS-RESP2 TO REC-RESP2
           EXEC CICS WRITEQ TS QUEUE('HCNLOG') FROM(WS-REC)
                     LENGTH(24)
           END-EXEC.
