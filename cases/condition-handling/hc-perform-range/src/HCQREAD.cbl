       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCQREAD.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-perform-range          *
      * Original program (Apache-2.0).                                *
      * HANDLE CONDITION labels that sit inside a PERFORM ... THRU    *
      * range (and fall through into each other), an ERROR label      *
      * outside it, RESP overriding an active HANDLE, IGNORE          *
      * CONDITION, and a later HANDLE CONDITION overriding the        *
      * IGNORE. Every path leaves a breadcrumb in WS-TRAIL, which is  *
      * sent to the terminal at the end.                              *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TRAIL              PIC X(40) VALUE SPACES.
       01  WS-PTR                PIC S9(4) COMP VALUE 1.
       01  WS-ITEM               PIC X(8)  VALUE SPACES.
       01  WS-ILEN               PIC S9(4) COMP VALUE 0.
       01  WS-N                  PIC S9(4) COMP VALUE 0.
       01  WS-ONE                PIC X     VALUE 'W'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP-D             PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS HANDLE CONDITION QIDERR(NO-QUEUE)
                                      ITEMERR(PAST-END)
                                      ERROR(ANY-ERROR)
           END-EXEC
           STRING 'm' DELIMITED BY SIZE INTO WS-TRAIL
               WITH POINTER WS-PTR
      *    WS-ILEN is set once, before the loop, and never reset.
           MOVE 8 TO WS-ILEN
           PERFORM READ-ITEMS THRU READ-ITEMS-EXIT
           STRING 'b' DELIMITED BY SIZE INTO WS-TRAIL
               WITH POINTER WS-PTR
      *    A one-item scratch queue for the RESP / IGNORE / HANDLE tests
           EXEC CICS WRITEQ TS QUEUE('HCWORK') FROM(WS-ONE)
                     LENGTH(1)
           END-EXEC
      *    RESP: the ITEMERR handler is not taken, control falls through
           EXEC CICS READQ TS QUEUE('HCWORK') INTO(WS-ITEM)
                     LENGTH(WS-ILEN) ITEM(2) RESP(WS-RESP)
           END-EXEC
           MOVE WS-RESP TO WS-RESP-D
           STRING 'r' WS-RESP-D DELIMITED BY SIZE INTO WS-TRAIL
               WITH POINTER WS-PTR
      *    IGNORE CONDITION: no transfer, the EIB still says ITEMERR
           EXEC CICS IGNORE CONDITION ITEMERR END-EXEC
           EXEC CICS READQ TS QUEUE('HCWORK') INTO(WS-ITEM)
                     LENGTH(WS-ILEN) ITEM(3)
           END-EXEC
           MOVE EIBRESP TO WS-RESP-D
           STRING 'i' WS-RESP-D DELIMITED BY SIZE INTO WS-TRAIL
               WITH POINTER WS-PTR
      *    A new HANDLE CONDITION for ITEMERR overrides the IGNORE
           EXEC CICS HANDLE CONDITION ITEMERR(LATE-ITEM) END-EXEC
           EXEC CICS READQ TS QUEUE('HCWORK') INTO(WS-ITEM)
                     LENGTH(WS-ILEN) ITEM(4)
           END-EXEC
           STRING 'x' DELIMITED BY SIZE INTO WS-TRAIL
               WITH POINTER WS-PTR
           GO TO SEND-TRAIL.
       READ-ITEMS.
           PERFORM VARYING WS-N FROM 1 BY 1 UNTIL WS-N > 5
               EXEC CICS READQ TS QUEUE('HCQ1') INTO(WS-ITEM)
                         LENGTH(WS-ILEN) ITEM(WS-N)
               END-EXEC
               STRING WS-ITEM(1:1) DELIMITED BY SIZE INTO WS-TRAIL
                   WITH POINTER WS-PTR
           END-PERFORM
           STRING 'l' DELIMITED BY SIZE INTO WS-TRAIL
               WITH POINTER WS-PTR.
       NO-QUEUE.
           STRING 'q' DELIMITED BY SIZE INTO WS-TRAIL
               WITH POINTER WS-PTR.
       PAST-END.
           STRING 'p' DELIMITED BY SIZE INTO WS-TRAIL
               WITH POINTER WS-PTR.
       READ-ITEMS-EXIT.
           EXIT.
       LATE-ITEM.
           STRING 't' DELIMITED BY SIZE INTO WS-TRAIL
               WITH POINTER WS-PTR
           GO TO SEND-TRAIL.
       ANY-ERROR.
           MOVE EIBRESP TO WS-RESP-D
           STRING 'e' WS-RESP-D DELIMITED BY SIZE INTO WS-TRAIL
               WITH POINTER WS-PTR.
       SEND-TRAIL.
           EXEC CICS SEND TEXT FROM(WS-TRAIL) LENGTH(40) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
