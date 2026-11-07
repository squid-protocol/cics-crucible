       IDENTIFICATION DIVISION.
       PROGRAM-ID. HXCUR.
      *---------------------------------------------------------------*
      * cics-crucible  hex-attributes / hx-cursor-offset              *
      * Original program (Apache-2.0).                                *
      * SEND MAP CURSOR(n): n is a screen offset, zero-based, row by  *
      * row at 80 columns (row 1 column 1 is 0). It overrides the     *
      * map's IC field, and DATAONLY does not stop it.                *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY HXSET5.
       COPY DFHAID.
       01  WS-CA                 PIC X     VALUE 'S'.
       01  WS-POS                PIC S9(4) COMP VALUE 0.
       01  WS-ROW                PIC S9(4) COMP VALUE 0.
       01  WS-COL                PIC S9(4) COMP VALUE 0.
       LINKAGE SECTION.
       01  DFHCOMMAREA           PIC X.
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE LOW-VALUES TO HXM5O
           IF EIBCALEN = 0
               MOVE 'READY' TO MSGO
               EXEC CICS SEND MAP('HXM5') MAPSET('HXSET5') FROM(HXM5O)
                         ERASE
               END-EXEC
           ELSE
               EVALUATE TRUE
                   WHEN EIBAID = DFHPF1
                       PERFORM FIXED-OFFSET
                   WHEN EIBAID = DFHPF2
                       PERFORM BEATS-IC
                   WHEN OTHER
                       PERFORM COMPUTED-OFFSET
               END-EVALUATE
           END-IF
           EXEC CICS RETURN TRANSID('HX05') COMMAREA(WS-CA) LENGTH(1)
           END-EXEC.
       FIXED-OFFSET.
           MOVE 'DATAONLY 165' TO MSGO
           MOVE 165 TO WS-POS
           EXEC CICS SEND MAP('HXM5') MAPSET('HXSET5') FROM(HXM5O)
                     DATAONLY CURSOR(WS-POS)
           END-EXEC.
       BEATS-IC.
           MOVE 'IC OVERRIDE' TO MSGO
           MOVE 81 TO WS-POS
           EXEC CICS SEND MAP('HXM5') MAPSET('HXSET5') FROM(HXM5O)
                     CURSOR(WS-POS)
           END-EXEC.
       COMPUTED-OFFSET.
           MOVE 6 TO WS-ROW
           MOVE 8 TO WS-COL
           COMPUTE WS-POS = (WS-ROW - 1) * 80 + (WS-COL - 1)
           MOVE 'ROW 6 COL 8' TO MSGO
           EXEC CICS SEND MAP('HXM5') MAPSET('HXSET5') FROM(HXM5O)
                     DATAONLY CURSOR(WS-POS)
           END-EXEC.
