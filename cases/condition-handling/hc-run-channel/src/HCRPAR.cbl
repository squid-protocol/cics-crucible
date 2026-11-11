       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCRPAR.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-run-channel            *
      * Original program (Apache-2.0).                                *
      * HCRP reads its mode from the terminal input (HCRP C, N, B):   *
      *   C  PUT CONTAINER PAYLOAD on channel HCRCHAN, RUN TRANSID    *
      *      HCRD CHANNEL(HCRCHAN), then PUT PAYLOAD again (the child *
      *      was given a copy when the RUN was issued), FETCH CHILD,  *
      *      and read PAYLOAD back from the parent's own channel      *
      *   N  RUN TRANSID HCRD CHANNEL(HCRNEW), a channel that does    *
      *      not exist: CICS creates it, empty                        *
      *   B  RUN TRANSID HCRD CHANNEL('BAD*NAME'): a name with a      *
      *      character IBM does not accept                            *
      * The parent logs 45-byte records (copybook HCRLOG) to TS      *
      * queue HCRLOG; the child logs to HCRCLOG.                      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-CHAN               PIC X(16) VALUE 'HCRCHAN'.
       01  WS-NEW                PIC X(16) VALUE 'HCRNEW'.
       01  WS-BAD                PIC X(16) VALUE 'BAD*NAME'.
       01  WS-V1                 PIC X(10) VALUE 'ORDER-0042'.
       01  WS-V2                 PIC X(10) VALUE 'CHANGED-01'.
       01  WS-TOK                PIC X(16) VALUE LOW-VALUES.
       01  WS-CS                 PIC S9(8) COMP VALUE 0.
       01  WS-AB                 PIC X(4)  VALUE SPACES.
       01  WS-AREA               PIC X(16) VALUE SPACES.
       01  WS-LEN                PIC S9(8) COMP VALUE 0.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(4)  VALUE 'DONE'.
           COPY HCRLOG.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'C'
                   EXEC CICS PUT CONTAINER('PAYLOAD') CHANNEL(WS-CHAN)
                             FROM(WS-V1) CHAR
                   END-EXEC
                   EXEC CICS RUN TRANSID('HCRD') CHILD(WS-TOK)
                             CHANNEL(WS-CHAN)
                   END-EXEC
                   EXEC CICS PUT CONTAINER('PAYLOAD') CHANNEL(WS-CHAN)
                             FROM(WS-V2) CHAR
                   END-EXEC
                   EXEC CICS FETCH CHILD(WS-TOK) COMPSTATUS(WS-CS)
                             ABCODE(WS-AB)
                   END-EXEC
                   MOVE 16 TO WS-LEN
                   EXEC CICS GET CONTAINER('PAYLOAD') CHANNEL(WS-CHAN)
                             INTO(WS-AREA) FLENGTH(WS-LEN)
                             RESP(WS-RESP) RESP2(WS-RESP2)
                   END-EXEC
                   MOVE WS-CHAN TO LG-CHAN
                   MOVE WS-LEN TO LG-LEN
                   MOVE WS-AREA TO LG-DATA
                   PERFORM LOG-WRITE
               WHEN 'N'
                   EXEC CICS RUN TRANSID('HCRD') CHILD(WS-TOK)
                             CHANNEL(WS-NEW)
                   END-EXEC
                   EXEC CICS FETCH CHILD(WS-TOK) COMPSTATUS(WS-CS)
                             ABCODE(WS-AB)
                   END-EXEC
               WHEN 'B'
                   EXEC CICS RUN TRANSID('HCRD') CHILD(WS-TOK)
                             CHANNEL(WS-BAD) RESP(WS-RESP)
                             RESP2(WS-RESP2)
                   END-EXEC
                   MOVE WS-BAD TO LG-CHAN
                   MOVE 0 TO LG-LEN
                   MOVE SPACES TO LG-DATA
                   PERFORM LOG-WRITE
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(4) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       LOG-WRITE.
           MOVE 'P ' TO LG-WHO
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           EXEC CICS WRITEQ TS QUEUE('HCRLOG') FROM(WS-REC)
           END-EXEC.
