       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCRCHD.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-run-channel            *
      * Original program (Apache-2.0).                                *
      * HCRD, a RUN TRANSID child of HCRPAR: logs its current channel *
      * (ASSIGN CHANNEL) and what GET CONTAINER PAYLOAD returns on it *
      * to TS HCRCLOG, then returns.                                  *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CUR                PIC X(16) VALUE SPACES.
       01  WS-AREA               PIC X(16) VALUE SPACES.
       01  WS-LEN                PIC S9(8) COMP VALUE 0.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
           COPY HCRLOG.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS ASSIGN CHANNEL(WS-CUR) END-EXEC
           MOVE 16 TO WS-LEN
           EXEC CICS GET CONTAINER('PAYLOAD') INTO(WS-AREA)
                     FLENGTH(WS-LEN) RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'C ' TO LG-WHO
           MOVE WS-CUR TO LG-CHAN
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           IF WS-RESP = 0
               MOVE WS-LEN TO LG-LEN
               MOVE WS-AREA TO LG-DATA
           ELSE
               MOVE 0 TO LG-LEN
               MOVE SPACES TO LG-DATA
           END-IF
           EXEC CICS WRITEQ TS QUEUE('HCRCLOG') FROM(WS-REC)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
