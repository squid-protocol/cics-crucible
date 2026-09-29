       IDENTIFICATION DIVISION.
       PROGRAM-ID. HXATTR.
      *---------------------------------------------------------------*
      * cics-crucible  hex-attributes / hx-attr-bytes                 *
      * Original program (Apache-2.0).                                *
      * First entry: fills the attribute bytes of map HXM1 by every   *
      * route seen in old code: a DFHBMSCA name, hex literals (valid, *
      * non-graphic, and a byte meant as "blink"), bit arithmetic,    *
      * and a left-over input flag. Second entry: RECEIVE MAP and     *
      * echo the map back with SEND MAP DATAONLY (or, on CLEAR,       *
      * resend the bare map with MAPONLY).                            *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY HXSET1.
       COPY DFHBMSCA.
       COPY DFHAID.
       01  WS-CA                 PIC X     VALUE 'S'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-BITS.
           05  WS-BITS-NUM       PIC S9(4) COMP VALUE 0.
       01  WS-BITS-X REDEFINES WS-BITS.
           05  WS-BITS-HIGH      PIC X.
           05  WS-BITS-LOW       PIC X.
       LINKAGE SECTION.
       01  DFHCOMMAREA           PIC X.
       PROCEDURE DIVISION.
       MAIN-PARA.
           IF EIBCALEN = 0
               PERFORM FIRST-SCREEN
           ELSE
               IF EIBAID = DFHCLEAR
                   PERFORM RESET-SCREEN
               ELSE
                   PERFORM ECHO-SCREEN
               END-IF
           END-IF
           EXEC CICS RETURN END-EXEC.
       FIRST-SCREEN.
           MOVE LOW-VALUES TO HXM1O
      *    a DFHBMSCA name: protected, normal
           MOVE DFHBMPRO TO STATA
           MOVE 'PROTECTED' TO STATO
      *    a literal: protected + bright (the value of DFHPROTI)
           MOVE X'E8' TO BRITEA
           MOVE 'IGNORED' TO BRITEO
           MOVE LOW-VALUE TO BRITEO(1:1)
      *    a literal: unprotected, nondisplay, MDT on (DFHUNNOD)
           MOVE X'4D' TO SECRETA
           MOVE 'PASSWORD' TO SECRETO
      *    a raw byte that is not an EBCDIC graphic
           MOVE X'3C' TO RAWA
           MOVE 'HIDDEN' TO RAWO
      *    meant as "blink": F1 in the ATTRIBUTE byte is ASKIP + MDT
           MOVE X'F1' TO BLINKYA
           MOVE 'BLINK?' TO BLINKYO
      *    bit arithmetic: DFHBMUNP (X'40') plus 1 to set the MDT bit
           MOVE DFHBMUNP TO WS-BITS-LOW
           ADD 1 TO WS-BITS-NUM
           MOVE WS-BITS-LOW TO TWIDDLEA
           MOVE 'TWIDDLED' TO TWIDDLEO
      *    a left-over input flag (field erased) used as an attribute
           MOVE DFHBMEOF TO LEFTOVRA
      *    null attribute, program data
           MOVE 'PROGDATA' TO NULATRO
           EXEC CICS SEND MAP('HXM1') MAPSET('HXSET1') FROM(HXM1O)
                     ERASE
           END-EXEC
           EXEC CICS RETURN TRANSID('HX01') COMMAREA(WS-CA)
                     LENGTH(1)
           END-EXEC.
       ECHO-SCREEN.
           MOVE LOW-VALUES TO HXM1I
           EXEC CICS RECEIVE MAP('HXM1') MAPSET('HXSET1') INTO(HXM1I)
                     RESP(WS-RESP)
           END-EXEC
           MOVE DFHBMPRF TO STATA
           IF WS-RESP = DFHRESP(NORMAL)
               MOVE 'RECEIVED' TO STATO
           ELSE
               MOVE 'NO INPUT' TO STATO
           END-IF
           EXEC CICS SEND MAP('HXM1') MAPSET('HXSET1') FROM(HXM1O)
                     DATAONLY
           END-EXEC.
       RESET-SCREEN.
           EXEC CICS SEND MAP('HXM1') MAPSET('HXSET1') MAPONLY ERASE
           END-EXEC
           EXEC CICS RETURN TRANSID('HX01') COMMAREA(WS-CA)
                     LENGTH(1)
           END-EXEC.
