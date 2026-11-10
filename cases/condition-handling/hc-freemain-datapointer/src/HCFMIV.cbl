       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCFMIV.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-freemain-datapointer   *
      * Original program (Apache-2.0).                                *
      * FREEMAIN DATAPOINTER of an address GETMAIN never returned     *
      * (the address of one of the program's own WORKING-STORAGE      *
      * items): INVREQ RESP2 1, the item untouched, and a GETMAIN and *
      * FREEMAIN after it work as before. GETMAIN and FREEMAIN are    *
      * not events, so each step writes a breadcrumb to TS queue      *
      * FMLOG.                                                        *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PWS                POINTER.
       01  WS-PGM                POINTER.
       01  WS-KEEP               PIC X(8)  VALUE 'KEEPME!!'.
       01  WS-FILL               PIC X     VALUE 'Q'.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY FMLOG.
       LINKAGE SECTION.
       01  LS-AREA               PIC X(8).
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
      * The address of a WORKING-STORAGE item is not storage that a
      * GETMAIN acquired.
           SET WS-PWS TO ADDRESS OF WS-KEEP
           EXEC CICS FREEMAIN DATAPOINTER(WS-PWS)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'IV01' TO LG-TAG
           PERFORM LOG-RESP
           MOVE 'IV02' TO LG-TAG
           MOVE WS-KEEP TO LG-DATA
           MOVE 0 TO WS-RESP WS-RESP2
           PERFORM LOG-RESP
      * A GETMAIN and its FREEMAIN afterwards are unaffected.
           EXEC CICS GETMAIN SET(WS-PGM) FLENGTH(8)
                     INITIMG(WS-FILL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GM01' TO LG-TAG
           PERFORM LOG-RESP
           SET ADDRESS OF LS-AREA TO WS-PGM
           MOVE 'VW01' TO LG-TAG
           MOVE LS-AREA TO LG-DATA
           PERFORM LOG-RESP
           EXEC CICS FREEMAIN DATAPOINTER(WS-PGM)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'FR01' TO LG-TAG
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
