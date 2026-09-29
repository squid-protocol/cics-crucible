       IDENTIFICATION DIVISION.
       PROGRAM-ID. HXEXT.
      *---------------------------------------------------------------*
      * cics-crucible  hex-attributes / hx-extended-cursor            *
      * Original program (Apache-2.0).                                *
      * Extended attributes (colour, highlight) next to the base      *
      * attribute byte, symbolic cursor positioning (-1 in the length *
      * field + CURSOR), and a NUM field with JUSTIFY=(RIGHT,ZERO).   *
      * PF5 shows the classic mistake: X'F1' ("blink") moved to the   *
      * attribute byte instead of the highlight byte.                 *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY HXSET2.
       COPY DFHBMSCA.
       COPY DFHAID.
       01  WS-CA                 PIC X     VALUE 'E'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       LINKAGE SECTION.
       01  DFHCOMMAREA           PIC X.
       PROCEDURE DIVISION.
       MAIN-PARA.
           IF EIBCALEN = 0
               MOVE LOW-VALUES TO HXM2O
               MOVE 'ENTER ACCOUNT AND AMOUNT' TO MSGO
               EXEC CICS SEND MAP('HXM2') MAPSET('HXSET2') FROM(HXM2O)
                         ERASE
               END-EXEC
           ELSE
               IF EIBAID = DFHPF5
                   PERFORM BLINK-MISTAKE
               ELSE
                   PERFORM CHECK-INPUT
               END-IF
           END-IF
           EXEC CICS RETURN TRANSID('HX02') COMMAREA(WS-CA) LENGTH(1)
           END-EXEC.
       CHECK-INPUT.
           MOVE LOW-VALUES TO HXM2I
           EXEC CICS RECEIVE MAP('HXM2') MAPSET('HXSET2') INTO(HXM2I)
                     RESP(WS-RESP)
           END-EXEC
           IF ACCTL NOT = 6 OR ACCTI IS NOT NUMERIC
               MOVE -1 TO ACCTL
               MOVE DFHUNIMD TO ACCTA
               MOVE DFHRED TO ACCTC
               MOVE DFHBLINK TO ACCTH
               MOVE 'ACCOUNT MUST BE 6 DIGITS' TO MSGO
               EXEC CICS SEND MAP('HXM2') MAPSET('HXSET2') FROM(HXM2O)
                         DATAONLY CURSOR ALARM
               END-EXEC
           ELSE
               MOVE SPACES TO MSGO
               STRING 'OK ' ACCTI ' AMOUNT ' AMOUNTI
                   DELIMITED BY SIZE INTO MSGO
               EXEC CICS SEND MAP('HXM2') MAPSET('HXSET2') FROM(HXM2O)
                         DATAONLY
               END-EXEC
           END-IF.
       BLINK-MISTAKE.
           MOVE LOW-VALUES TO HXM2O
      *    wrong: X'F1' in the attribute byte is autoskip + MDT
           MOVE X'F1' TO MSGA
           MOVE 'BLINK REQUESTED' TO MSGO
      *    right: blink is the extended highlighting byte
           MOVE DFHBMUNP TO ACCTA
           MOVE DFHBLINK TO ACCTH
           EXEC CICS SEND MAP('HXM2') MAPSET('HXSET2') FROM(HXM2O)
                     DATAONLY
           END-EXEC.
