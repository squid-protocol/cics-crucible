       IDENTIFICATION DIVISION.
       PROGRAM-ID. HXRST.
      *---------------------------------------------------------------*
      * cics-crucible  hex-attributes / hx-mdt-reset                  *
      * Original program (Apache-2.0).                                *
      * First entry: sends map HXM3 with ERASE; NOTE goes out with    *
      * its MDT on (DFHBMFSE). Later entries: RECEIVE MAP, then echo  *
      * with SEND MAP DATAONLY, adding FRSET on PF1, and on PF2 the   *
      * screen is cleared of data and sent with ERASEAUP. What the    *
      * next RECEIVE MAP gets depends only on the MDT bits the        *
      * terminal holds, so each path ends with an ENTER and no typing.*
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY HXSET3.
       COPY DFHBMSCA.
       COPY DFHAID.
       01  WS-CA                 PIC X     VALUE 'S'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       LINKAGE SECTION.
       01  DFHCOMMAREA           PIC X.
       PROCEDURE DIVISION.
       MAIN-PARA.
           IF EIBCALEN = 0
               PERFORM FIRST-SCREEN
           ELSE
               MOVE LOW-VALUES TO HXM3I
               EXEC CICS RECEIVE MAP('HXM3') MAPSET('HXSET3')
                         INTO(HXM3I) RESP(WS-RESP)
               END-EXEC
               IF EIBAID = DFHPF2
                   PERFORM ERASE-SCREEN
               ELSE
                   PERFORM ECHO-SCREEN
               END-IF
           END-IF
           EXEC CICS RETURN TRANSID('HX03') COMMAREA(WS-CA)
                     LENGTH(1)
           END-EXEC.
       FIRST-SCREEN.
           MOVE LOW-VALUES TO HXM3O
           MOVE DFHBMPRO TO MSGA
           MOVE 'READY' TO MSGO
      *    unprotected, normal, MDT on: the terminal will send NOTE
      *    on every ENTER until something resets its MDT
           MOVE DFHBMFSE TO NOTEA
           MOVE 'KEEP' TO NOTEO
           EXEC CICS SEND MAP('HXM3') MAPSET('HXSET3') FROM(HXM3O)
                     ERASE
           END-EXEC.
       ECHO-SCREEN.
           MOVE DFHBMPRO TO MSGA
           IF WS-RESP = DFHRESP(NORMAL)
               MOVE 'RECEIVED' TO MSGO
           ELSE
               MOVE 'NO INPUT' TO MSGO
           END-IF
           IF EIBAID = DFHPF1
               EXEC CICS SEND MAP('HXM3') MAPSET('HXSET3') FROM(HXM3O)
                         DATAONLY FRSET
               END-EXEC
           ELSE
               EXEC CICS SEND MAP('HXM3') MAPSET('HXSET3') FROM(HXM3O)
                         DATAONLY
               END-EXEC
           END-IF.
       ERASE-SCREEN.
           MOVE LOW-VALUES TO HXM3O
           MOVE DFHBMPRO TO MSGA
           MOVE 'ERASED' TO MSGO
           EXEC CICS SEND MAP('HXM3') MAPSET('HXSET3') FROM(HXM3O)
                     DATAONLY ERASEAUP
           END-EXEC.
