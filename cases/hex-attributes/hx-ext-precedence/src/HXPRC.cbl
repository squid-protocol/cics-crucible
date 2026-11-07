       IDENTIFICATION DIVISION.
       PROGRAM-ID. HXPRC.
      *---------------------------------------------------------------*
      * cics-crucible  hex-attributes / hx-ext-precedence             *
      * Original program (Apache-2.0).                                *
      * Where a field's colour and highlight come from: the byte the  *
      * program puts in <f>C / <f>H, else the field's COLOR/HILIGHT,  *
      * else the map's, else the mapset's. X'00' (DFHDFCOL) is "not   *
      * set", not a colour. DATAONLY applies no map default at all.   *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY HXSET4.
       COPY DFHBMSCA.
       COPY DFHAID.
       01  WS-CA                 PIC X     VALUE 'S'.
       LINKAGE SECTION.
       01  DFHCOMMAREA           PIC X.
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE LOW-VALUES TO HXM4O
           MOVE 'ALPHA' TO FAO
           MOVE 'BETA' TO FBO
           MOVE 'GAMMA' TO FCO
           IF EIBCALEN = 0
               EXEC CICS SEND MAP('HXM4') MAPSET('HXSET4') FROM(HXM4O)
                         ERASE
               END-EXEC
           ELSE
               IF EIBAID = DFHPF1
                   PERFORM OVERRIDE-SOME
               ELSE
                   PERFORM DATAONLY-SEND
               END-IF
           END-IF
           EXEC CICS RETURN TRANSID('HX04') COMMAREA(WS-CA) LENGTH(1)
           END-EXEC.
       OVERRIDE-SOME.
      *    program colour beats the field's RED; the default byte
      *    X'00' leaves BLUE (map) in force; program highlight beats
      *    the field's REVERSE
           MOVE DFHYELLO TO FAC
           MOVE DFHDFCOL TO FBC
           MOVE DFHBLINK TO FCH
           EXEC CICS SEND MAP('HXM4') MAPSET('HXSET4') FROM(HXM4O)
           END-EXEC.
       DATAONLY-SEND.
      *    DATAONLY: only what the program supplies is sent; the map's
      *    colours and highlights are not applied
           MOVE LOW-VALUES TO HXM4O
           MOVE DFHPINK TO FAC
           MOVE DFHDFCOL TO FBC
           MOVE 'BETA' TO FBO
           EXEC CICS SEND MAP('HXM4') MAPSET('HXSET4') FROM(HXM4O)
                     DATAONLY
           END-EXEC.
