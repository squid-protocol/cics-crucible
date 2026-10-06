       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCEOC.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-terminal-eoc           *
      * Original program (Apache-2.0).                                *
      * The terminal is a 3270 display logical unit (LUTYPE2): the    *
      * input message is one chain, so the RECEIVE that returns it    *
      * raises EOC. Three transactions run the same program and treat *
      * EOC three ways, chosen by EIBTRNID before the RECEIVE: RESP   *
      * (HC04), HANDLE CONDITION EOC (HC05), and neither (HC06), where *
      * CICS's default action ignores it. The breadcrumbs go out with *
      * SEND TEXT.                                                    *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TRAIL              PIC X(40) VALUE SPACES.
       01  WS-PTR                PIC S9(4) COMP VALUE 1.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP-D             PIC 99    VALUE 0.
       01  WS-LEN-D              PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EVALUATE EIBTRNID
               WHEN 'HC04'
                   EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
                             RESP(WS-RESP)
                   END-EXEC
                   MOVE WS-RESP TO WS-RESP-D
                   STRING 'r' DELIMITED BY SIZE
                       INTO WS-TRAIL WITH POINTER WS-PTR
                   PERFORM NOTE-INPUT
               WHEN 'HC05'
                   EXEC CICS HANDLE CONDITION EOC(GOT-EOC) END-EXEC
                   EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
                   END-EXEC
                   STRING 'n' DELIMITED BY SIZE
                       INTO WS-TRAIL WITH POINTER WS-PTR
               WHEN OTHER
                   EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
                   END-EXEC
                   MOVE EIBRESP TO WS-RESP-D
                   STRING 'i' DELIMITED BY SIZE
                       INTO WS-TRAIL WITH POINTER WS-PTR
                   PERFORM NOTE-INPUT
           END-EVALUATE
           GO TO SEND-TRAIL.
      *    The handler shows only that it ran and EIBRESP
       GOT-EOC.
           MOVE EIBRESP TO WS-RESP-D
           STRING 'e' WS-RESP-D DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR.
       SEND-TRAIL.
           EXEC CICS SEND TEXT FROM(WS-TRAIL) LENGTH(40) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       NOTE-INPUT.
           MOVE WS-INLEN TO WS-LEN-D
           STRING WS-RESP-D '/' WS-LEN-D ' ' WS-INPUT(1:WS-INLEN)
               DELIMITED BY SIZE INTO WS-TRAIL WITH POINTER WS-PTR.
