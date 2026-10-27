       IDENTIFICATION DIVISION.
       PROGRAM-ID. CABROW.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-channel-browse          *
      * Original program (Apache-2.0).                                *
      * Browses the containers of a channel it created, MOVEs one to  *
      * another channel, counts with QUERY CHANNEL, then DELETEs the  *
      * channel. Every command names its CHANNEL: the terminal task   *
      * has no current channel. The browse order is undefined in IBM, *
      * so no log depends on it.                                      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CH                 PIC X(16) VALUE 'CABROWSEME'.
       01  WS-MV                 PIC X(16) VALUE 'CABMOVED'.
       01  WS-DATA               PIC X(5)  VALUE 'AAAAA'.
       01  WS-NAME               PIC X(16).
       01  WS-TOK                PIC S9(8) COMP.
       01  WS-CNT                PIC S9(8) COMP.
       01  WS-LEN                PIC S9(8) COMP.
       01  WS-SEEN               PIC S9(8) COMP.
       01  WS-FLAGS.
           05  WS-SEEN-A         PIC X VALUE 'N'.
           05  WS-SEEN-B         PIC X VALUE 'N'.
           05  WS-SEEN-G         PIC X VALUE 'N'.
       01  WS-RESP               PIC S9(8) COMP.
       01  WS-RESP2              PIC S9(8) COMP.
           COPY CALOG.
       PROCEDURE DIVISION.
       MAIN-PARA.
           INITIALIZE WS-LOG
           EXEC CICS PUT CONTAINER('ALPHA') CHANNEL(WS-CH)
                     FROM(WS-DATA) CHAR RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT1' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS PUT CONTAINER('BETA') CHANNEL(WS-CH)
                     FROM(WS-DATA) CHAR RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT2' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS PUT CONTAINER('GAMMA') CHANNEL(WS-CH)
                     FROM(WS-DATA) CHAR RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT3' TO LG-TAG
           PERFORM LOG-RESP
           MOVE 'QCH1' TO LG-TAG
           PERFORM QUERY-CH
           EXEC CICS STARTBROWSE CONTAINER CHANNEL(WS-CH)
                     BROWSETOKEN(WS-TOK)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'SBR1' TO LG-TAG
           PERFORM LOG-RESP
           PERFORM NEXT-NAME
           MOVE 'GNX1' TO LG-TAG
           PERFORM LOG-RESP
           PERFORM NEXT-NAME
           MOVE 'GNX2' TO LG-TAG
           PERFORM LOG-RESP
           PERFORM NEXT-NAME
           MOVE 'GNX3' TO LG-TAG
           PERFORM LOG-RESP
           MOVE 0 TO WS-SEEN
           IF WS-SEEN-A = 'Y' ADD 1 TO WS-SEEN END-IF
           IF WS-SEEN-B = 'Y' ADD 1 TO WS-SEEN END-IF
           IF WS-SEEN-G = 'Y' ADD 1 TO WS-SEEN END-IF
           MOVE 'NAMS' TO LG-TAG
           MOVE WS-SEEN TO LG-LEN
           PERFORM LOG-ENTRY
           PERFORM NEXT-NAME
           MOVE 'GNX4' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS ENDBROWSE CONTAINER BROWSETOKEN(WS-TOK)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'EBR1' TO LG-TAG
           PERFORM LOG-RESP
           PERFORM NEXT-NAME
           MOVE 'GNX5' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS ENDBROWSE CONTAINER BROWSETOKEN(WS-TOK)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'EBR2' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS MOVE CONTAINER('ALPHA') AS('ALPHA2')
                     CHANNEL(WS-CH) TOCHANNEL(WS-MV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'MOV1' TO LG-TAG
           PERFORM LOG-RESP
           MOVE 'QCH2' TO LG-TAG
           PERFORM QUERY-CH
           MOVE 'QCH3' TO LG-TAG
           PERFORM QUERY-MV
           EXEC CICS GET CONTAINER('ALPHA2') CHANNEL(WS-MV)
                     NODATA FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET1' TO LG-TAG
           MOVE WS-LEN TO LG-LEN
           PERFORM LOG-RESP
           EXEC CICS GET CONTAINER('ALPHA') CHANNEL(WS-CH)
                     NODATA FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET2' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS MOVE CONTAINER('ALPHA') AS('ALPHA3')
                     CHANNEL(WS-CH) TOCHANNEL(WS-MV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'MOV2' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS DELETE CHANNEL(WS-CH)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'DCH1' TO LG-TAG
           PERFORM LOG-RESP
           MOVE 'QCH4' TO LG-TAG
           PERFORM QUERY-CH
           EXEC CICS GET CONTAINER('BETA') CHANNEL(WS-CH)
                     NODATA FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET3' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS DELETE CHANNEL(WS-CH)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'DCH2' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS PUT CONTAINER('BETA') CHANNEL(WS-CH)
                     FROM(WS-DATA) CHAR RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'PUT4' TO LG-TAG
           PERFORM LOG-RESP
           MOVE 'QCH5' TO LG-TAG
           PERFORM QUERY-CH
           EXEC CICS GET CONTAINER('ALPHA') CHANNEL(WS-CH)
                     NODATA FLENGTH(WS-LEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'GET4' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS DELETE CHANNEL(WS-MV)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'DCH3' TO LG-TAG
           PERFORM LOG-RESP
           EXEC CICS RETURN END-EXEC.
      * QUERY CHANNEL of CABROWSEME: the count is logged only on NORMAL
      * (IBM does not say what CONTAINERCNT holds on CHANNELERR).
       QUERY-CH.
           MOVE 0 TO WS-CNT
           EXEC CICS QUERY CHANNEL(WS-CH) CONTAINERCNT(WS-CNT)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-RESP = 0
              MOVE WS-CNT TO LG-LEN
           END-IF
           PERFORM LOG-RESP.
       QUERY-MV.
           MOVE 0 TO WS-CNT
           EXEC CICS QUERY CHANNEL(WS-MV) CONTAINERCNT(WS-CNT)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-RESP = 0
              MOVE WS-CNT TO LG-LEN
           END-IF
           PERFORM LOG-RESP.
      * GETNEXT: the name is kept only as a seen-flag, never logged.
       NEXT-NAME.
           MOVE SPACES TO WS-NAME
           EXEC CICS GETNEXT CONTAINER(WS-NAME) BROWSETOKEN(WS-TOK)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-RESP = 0
              EVALUATE WS-NAME
                 WHEN 'ALPHA' MOVE 'Y' TO WS-SEEN-A
                 WHEN 'BETA'  MOVE 'Y' TO WS-SEEN-B
                 WHEN 'GAMMA' MOVE 'Y' TO WS-SEEN-G
              END-EVALUATE
           END-IF.
       LOG-RESP.
           MOVE WS-RESP TO LG-RESP
           MOVE WS-RESP2 TO LG-RESP2
           PERFORM LOG-ENTRY.
       LOG-ENTRY.
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-LOG) END-EXEC
           INITIALIZE WS-LOG.
