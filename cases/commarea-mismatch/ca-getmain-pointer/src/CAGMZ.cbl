       IDENTIFICATION DIVISION.
       PROGRAM-ID. CAGMZ.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-getmain-pointer         *
      * Original program (Apache-2.0).                                *
      * GETMAIN with a length below 1: FLENGTH 0, FLENGTH -1 and      *
      * LENGTH 0 each raise LENGERR and leave the pointer zero. The   *
      * pointer starts non-zero each time. A valid GETMAIN then       *
      * works and is freed. Results go to TS queue GMLOG.             *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PTR                POINTER.
       01  WS-PTR2              POINTER.
       01  WS-PTR2-N REDEFINES WS-PTR2 PIC S9(8) COMP.
       01  WS-DUMMY              PIC X.
       01  WS-FILL               PIC X     VALUE 'Q'.
       01  WS-FLEN               PIC S9(8) COMP.
       01  WS-HLEN               PIC S9(4) COMP.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY GMLOG.
       LINKAGE SECTION.
       01  LS-CHK                PIC X(8).
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
           SET WS-PTR TO ADDRESS OF WS-DUMMY
           MOVE 'PRE0' TO LG-TAG
           PERFORM LOG-ZERO
      * FLENGTH 0.
           MOVE 0 TO WS-FLEN
           EXEC CICS GETMAIN SET(WS-PTR) FLENGTH(WS-FLEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GMF0' TO LG-TAG
           PERFORM LOG-ZERO
      * FLENGTH -1.
           SET WS-PTR TO ADDRESS OF WS-DUMMY
           MOVE -1 TO WS-FLEN
           EXEC CICS GETMAIN SET(WS-PTR) FLENGTH(WS-FLEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GMFN' TO LG-TAG
           PERFORM LOG-ZERO
      * LENGTH 0.
           SET WS-PTR TO ADDRESS OF WS-DUMMY
           MOVE 0 TO WS-HLEN
           EXEC CICS GETMAIN SET(WS-PTR) LENGTH(WS-HLEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GML0' TO LG-TAG
           PERFORM LOG-ZERO
      * A valid request after the failures.
           SET WS-PTR TO ADDRESS OF WS-DUMMY
           MOVE 8 TO WS-FLEN
           EXEC CICS GETMAIN SET(WS-PTR) FLENGTH(WS-FLEN)
                     INITIMG(WS-FILL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GMOK' TO LG-TAG
           PERFORM LOG-ZERO
           SET ADDRESS OF LS-CHK TO WS-PTR
           MOVE 'VIEW' TO LG-TAG
           MOVE LS-CHK TO LG-DATA
           PERFORM LOG-RESP
           EXEC CICS FREEMAIN DATA(LS-CHK)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'FMOK' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS RETURN END-EXEC.
      * Whether the pointer is zero goes in the data, then the codes.
       LOG-ZERO.
           SET WS-PTR2 TO WS-PTR
           IF WS-PTR2-N = 0
               MOVE 'ZERO=Y' TO LG-DATA
           ELSE
               MOVE 'ZERO=N' TO LG-DATA
           END-IF
           PERFORM LOG-RESP.
       LOG-RESP.
           IF WS-RESP = 0
               MOVE 0 TO LG-RESP
               MOVE 0 TO LG-RESP2
           ELSE
               MOVE WS-RESP TO LG-RESP
               MOVE WS-RESP2 TO LG-RESP2
           END-IF
           EXEC CICS WRITEQ TS QUEUE('GMLOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
