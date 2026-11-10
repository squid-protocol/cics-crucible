       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCFPAR.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-fetch-child            *
      * Original program (Apache-2.0).                                *
      * HCFT reads its mode from the terminal input (HCFT N,A,Y,B,F) *
      * and logs one 24-byte record per FETCH or FREE to TS HCFLOG:  *
      *   R=rrr/sss C=c A=aaaa T=t  (RESP, RESP2, COMPSTATUS N or A,  *
      *   ABCODE, token match)                                        *
      *   N  RUN HCFD CHILD, FETCH CHILD (the child ends normally)    *
      *   A  RUN HCFE CHILD, FETCH CHILD (the child abends HCFX)      *
      *   Y  RUN HCFD CHILD, FETCH ANY twice                          *
      *   B  FETCH ANY with no children, FETCH CHILD of a token that  *
      *      was never issued                                         *
      *   F  RUN HCFD CHILD, DELAY, FREE CHILD twice, FETCH CHILD     *
      *---------------------------------------------------------------*
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
      * IBM's numeric CVDA values for COMPSTATUS (CVDA list): NORMAL
      * 1016, ABEND 900.
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
               WHEN 'N'
                   EXEC CICS RUN TRANSID('HCFD') CHILD(WS-TOK)
                   END-EXEC
                   EXEC CICS FETCH CHILD(WS-TOK) COMPSTATUS(WS-CS)
                             ABCODE(WS-AB) RESP(WS-RESP)
                             RESP2(WS-RESP2)
                   END-EXEC
                   PERFORM LOG-FETCH
               WHEN 'A'
                   EXEC CICS RUN TRANSID('HCFE') CHILD(WS-TOK)
                   END-EXEC
                   EXEC CICS FETCH CHILD(WS-TOK) COMPSTATUS(WS-CS)
                             ABCODE(WS-AB) RESP(WS-RESP)
                             RESP2(WS-RESP2)
                   END-EXEC
                   PERFORM LOG-FETCH
               WHEN 'Y'
                   EXEC CICS RUN TRANSID('HCFD') CHILD(WS-TOK)
                   END-EXEC
                   EXEC CICS FETCH ANY(WS-TOK2) COMPSTATUS(WS-CS)
                             ABCODE(WS-AB) RESP(WS-RESP)
                             RESP2(WS-RESP2)
                   END-EXEC
                   IF WS-TOK2 = WS-TOK
                       MOVE 'Y' TO WS-TM
                   ELSE
                       MOVE 'N' TO WS-TM
                   END-IF
                   PERFORM LOG-FETCH
                   MOVE 0 TO WS-CS
                   MOVE SPACES TO WS-AB
                   EXEC CICS FETCH ANY(WS-TOK2) COMPSTATUS(WS-CS)
                             ABCODE(WS-AB) RESP(WS-RESP)
                             RESP2(WS-RESP2)
                   END-EXEC
                   PERFORM LOG-FETCH
               WHEN 'B'
                   EXEC CICS FETCH ANY(WS-TOK2) COMPSTATUS(WS-CS)
                             ABCODE(WS-AB) RESP(WS-RESP)
                             RESP2(WS-RESP2)
                   END-EXEC
                   PERFORM LOG-FETCH
                   EXEC CICS FETCH CHILD(WS-TOK) COMPSTATUS(WS-CS)
                             ABCODE(WS-AB) RESP(WS-RESP)
                             RESP2(WS-RESP2)
                   END-EXEC
                   PERFORM LOG-FETCH
               WHEN 'F'
                   EXEC CICS RUN TRANSID('HCFD') CHILD(WS-TOK)
                   END-EXEC
                   EXEC CICS DELAY INTERVAL(1) END-EXEC
                   EXEC CICS FREE CHILD(WS-TOK) RESP(WS-RESP)
                             RESP2(WS-RESP2)
                   END-EXEC
                   PERFORM LOG-FETCH
                   EXEC CICS FREE CHILD(WS-TOK) RESP(WS-RESP)
                             RESP2(WS-RESP2)
                   END-EXEC
                   PERFORM LOG-FETCH
                   EXEC CICS FETCH CHILD(WS-TOK) COMPSTATUS(WS-CS)
                             ABCODE(WS-AB) RESP(WS-RESP)
                             RESP2(WS-RESP2)
                   END-EXEC
                   PERFORM LOG-FETCH
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(4) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
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
           PERFORM LOG-WRITE.
       LOG-WRITE.
           MOVE WS-RESP TO REC-RESP
           MOVE WS-RESP2 TO REC-RESP2
           EXEC CICS WRITEQ TS QUEUE('HCFLOG') FROM(WS-REC)
                     LENGTH(24)
           END-EXEC.
