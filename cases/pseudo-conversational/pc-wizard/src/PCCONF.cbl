       IDENTIFICATION DIVISION.
       PROGRAM-ID. PCCONF.
      *---------------------------------------------------------------*
      * cics-crucible  pseudo-conversational / pc-wizard              *
      * Original program (Apache-2.0).                                *
      * Transaction PC03: takes the amount (step 2), shows the        *
      * confirmation (step 3), posts on ENTER, goes back to PCWIZ on  *
      * PF7 (XCTL), cancels on PF3, redraws on CLEAR.                 *
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
       01  WS-AMT-ED             PIC ZZZ,ZZ9.99.
       01  WS-BYE                PIC X(16) VALUE 'WIZARD CANCELLED'.
       01  WS-LEDGER.
           05  LG-NAME           PIC X(15).
           05  LG-AMT            PIC ZZZ,ZZ9.99.
           05  LG-SEP            PIC X(3)  VALUE ' E='.
           05  LG-ERR            PIC 9(2).
       01  WS-POSTED.
           05  FILLER            PIC X(8)  VALUE 'POSTED: '.
           05  WS-POST-DATA      PIC X(30).
       LINKAGE SECTION.
       01  DFHCOMMAREA           PIC X(30).
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE DFHCOMMAREA TO WS-STATE
           EVALUATE TRUE
               WHEN EIBAID = DFHPF3
                   EXEC CICS SEND TEXT FROM(WS-BYE) LENGTH(16) ERASE
                   END-EXEC
                   EXEC CICS RETURN END-EXEC
               WHEN EIBAID = DFHCLEAR
                   MOVE 'SCREEN RESTORED' TO WS-MSG
                   IF PC-STEP = 3
                       PERFORM SEND-STEP3
                   ELSE
                       PERFORM SEND-STEP2
                   END-IF
               WHEN PC-STEP = 2
                   PERFORM TAKE-AMOUNT
               WHEN EIBAID = DFHPF7
                   MOVE 'Y' TO PC-BACK
                   EXEC CICS XCTL PROGRAM('PCWIZ') COMMAREA(WS-STATE)
                             LENGTH(30)
                   END-EXEC
               WHEN EIBAID = DFHENTER
                   PERFORM POST-IT
               WHEN OTHER
                   MOVE 'USE ENTER, PF7 OR PF3' TO WS-MSG
                   PERFORM SEND-STEP3
           END-EVALUATE.
       TAKE-AMOUNT.
           MOVE LOW-VALUES TO PCM2I
           EXEC CICS RECEIVE MAP('PCM2') MAPSET('PCSET') INTO(PCM2I)
                     RESP(WS-RESP)
           END-EXEC
           IF WS-RESP NOT = DFHRESP(NORMAL) OR AMTL = 0
              OR AMTI IS NOT NUMERIC
               ADD 1 TO PC-ERRORS
               MOVE 'AMOUNT MUST BE DIGITS' TO WS-MSG
               PERFORM SEND-STEP2
           END-IF
           MOVE AMTI TO WS-AMT-DIGITS
           COMPUTE PC-AMOUNT = WS-AMT-DIGITS / 100
           MOVE 3 TO PC-STEP
           PERFORM SEND-STEP3.
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
       SEND-STEP3.
           MOVE LOW-VALUES TO PCM3O
           MOVE PC-NAME TO SUMNAMEO
           MOVE PC-AMOUNT TO WS-AMT-ED
           MOVE WS-AMT-ED TO SUMAMTO
           IF WS-MSG NOT = SPACES
               MOVE WS-MSG TO MSG3O
           END-IF
           EXEC CICS SEND MAP('PCM3') MAPSET('PCSET') FROM(PCM3O) ERASE
           END-EXEC
           EXEC CICS RETURN TRANSID('PC03') COMMAREA(WS-STATE)
                     LENGTH(30)
           END-EXEC.
       POST-IT.
           MOVE PC-NAME TO LG-NAME
           MOVE PC-AMOUNT TO LG-AMT
           MOVE PC-ERRORS TO LG-ERR
           EXEC CICS WRITEQ TS QUEUE('PCLEDGER') FROM(WS-LEDGER)
                     LENGTH(30)
           END-EXEC
           MOVE WS-LEDGER TO WS-POST-DATA
           EXEC CICS SEND TEXT FROM(WS-POSTED) LENGTH(38) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
