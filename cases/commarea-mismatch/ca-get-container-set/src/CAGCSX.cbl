       IDENTIFICATION DIVISION.
       PROGRAM-ID. CAGCSX.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-get-container-set       *
      * Original program (Apache-2.0).                                *
      * GET CONTAINER SET(ptr) FLENGTH(len) that fails: a container   *
      * that does not exist (CONTAINERERR) and a channel that does    *
      * not exist (CHANNELERR). The pointer and FLENGTH are not read  *
      * after a failure. A good GET SET follows, to show the channel  *
      * is unchanged. Each result is a record in TS queue GCLOG.      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CHAN               PIC X(16) VALUE 'GCCHAN'.
       01  WS-NONE               PIC X(16) VALUE 'GCNONE'.
       01  WS-SRC                PIC X(20) VALUE 'ZYXWVUTSRQPONMLKJIHG'.
       01  WS-PTR                POINTER.
       01  WS-LEN                PIC S9(8) COMP.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY GCLOG.
       LINKAGE SECTION.
       01  LS-VIEW               PIC X(20).
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
           EXEC CICS PUT CONTAINER('DATA') CHANNEL(WS-CHAN)
                     FROM(WS-SRC) BIT
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT1' TO LG-TAG
           PERFORM LOG-RESP
      * No container of this name in the channel.
           EXEC CICS GET CONTAINER('NOSUCH') CHANNEL(WS-CHAN)
                     SET(WS-PTR) FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'CE01' TO LG-TAG
           PERFORM LOG-RESP
      * No channel of this name.
           EXEC CICS GET CONTAINER('DATA') CHANNEL(WS-NONE)
                     SET(WS-PTR) FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'CE02' TO LG-TAG
           PERFORM LOG-RESP
      * The container is still there and still readable.
           MOVE 55 TO WS-LEN
           EXEC CICS GET CONTAINER('DATA') CHANNEL(WS-CHAN)
                     SET(WS-PTR) FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           SET ADDRESS OF LS-VIEW TO WS-PTR
           MOVE 'OK01' TO LG-TAG
           MOVE WS-LEN TO LG-LEN
           MOVE LS-VIEW(1:16) TO LG-DATA
           PERFORM LOG-RESP
           EXEC CICS RETURN END-EXEC.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           EXEC CICS WRITEQ TS QUEUE('GCLOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
