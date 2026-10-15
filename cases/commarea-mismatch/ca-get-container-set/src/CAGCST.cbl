       IDENTIFICATION DIVISION.
       PROGRAM-ID. CAGCST.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-get-container-set       *
      * Original program (Apache-2.0).                                *
      * GET CONTAINER SET(ptr) FLENGTH(len): the pointer CICS returns *
      * for a BIT container, a LINKAGE view laid over it, FLENGTH as  *
      * an output-only field (preset to junk), a second GET SET of    *
      * the same container, then a PUT that replaces the container.   *
      * The pointer from before the PUT is never read again; a fresh  *
      * GET SET gives the view of the new data. Each result is a      *
      * record in TS queue GCLOG.                                     *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CHAN               PIC X(16) VALUE 'GCCHAN'.
       01  WS-SRC                PIC X(20) VALUE 'ABCDEFGHIJKLMNOPQRST'.
       01  WS-SRC2               PIC X(8)  VALUE 'uvwxyz12'.
       01  WS-PTR                POINTER.
       01  WS-LEN                PIC S9(8) COMP.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY GCLOG.
       LINKAGE SECTION.
       01  LS-VIEW               PIC X(20).
       01  LS-VIEW2              PIC X(8).
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
           EXEC CICS PUT CONTAINER('DATA') CHANNEL(WS-CHAN)
                     FROM(WS-SRC) BIT
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT1' TO LG-TAG
           PERFORM LOG-RESP
      * FLENGTH is output only with SET: the junk 99 is replaced.
           MOVE 99 TO WS-LEN
           EXEC CICS GET CONTAINER('DATA') CHANNEL(WS-CHAN)
                     SET(WS-PTR) FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           SET ADDRESS OF LS-VIEW TO WS-PTR
           MOVE 'GET1' TO LG-TAG
           MOVE WS-LEN TO LG-LEN
           MOVE LS-VIEW(1:16) TO LG-DATA
           PERFORM LOG-RESP
      * The view covers all FLENGTH bytes: read the last 16.
           MOVE 'GET2' TO LG-TAG
           MOVE WS-LEN TO LG-LEN
           MOVE LS-VIEW(5:16) TO LG-DATA
           PERFORM LOG-RESP
      * A second GET SET of the same container: a new pointer.
           MOVE 99 TO WS-LEN
           EXEC CICS GET CONTAINER('DATA') CHANNEL(WS-CHAN)
                     SET(WS-PTR) FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           SET ADDRESS OF LS-VIEW TO WS-PTR
           MOVE 'GET3' TO LG-TAG
           MOVE WS-LEN TO LG-LEN
           MOVE LS-VIEW(1:16) TO LG-DATA
           PERFORM LOG-RESP
      * Replace the container. No view from before this PUT is read.
           EXEC CICS PUT CONTAINER('DATA') CHANNEL(WS-CHAN)
                     FROM(WS-SRC2) BIT
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT2' TO LG-TAG
           PERFORM LOG-RESP
           MOVE 77 TO WS-LEN
           EXEC CICS GET CONTAINER('DATA') CHANNEL(WS-CHAN)
                     SET(WS-PTR) FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           SET ADDRESS OF LS-VIEW2 TO WS-PTR
           MOVE 'GET4' TO LG-TAG
           MOVE WS-LEN TO LG-LEN
           MOVE LS-VIEW2 TO LG-DATA
           PERFORM LOG-RESP
           EXEC CICS RETURN END-EXEC.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           EXEC CICS WRITEQ TS QUEUE('GCLOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
