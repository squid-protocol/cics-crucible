       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCIGN.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-ignore-error           *
      * Original program (Apache-2.0).                                *
      * IGNORE CONDITION, HANDLE CONDITION ERROR and PUSH / POP       *
      * HANDLE around one condition: a terminal RECEIVE whose LENGTH  *
      * (4) is shorter than the input raises LENGERR. Each            *
      * transaction sets its handlers first: LENGERR ignored, ERROR's *
      * label, LENGERR's own label beside ERROR's, an IGNORE beside   *
      * ERROR, an IGNORE suspended by PUSH HANDLE and restored by POP *
      * HANDLE, an IGNORE overriding a HANDLE, ERROR suspended by     *
      * PUSH HANDLE; one pops with nothing pushed (INVREQ). Every     *
      * path leaves a breadcrumb in WS-TRAIL, sent with SEND TEXT.    *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TRAIL              PIC X(40) VALUE SPACES.
       01  WS-PTR                PIC S9(4) COMP VALUE 1.
       01  WS-INPUT              PIC X(4)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 4.
       01  WS-RESP-D             PIC 99    VALUE 0.
       01  WS-LEN-D              PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EVALUATE EIBTRNID
      *        IGNORE CONDITION: control goes on, the EIB says LENGERR
               WHEN 'IE01'
                   EXEC CICS IGNORE CONDITION LENGERR END-EXEC
      *        ERROR's label for a condition with no handler (#4502)
               WHEN 'IE02'
                   EXEC CICS HANDLE CONDITION ERROR(GOT-ERROR) END-EXEC
      *        LENGERR's own label beside ERROR's
               WHEN 'IE03'
                   EXEC CICS HANDLE CONDITION ERROR(GOT-ERROR)
                                              LENGERR(GOT-LEN)
                   END-EXEC
      *        LENGERR ignored beside ERROR's label
               WHEN 'IE04'
                   EXEC CICS HANDLE CONDITION ERROR(GOT-ERROR) END-EXEC
                   EXEC CICS IGNORE CONDITION LENGERR END-EXEC
      *        PUSH HANDLE suspends the IGNORE: the default action
               WHEN 'IE05'
                   EXEC CICS IGNORE CONDITION LENGERR END-EXEC
                   EXEC CICS PUSH HANDLE END-EXEC
      *        POP HANDLE restores it
               WHEN 'IE06'
                   EXEC CICS IGNORE CONDITION LENGERR END-EXEC
                   EXEC CICS PUSH HANDLE END-EXEC
                   EXEC CICS POP HANDLE END-EXEC
      *        POP HANDLE with nothing pushed: INVREQ, to ERROR's label
               WHEN 'IE07'
                   EXEC CICS HANDLE CONDITION ERROR(GOT-ERROR) END-EXEC
                   EXEC CICS POP HANDLE END-EXEC
                   STRING 'x' DELIMITED BY SIZE
                       INTO WS-TRAIL WITH POINTER WS-PTR
                   GO TO SEND-TRAIL
      *        IGNORE CONDITION overrides LENGERR's HANDLE CONDITION
               WHEN 'IE08'
                   EXEC CICS HANDLE CONDITION LENGERR(GOT-LEN) END-EXEC
                   EXEC CICS IGNORE CONDITION LENGERR END-EXEC
      *        PUSH HANDLE suspends ERROR's label: the default action
               WHEN OTHER
                   EXEC CICS HANDLE CONDITION ERROR(GOT-ERROR) END-EXEC
                   EXEC CICS PUSH HANDLE END-EXEC
           END-EVALUATE
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN) END-EXEC
           MOVE EIBRESP TO WS-RESP-D
           STRING 'i' WS-RESP-D DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR
           PERFORM NOTE-INPUT
           GO TO SEND-TRAIL.
       GOT-LEN.
           MOVE EIBRESP TO WS-RESP-D
           STRING 'l' WS-RESP-D DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR
           GO TO SEND-TRAIL.
       GOT-ERROR.
           MOVE EIBRESP TO WS-RESP-D
           STRING 'e' WS-RESP-D DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR.
       SEND-TRAIL.
           EXEC CICS SEND TEXT FROM(WS-TRAIL) LENGTH(40) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       NOTE-INPUT.
           MOVE WS-INLEN TO WS-LEN-D
           STRING ' ' WS-LEN-D ' ' WS-INPUT
               DELIMITED BY SIZE INTO WS-TRAIL WITH POINTER WS-PTR.
