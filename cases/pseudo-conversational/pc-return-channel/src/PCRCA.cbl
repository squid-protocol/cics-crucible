       IDENTIFICATION DIVISION.
       PROGRAM-ID. PCRCA.
      *---------------------------------------------------------------*
      * cics-crucible  pseudo-conversational / pc-return-channel      *
      * Original program (Apache-2.0).                                *
      * PC61, a mode typed after the transid:                         *
      *   C  PUT a container, RETURN TRANSID(PC62) CHANNEL            *
      *   M  the same, with a container that PC62 changes each turn   *
      *   L  LINK PCRCL, which tries RETURN CHANNEL below level 1     *
      * Every result is a breadcrumb in TS queue PCRLOG.              *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-CHAN               PIC X(16) VALUE 'PCCHAN'.
       01  WS-CARRY              PIC X(8)  VALUE 'CARRY-A1'.
       01  WS-MODIFY             PIC X(8)  VALUE '1MODIFY0'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
           COPY PCRLOG.
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'C'
                   PERFORM CARRY-PARA
               WHEN 'M'
                   PERFORM MODIFY-PARA
               WHEN 'L'
                   PERFORM LINK-PARA
           END-EVALUATE
           EXEC CICS RETURN END-EXEC.
       CARRY-PARA.
           EXEC CICS PUT CONTAINER('STATE') CHANNEL(WS-CHAN)
                     FROM(WS-CARRY) CHAR
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT1' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS RETURN TRANSID('PC62') CHANNEL(WS-CHAN)
           END-EXEC.
       MODIFY-PARA.
           EXEC CICS PUT CONTAINER('STATE') CHANNEL(WS-CHAN)
                     FROM(WS-MODIFY) CHAR
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT1' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS RETURN TRANSID('PC62') CHANNEL(WS-CHAN)
           END-EXEC.
       LINK-PARA.
           EXEC CICS LINK PROGRAM('PCRCL')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'LNK1' TO LG-TAG
           PERFORM LOG-RESP.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           EXEC CICS WRITEQ TS QUEUE('PCRLOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
