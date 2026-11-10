       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCFMRL.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-freemain-datapointer   *
      * Original program (Apache-2.0).                                *
      * Two GETMAIN blocks, each viewed with SET ADDRESS OF; the      *
      * first is released with FREEMAIN DATAPOINTER(pointer), and the *
      * second must be untouched by that and still usable until it is *
      * released the same way. GETMAIN and FREEMAIN are not events,   *
      * so each step writes a breadcrumb to TS queue FMLOG.           *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-P1                 POINTER.
       01  WS-P2                 POINTER.
       01  WS-FILL-A             PIC X     VALUE 'A'.
       01  WS-FILL-B             PIC X     VALUE 'B'.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY FMLOG.
       LINKAGE SECTION.
       01  LS-FIRST              PIC X(8).
       01  LS-SECOND             PIC X(8).
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
           EXEC CICS GETMAIN SET(WS-P1) FLENGTH(8)
                     INITIMG(WS-FILL-A)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GM01' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS GETMAIN SET(WS-P2) FLENGTH(8)
                     INITIMG(WS-FILL-B)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GM02' TO LG-TAG
           PERFORM LOG-RESP
           SET ADDRESS OF LS-FIRST TO WS-P1
           SET ADDRESS OF LS-SECOND TO WS-P2
      * Write through the first view; the second block is untouched.
           MOVE 'FIRST-01' TO LS-FIRST
           MOVE 'VW01' TO LG-TAG
           MOVE LS-FIRST TO LG-DATA
           PERFORM LOG-RESP
           MOVE 'VW02' TO LG-TAG
           MOVE LS-SECOND TO LG-DATA
           PERFORM LOG-RESP
      * Release the first block by its pointer.
           EXEC CICS FREEMAIN DATAPOINTER(WS-P1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'FR01' TO LG-TAG
           PERFORM LOG-RESP
      * The second block is still the program's: write and read it.
           MOVE 'LATER-02' TO LS-SECOND
           MOVE 'VW03' TO LG-TAG
           MOVE LS-SECOND TO LG-DATA
           PERFORM LOG-RESP
           EXEC CICS FREEMAIN DATAPOINTER(WS-P2)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'FR02' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS RETURN END-EXEC.
      * RESP2 is logged only when the command raised a condition.
       LOG-RESP.
           IF WS-RESP = 0
               MOVE 0 TO LG-RESP
               MOVE 0 TO LG-RESP2
           ELSE
               MOVE WS-RESP TO LG-RESP
               MOVE WS-RESP2 TO LG-RESP2
           END-IF
           EXEC CICS WRITEQ TS QUEUE('FMLOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
