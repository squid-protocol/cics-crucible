       IDENTIFICATION DIVISION.
       PROGRAM-ID. CAGMPT.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-getmain-pointer         *
      * Original program (Apache-2.0).                                *
      * GETMAIN SET(ptr) FLENGTH INITIMG, a view of the storage with  *
      * SET ADDRESS OF, a second view reached by adding to the        *
      * pointer through a binary REDEFINES, a third view from the     *
      * ADDRESS OF a subordinate item, then FREEMAIN. GETMAIN and     *
      * FREEMAIN are not events, so each step writes a breadcrumb to  *
      * TS queue GMLOG.                                               *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PTR                POINTER.
       01  WS-PTR2              POINTER.
       01  WS-PTR2-N REDEFINES WS-PTR2 PIC S9(8) COMP.
       01  WS-PSUB               POINTER.
       01  WS-FILL               PIC X     VALUE 'Z'.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY GMLOG.
       LINKAGE SECTION.
       01  LS-AREA.
           05  LS-HEAD           PIC X(4).
           05  LS-BODY           PIC X(12).
       01  LS-TAIL               PIC X(12).
       01  LS-SUB                PIC X(12).
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
           EXEC CICS GETMAIN SET(WS-PTR) FLENGTH(16)
                     INITIMG(WS-FILL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GM01' TO LG-TAG
           PERFORM LOG-RESP
      * View the 16 bytes: every byte is the INITIMG value.
           SET ADDRESS OF LS-AREA TO WS-PTR
           MOVE 'GM02' TO LG-TAG
           MOVE LS-AREA TO LG-DATA
           PERFORM LOG-RESP
      * Write through the view.
           MOVE 'HEAD' TO LS-HEAD
           MOVE 'ABCDEFGHIJKL' TO LS-BODY
           MOVE 'GM03' TO LG-TAG
           MOVE LS-AREA TO LG-DATA
           PERFORM LOG-RESP
      * Pointer arithmetic: the pointer plus 4 is the address of
      * the byte after LS-HEAD.
           SET WS-PTR2 TO WS-PTR
           ADD 4 TO WS-PTR2-N
           SET ADDRESS OF LS-TAIL TO WS-PTR2
           MOVE 'GM04' TO LG-TAG
           MOVE LS-TAIL TO LG-DATA
           PERFORM LOG-RESP
      * ADDRESS OF a subordinate item of the based area.
           SET WS-PSUB TO ADDRESS OF LS-BODY
           SET ADDRESS OF LS-SUB TO WS-PSUB
           MOVE 'GM05' TO LG-TAG
           MOVE LS-SUB TO LG-DATA
           PERFORM LOG-RESP
           MOVE 'GM06' TO LG-TAG
           MOVE 'EQ=N NEBASE=N' TO LG-DATA
           IF WS-PSUB = WS-PTR2
               MOVE 'Y' TO LG-DATA(4:1)
           END-IF
           IF WS-PSUB NOT = WS-PTR
               MOVE 'Y' TO LG-DATA(13:1)
           END-IF
           PERFORM LOG-RESP
      * A write through the third view shows in the first.
           MOVE 'MNOPQRSTUVWX' TO LS-SUB
           MOVE 'GM07' TO LG-TAG
           MOVE LS-AREA TO LG-DATA
           PERFORM LOG-RESP
      * Release the storage GETMAIN obtained.
           EXEC CICS FREEMAIN DATA(LS-AREA)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'FM01' TO LG-TAG
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
           EXEC CICS WRITEQ TS QUEUE('GMLOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
