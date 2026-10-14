       IDENTIFICATION DIVISION.
       PROGRAM-ID. PCRCL.
      *---------------------------------------------------------------*
      * cics-crucible  pseudo-conversational / pc-return-channel      *
      * Original program (Apache-2.0).                                *
      * LINKed by PCRCA: builds a channel and RETURNs it to CICS from *
      * below the highest logical level, with RESP / RESP2.           *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CHAN               PIC X(16) VALUE 'PCCHAN'.
       01  WS-LINKED             PIC X(8)  VALUE 'CARRY-L2'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
           COPY PCRLOG.
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
           EXEC CICS PUT CONTAINER('STATE') CHANNEL(WS-CHAN)
                     FROM(WS-LINKED) CHAR
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT2' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS RETURN TRANSID('PC62') CHANNEL(WS-CHAN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'RET1' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS RETURN END-EXEC.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           EXEC CICS WRITEQ TS QUEUE('PCRLOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
