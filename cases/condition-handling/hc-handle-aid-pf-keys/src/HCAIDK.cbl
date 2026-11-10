       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCAIDK.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-handle-aid-pf-keys     *
      * Original program (Apache-2.0).                                *
      * HANDLE AID with labels for two PF keys, PF8 and PF12, set in  *
      * one command (HK01) or in two separate commands (HK02), then   *
      * one terminal RECEIVE. The key the operator pressed picks the  *
      * label: GOT-PF8, GOT-PF12, or none (control goes on after the  *
      * RECEIVE). Every path leaves a breadcrumb in WS-TRAIL, sent    *
      * with SEND TEXT: a path letter, LENGTH as 2 digits, and the    *
      * first 8 bytes of the input.                                   *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TRAIL              PIC X(40) VALUE SPACES.
       01  WS-PTR                PIC S9(4) COMP VALUE 1.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-LEN-D              PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EVALUATE EIBTRNID
      *        Two keys, one command
               WHEN 'HK01'
                   EXEC CICS HANDLE AID PF8(GOT-PF8) PF12(GOT-PF12)
                   END-EXEC
      *        Two keys, two commands: the second must not cancel
      *        the first
               WHEN OTHER
                   EXEC CICS HANDLE AID PF12(GOT-PF12) END-EXEC
                   EXEC CICS HANDLE AID PF8(GOT-PF8) END-EXEC
           END-EVALUATE
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           STRING 'n' DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR
           PERFORM NOTE-INPUT
           GO TO SEND-TRAIL.
      *    The labels show the input: it was moved before the transfer
       GOT-PF8.
           STRING 'e' DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR
           PERFORM NOTE-INPUT
           GO TO SEND-TRAIL.
       GOT-PF12.
           STRING 't' DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR
           PERFORM NOTE-INPUT.
       SEND-TRAIL.
           EXEC CICS SEND TEXT FROM(WS-TRAIL) LENGTH(40) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       NOTE-INPUT.
           MOVE WS-INLEN TO WS-LEN-D
           STRING WS-LEN-D ' ' WS-INPUT(1:8)
               DELIMITED BY SIZE INTO WS-TRAIL WITH POINTER WS-PTR.
