       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARCST.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-receive-retrieve-set    *
      * Original program (Apache-2.0).                                *
      * RECEIVE SET into a POINTER variable, a LINKAGE view laid over *
      * the data CICS received, then (by the mode letter after the    *
      * transaction id) a START of CA0E with or without FROM data.    *
      *   S  no START                                                 *
      *   E  START INTERVAL(0) FROM 20 bytes                          *
      *   N  START INTERVAL(0), no FROM                               *
      * Each result is a record in TS queue RSLOG.                    *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PTR                POINTER.
       01  WS-LEN                PIC S9(4) COMP VALUE 0.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-MSG                PIC X(20) VALUE 'ORDER 0003 READY'.
           COPY RSLOG.
       LINKAGE SECTION.
       01  LS-IN                 PIC X(80).
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
           EXEC CICS RECEIVE SET(WS-PTR) LENGTH(WS-LEN)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'RC01' TO LG-TAG
           MOVE WS-RESP TO LG-RESP
           IF WS-RESP = 0
               SET ADDRESS OF LS-IN TO WS-PTR
               MOVE WS-LEN TO LG-LEN
      * Only the WS-LEN bytes CICS received are read.
               MOVE LS-IN(1:WS-LEN) TO LG-DATA
               MOVE LS-IN(6:1) TO WS-MODE
           END-IF
           EXEC CICS WRITEQ TS QUEUE('RSLOG') FROM(WS-LOG) END-EXEC
           EVALUATE WS-MODE
               WHEN 'E'
                   EXEC CICS START TRANSID('CA0E') INTERVAL(0)
                             FROM(WS-MSG) LENGTH(20)
                   END-EXEC
               WHEN 'N'
                   EXEC CICS START TRANSID('CA0E') INTERVAL(0)
                   END-EXEC
           END-EVALUATE
           EXEC CICS RETURN END-EXEC.
