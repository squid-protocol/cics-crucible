       IDENTIFICATION DIVISION.
       PROGRAM-ID. PCWIZ.
      *---------------------------------------------------------------*
      * cics-crucible  pseudo-conversational / pc-wizard              *
      * Original program (Apache-2.0).                                *
      * Steps 1-2 of a three-screen wizard. Runs as PC01 (first       *
      * entry, EIBCALEN = 0) and PC02 (name screen answered), and is  *
      * XCTLed to from PCCONF (PF7 = back), still under PC03.         *
      * Every task ends in RETURN TRANSID(next) COMMAREA(state).      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY PCSET.
       COPY DFHAID.
       01  WS-STATE.
           COPY PCSTATE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-MSG                PIC X(40) VALUE SPACES.
       01  WS-AMT-DIGITS         PIC 9(7)  VALUE 0.
       01  WS-BYE                PIC X(16) VALUE 'WIZARD CANCELLED'.
       LINKAGE SECTION.
       01  DFHCOMMAREA           PIC X(30).
       PROCEDURE DIVISION.
       MAIN-PARA.
           IF EIBCALEN = 0
               INITIALIZE WS-STATE
               MOVE 1 TO PC-STEP
               MOVE 'TYPE YOUR NAME' TO WS-MSG
               PERFORM SEND-STEP1
           END-IF
           MOVE DFHCOMMAREA TO WS-STATE
           EVALUATE TRUE
               WHEN EIBAID = DFHPF3
                   PERFORM CANCEL-WIZARD
               WHEN PC-BACK = 'Y'
                   MOVE 'N' TO PC-BACK
                   MOVE 2 TO PC-STEP
                   MOVE 'CHANGE THE AMOUNT' TO WS-MSG
                   PERFORM SEND-STEP2
               WHEN EIBAID = DFHCLEAR
                   MOVE 'SCREEN RESTORED' TO WS-MSG
                   PERFORM SEND-STEP1
               WHEN OTHER
                   PERFORM TAKE-NAME
           END-EVALUATE.
       TAKE-NAME.
           MOVE LOW-VALUES TO PCM1I
           EXEC CICS RECEIVE MAP('PCM1') MAPSET('PCSET') INTO(PCM1I)
                     RESP(WS-RESP)
           END-EXEC
           IF WS-RESP NOT = DFHRESP(NORMAL) OR NAMEL = 0
               ADD 1 TO PC-ERRORS
               MOVE 'NAME IS REQUIRED' TO WS-MSG
               PERFORM SEND-STEP1
           END-IF
           MOVE NAMEI TO PC-NAME
           MOVE 2 TO PC-STEP
           MOVE 'TYPE THE AMOUNT IN CENTS' TO WS-MSG
           PERFORM SEND-STEP2.
       SEND-STEP1.
           MOVE LOW-VALUES TO PCM1O
           MOVE WS-MSG TO MSG1O
           EXEC CICS SEND MAP('PCM1') MAPSET('PCSET') FROM(PCM1O) ERASE
           END-EXEC
           EXEC CICS RETURN TRANSID('PC02') COMMAREA(WS-STATE)
                     LENGTH(30)
           END-EXEC.
       SEND-STEP2.
           MOVE LOW-VALUES TO PCM2O
           MOVE PC-NAME TO NAMEOUTO
           IF PC-AMOUNT > 0
               COMPUTE WS-AMT-DIGITS = PC-AMOUNT * 100
               MOVE WS-AMT-DIGITS TO AMTO
           END-IF
           MOVE WS-MSG TO MSG2O
           EXEC CICS SEND MAP('PCM2') MAPSET('PCSET') FROM(PCM2O) ERASE
           END-EXEC
           EXEC CICS RETURN TRANSID('PC03') COMMAREA(WS-STATE)
                     LENGTH(30)
           END-EXEC.
       CANCEL-WIZARD.
           EXEC CICS SEND TEXT FROM(WS-BYE) LENGTH(16) ERASE END-EXEC
           EXEC CICS RETURN END-EXEC.
