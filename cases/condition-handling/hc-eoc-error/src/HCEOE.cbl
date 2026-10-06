       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCEOE.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-eoc-error              *
      * Original program (Apache-2.0).                                *
      * The terminal is a 3270 display logical unit (LUTYPE2): the    *
      * RECEIVE that returns the input raises EOC, whose default      *
      * action is to ignore it. HANDLE CONDITION ERROR is active in   *
      * both transactions; EE02 also names EOC's own label. The       *
      * breadcrumbs go out with SEND TEXT.                            *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TRAIL              PIC X(40) VALUE SPACES.
       01  WS-PTR                PIC S9(4) COMP VALUE 1.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-RESP-D             PIC 99    VALUE 0.
       01  WS-LEN-D              PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS HANDLE CONDITION ERROR(GOT-ERROR) END-EXEC
           IF EIBTRNID = 'EE02'
               EXEC CICS HANDLE CONDITION EOC(GOT-EOC) END-EXEC
           END-IF
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN) END-EXEC
           MOVE EIBRESP TO WS-RESP-D
           MOVE WS-INLEN TO WS-LEN-D
           STRING 'i' WS-RESP-D '/' WS-LEN-D ' ' WS-INPUT(1:WS-INLEN)
               DELIMITED BY SIZE INTO WS-TRAIL WITH POINTER WS-PTR
           GO TO SEND-TRAIL.
       GOT-EOC.
           MOVE EIBRESP TO WS-RESP-D
           STRING 'c' WS-RESP-D DELIMITED BY SIZE
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
