       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCMAIN.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-abend-link             *
      * Original program (Apache-2.0).                                *
      * Sets a QIDERR handler and a HANDLE ABEND LABEL exit, then     *
      * LINKs to HCSUB. The handlers are not inherited by HCSUB, are  *
      * restored on return, catch abends raised at the lower level,   *
      * and are suspended by PUSH HANDLE. The mode letter comes from  *
      * TS queue HCMODE.                                              *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TRAIL              PIC X(40) VALUE SPACES.
       01  WS-PTR                PIC S9(4) COMP VALUE 1.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-MLEN               PIC S9(4) COMP VALUE 1.
       01  WS-JUNK               PIC X(8)  VALUE SPACES.
       01  WS-JLEN               PIC S9(4) COMP VALUE 8.
       01  WS-ABCODE             PIC X(4)  VALUE SPACES.
       01  WS-CA.
           COPY HCLINKCA.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS HANDLE CONDITION QIDERR(MAIN-QIDERR) END-EXEC
           EXEC CICS HANDLE ABEND LABEL(MAIN-ABEND) END-EXEC
           EXEC CICS READQ TS QUEUE('HCMODE') INTO(WS-MODE)
                     LENGTH(WS-MLEN) ITEM(1)
           END-EXEC
           STRING 'm' DELIMITED BY SIZE INTO WS-TRAIL
               WITH POINTER WS-PTR
           IF WS-MODE = 'P' OR WS-MODE = 'O'
               EXEC CICS PUSH HANDLE END-EXEC
               STRING 'u' DELIMITED BY SIZE INTO WS-TRAIL
                   WITH POINTER WS-PTR
               IF WS-MODE = 'P'
                   EXEC CICS READQ TS QUEUE('HCNONE') INTO(WS-JUNK)
                             LENGTH(WS-JLEN) ITEM(1)
                   END-EXEC
               END-IF
               EXEC CICS POP HANDLE END-EXEC
               STRING 'o' DELIMITED BY SIZE INTO WS-TRAIL
                   WITH POINTER WS-PTR
           ELSE
               INITIALIZE WS-CA
               MOVE WS-MODE TO CA-MODE
               EXEC CICS LINK PROGRAM('HCSUB') COMMAREA(WS-CA)
                         LENGTH(20)
               END-EXEC
               STRING 'r' CA-TRAIL(1:3) CA-RESULT
                   DELIMITED BY SIZE INTO WS-TRAIL WITH POINTER WS-PTR
           END-IF
      *    The QIDERR handler is in force again here
           EXEC CICS READQ TS QUEUE('HCNONE') INTO(WS-JUNK)
                     LENGTH(WS-JLEN) ITEM(1)
           END-EXEC
           STRING 'x' DELIMITED BY SIZE INTO WS-TRAIL
               WITH POINTER WS-PTR
           GO TO SEND-TRAIL.
       MAIN-QIDERR.
           STRING 'q' DELIMITED BY SIZE INTO WS-TRAIL
               WITH POINTER WS-PTR
           GO TO SEND-TRAIL.
       MAIN-ABEND.
           EXEC CICS ASSIGN ABCODE(WS-ABCODE) END-EXEC
           STRING 'X' WS-ABCODE 'c' CA-TRAIL(1:3)
               DELIMITED BY SIZE INTO WS-TRAIL WITH POINTER WS-PTR.
       SEND-TRAIL.
           EXEC CICS SEND TEXT FROM(WS-TRAIL) LENGTH(40) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
