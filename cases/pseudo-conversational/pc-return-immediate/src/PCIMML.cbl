       IDENTIFICATION DIVISION.
       PROGRAM-ID. PCIMML.
      *---------------------------------------------------------------*
      * cics-crucible  pseudo-conversational / pc-return-immediate    *
      * Original program (Apache-2.0).                                *
      * The program PCIMMA LINKs to. With a COMMAREA (mode L) it      *
      * rewrites the text and RETURNs; with none (mode N) it tries    *
      * RETURN IMMEDIATE below the highest logical level.             *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-R-D                PIC 99    VALUE 0.
       01  WS-LLOG.
           05  FILLER            PIC X(3)  VALUE 'L1 '.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  LLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' 2='.
           05  LLOG-RESP2        PIC 99    VALUE 0.
       LINKAGE SECTION.
       01  DFHCOMMAREA.
           05  CA-STAGE          PIC X.
           05  CA-TEXT           PIC X(7).
       PROCEDURE DIVISION.
       MAIN-PARA.
           IF EIBCALEN = 0
               EXEC CICS RETURN TRANSID('PC52') IMMEDIATE
                         RESP(WS-RESP) RESP2(WS-RESP2)
               END-EXEC
               MOVE WS-RESP TO LLOG-RESP
               MOVE WS-RESP2 TO LLOG-RESP2
               EXEC CICS WRITEQ TS QUEUE('PCLOG') FROM(WS-LLOG)
                         LENGTH(13)
               END-EXEC
           ELSE
               MOVE 'LINKED!' TO CA-TEXT
           END-IF
           EXEC CICS RETURN END-EXEC.
