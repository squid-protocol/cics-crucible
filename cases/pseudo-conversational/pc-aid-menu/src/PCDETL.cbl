       IDENTIFICATION DIVISION.
       PROGRAM-ID. PCDETL.
      *---------------------------------------------------------------*
      * cics-crucible  pseudo-conversational / pc-aid-menu            *
      * Original program (Apache-2.0).                                *
      * The detail screen: reached by XCTL from PCMENU (the task is   *
      * still PC11) or as transaction PC12 on the next input. Shows   *
      * the COMMAREA and EIBTRNID, then RETURNs TRANSID('PC11') with  *
      * NO COMMAREA, so the menu starts a new session.                *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY PCSET2.
       01  WS-CA.
           COPY PCMENUCA.
       01  WS-NOCTX              PIC X(28)
                                 VALUE 'NO CONTEXT - START FROM PC11'.
       LINKAGE SECTION.
       01  DFHCOMMAREA           PIC X(10).
       PROCEDURE DIVISION.
       MAIN-PARA.
           IF EIBCALEN = 0
               EXEC CICS SEND TEXT FROM(WS-NOCTX) LENGTH(28) ERASE
               END-EXEC
               EXEC CICS RETURN END-EXEC
           END-IF
           MOVE DFHCOMMAREA TO WS-CA
           MOVE LOW-VALUES TO PCDTO
           MOVE MN-VISITS TO DVISITSO
           MOVE MN-LAST TO DLASTO
           MOVE EIBTRNID TO DTRANO
           MOVE 'ENTER RETURNS TO THE MENU' TO DMSGO
           EXEC CICS SEND MAP('PCDT') MAPSET('PCSET2') FROM(PCDTO) ERASE
           END-EXEC
           EXEC CICS RETURN TRANSID('PC11') END-EXEC.
