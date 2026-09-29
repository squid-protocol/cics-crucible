       IDENTIFICATION DIVISION.
       PROGRAM-ID. PCMENU.
      *---------------------------------------------------------------*
      * cics-crucible  pseudo-conversational / pc-aid-menu            *
      * Original program (Apache-2.0).                                *
      * A menu (transaction PC11) driven by HANDLE AID: PF3 exits,    *
      * PF5 refreshes (by falling through into SHOW-MENU), other PF   *
      * keys are rejected. Option 1 XCTLs to PCDETL, option 2 hands   *
      * the NEXT input to transaction PC12. EIBCALEN = 0 always means *
      * "new session", whatever key was pressed.                      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY PCSET2.
       COPY DFHAID.
       01  WS-CA.
           COPY PCMENUCA.
       01  WS-MSG                PIC X(40) VALUE SPACES.
       01  WS-BYE                PIC X(10) VALUE 'MENU ENDED'.
       01  WS-NEXT               PIC X(20) VALUE 'DETAIL ON NEXT ENTER'.
       LINKAGE SECTION.
       01  DFHCOMMAREA           PIC X(10).
       PROCEDURE DIVISION.
       MAIN-PARA.
           IF EIBCALEN = 0
               INITIALIZE WS-CA
               MOVE 1 TO MN-VISITS
               MOVE 'WELCOME' TO WS-MSG
               PERFORM SHOW-MENU
           END-IF
           MOVE DFHCOMMAREA TO WS-CA
           ADD 1 TO MN-VISITS
           IF EIBAID = DFHCLEAR
               MOVE 'CLEARED' TO WS-MSG
               PERFORM SHOW-MENU
           END-IF
           EXEC CICS HANDLE AID PF3(MENU-EXIT) PF5(MENU-REFRESH)
           END-EXEC
           MOVE LOW-VALUES TO PCMNI
           EXEC CICS RECEIVE MAP('PCMN') MAPSET('PCSET2') INTO(PCMNI)
           END-EXEC
           IF EIBAID NOT = DFHENTER
               MOVE 'KEY NOT ACTIVE' TO WS-MSG
               PERFORM SHOW-MENU
           END-IF
           EVALUATE OPTI
               WHEN '1'
                   MOVE 'PC11' TO MN-LAST
                   EXEC CICS XCTL PROGRAM('PCDETL') COMMAREA(WS-CA)
                             LENGTH(10)
                   END-EXEC
               WHEN '2'
                   MOVE 'PC11' TO MN-LAST
                   EXEC CICS SEND TEXT FROM(WS-NEXT) LENGTH(20) ERASE
                   END-EXEC
                   EXEC CICS RETURN TRANSID('PC12') COMMAREA(WS-CA)
                             LENGTH(10)
                   END-EXEC
               WHEN OTHER
                   MOVE 'INVALID OPTION' TO WS-MSG
                   PERFORM SHOW-MENU
           END-EVALUATE.
       MENU-EXIT.
           EXEC CICS SEND TEXT FROM(WS-BYE) LENGTH(10) ERASE END-EXEC
           EXEC CICS RETURN END-EXEC.
       MENU-REFRESH.
           MOVE 'REFRESHED' TO WS-MSG.
       SHOW-MENU.
           MOVE LOW-VALUES TO PCMNO
           MOVE MN-VISITS TO VISITSO
           MOVE WS-MSG TO MSGO
           EXEC CICS SEND MAP('PCMN') MAPSET('PCSET2') FROM(PCMNO) ERASE
           END-EXEC
           EXEC CICS RETURN TRANSID('PC11') COMMAREA(WS-CA) LENGTH(10)
           END-EXEC.
