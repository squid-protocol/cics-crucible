       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCRQTD.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-readq-td               *
      * Original program (Apache-2.0).                                *
      * HC82, a mode typed after the transid:                         *
      *   F  FIFO: WRITEQ TD three items (5, 7 and 8 bytes), READQ    *
      *      TD them back into an 8-byte area, then once more         *
      *   S  a queue seeded with one item: WRITEQ TD one more, READQ  *
      *      TD both in order, READQ TD again                         *
      *   E  READQ TD of an empty queue, INTO pre-filled              *
      *   U  READQ / WRITEQ / DELETEQ TD of a queue the CSD does not  *
      *      define                                                   *
      *   D  WRITEQ TD three items, DELETEQ TD, READQ TD              *
      *   L  READQ TD into a 4-byte area an 8-byte item does not fit  *
      * Every command uses RESP, so a condition never abends the task *
      * and each command is one event in the log.                     *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-Q                  PIC X(4)  VALUE 'HCQ1'.
       01  WS-QN                 PIC X(4)  VALUE 'HCNQ'.
       01  WS-AREA               PIC X(8)  VALUE 'XXXXXXXX'.
       01  WS-SMALL              PIC X(4)  VALUE 'XXXX'.
       01  WS-LEN                PIC S9(4) COMP VALUE 8.
       01  WS-SLEN               PIC S9(4) COMP VALUE 4.
       01  WS-I1                 PIC X(5)  VALUE 'ALPHA'.
       01  WS-I2                 PIC X(7)  VALUE 'BRAVO77'.
       01  WS-I3                 PIC X(8)  VALUE 'EIGHTCHR'.
       01  WS-I4                 PIC X(8)  VALUE 'LONGITEM'.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'F'
                   PERFORM FIFO-PARA
               WHEN 'S'
                   PERFORM SEED-PARA
               WHEN 'E'
                   PERFORM EMPTY-PARA
               WHEN 'U'
                   PERFORM UNDEF-PARA
               WHEN 'D'
                   PERFORM DELETE-PARA
               WHEN 'L'
                   PERFORM LENGERR-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       FIFO-PARA.
           PERFORM WRITE-THREE
           PERFORM READ-ONE
           PERFORM READ-ONE
           PERFORM READ-ONE
           PERFORM READ-ONE.
       SEED-PARA.
           EXEC CICS WRITEQ TD QUEUE(WS-Q) FROM(WS-I2) LENGTH(7)
                     RESP(WS-RESP)
           END-EXEC
           PERFORM READ-ONE
           PERFORM READ-ONE
           PERFORM READ-ONE.
       EMPTY-PARA.
           PERFORM READ-ONE.
       UNDEF-PARA.
           MOVE 8 TO WS-LEN
           EXEC CICS READQ TD QUEUE(WS-QN) INTO(WS-AREA)
                     LENGTH(WS-LEN) RESP(WS-RESP)
           END-EXEC
           EXEC CICS WRITEQ TD QUEUE(WS-QN) FROM(WS-I1) LENGTH(5)
                     RESP(WS-RESP)
           END-EXEC
           EXEC CICS DELETEQ TD QUEUE(WS-QN) RESP(WS-RESP)
           END-EXEC.
       DELETE-PARA.
           PERFORM WRITE-THREE
           EXEC CICS DELETEQ TD QUEUE(WS-Q) RESP(WS-RESP)
           END-EXEC
           PERFORM READ-ONE.
       LENGERR-PARA.
           EXEC CICS WRITEQ TD QUEUE(WS-Q) FROM(WS-I4) LENGTH(8)
                     RESP(WS-RESP)
           END-EXEC
           EXEC CICS READQ TD QUEUE(WS-Q) INTO(WS-SMALL)
                     LENGTH(WS-SLEN) RESP(WS-RESP)
           END-EXEC.
       WRITE-THREE.
           EXEC CICS WRITEQ TD QUEUE(WS-Q) FROM(WS-I1) LENGTH(5)
                     RESP(WS-RESP)
           END-EXEC
           EXEC CICS WRITEQ TD QUEUE(WS-Q) FROM(WS-I2) LENGTH(7)
                     RESP(WS-RESP)
           END-EXEC
           EXEC CICS WRITEQ TD QUEUE(WS-Q) FROM(WS-I3) LENGTH(8)
                     RESP(WS-RESP)
           END-EXEC.
       READ-ONE.
           MOVE 8 TO WS-LEN
           EXEC CICS READQ TD QUEUE(WS-Q) INTO(WS-AREA)
                     LENGTH(WS-LEN) RESP(WS-RESP)
           END-EXEC.
