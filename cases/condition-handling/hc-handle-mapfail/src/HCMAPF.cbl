       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCMAPF.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-handle-mapfail         *
      * Original program (Apache-2.0).                                *
      * One input field that is not FSET: an ENTER with nothing typed *
      * transmits no field, so RECEIVE MAP raises MAPFAIL. Three      *
      * transactions treat it three ways:                             *
      *   HM01  HANDLE CONDITION MAPFAIL(NO-INPUT)                    *
      *   HM02  RESP(WS-RESP), tested against DFHRESP(MAPFAIL)        *
      *   HM03  nothing: the default action (abend AEI9)              *
      * First task: SEND MAP and RETURN TRANSID (same transaction).   *
      * Second task: the RECEIVE MAP; the outcome goes to the screen  *
      * with SEND TEXT.                                               *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY HMSET.
       01  WS-CA.
           05  CA-MARK           PIC X VALUE 'S'.
       01  WS-TRAN               PIC X(4) VALUE SPACES.
       01  WS-OUT                PIC X(16) VALUE SPACES.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       LINKAGE SECTION.
       01  DFHCOMMAREA           PIC X(1).
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE EIBTRNID TO WS-TRAN
           IF EIBCALEN = 0
               MOVE LOW-VALUES TO HMAPO
               EXEC CICS SEND MAP('HMAP') MAPSET('HMSET') FROM(HMAPO)
                         ERASE
               END-EXEC
               EXEC CICS RETURN TRANSID(WS-TRAN) COMMAREA(WS-CA)
                         LENGTH(1)
               END-EXEC
           END-IF
           MOVE LOW-VALUES TO HMAPI
           EVALUATE WS-TRAN
               WHEN 'HM01'
                   EXEC CICS HANDLE CONDITION MAPFAIL(NO-INPUT)
                   END-EXEC
                   EXEC CICS RECEIVE MAP('HMAP') MAPSET('HMSET')
                             INTO(HMAPI)
                   END-EXEC
                   MOVE 'RECEIVE DONE' TO WS-OUT
               WHEN 'HM02'
                   EXEC CICS RECEIVE MAP('HMAP') MAPSET('HMSET')
                             INTO(HMAPI) RESP(WS-RESP)
                   END-EXEC
                   EVALUATE WS-RESP
                       WHEN DFHRESP(NORMAL)
                           MOVE 'RESP NORMAL' TO WS-OUT
                       WHEN DFHRESP(MAPFAIL)
                           MOVE 'RESP MAPFAIL' TO WS-OUT
                       WHEN OTHER
                           MOVE 'RESP OTHER' TO WS-OUT
                   END-EVALUATE
               WHEN OTHER
                   EXEC CICS RECEIVE MAP('HMAP') MAPSET('HMSET')
                             INTO(HMAPI)
                   END-EXEC
                   MOVE 'RECEIVE DONE' TO WS-OUT
           END-EVALUATE
           PERFORM SHOW-OUT.
       NO-INPUT.
           MOVE 'AT LABEL' TO WS-OUT.
       SHOW-OUT.
           EXEC CICS SEND TEXT FROM(WS-OUT) LENGTH(16) ERASE END-EXEC
           EXEC CICS RETURN END-EXEC.
