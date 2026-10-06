       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTASNT.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-assign-startcode              *
      * Original program (Apache-2.0).                                *
      * GT32 / GT33, started by GT31: logs ASSIGN STARTCODE / USERID, *
      * then ASSIGN FACILITY / SCRNHT / SCRNWD with RESP: the values  *
      * on NORMAL, else only the RESP / RESP2 (no data area is read). *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SC                 PIC X(2)  VALUE SPACES.
       01  WS-USER               PIC X(8)  VALUE SPACES.
       01  WS-FAC                PIC X(4)  VALUE SPACES.
       01  WS-HT                 PIC S9(4) COMP VALUE 0.
       01  WS-WD                 PIC S9(4) COMP VALUE 0.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-ALOG.
           05  ALOG-TAG          PIC X(4)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' C='.
           05  ALOG-SC           PIC X(2)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' U='.
           05  ALOG-USER         PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' F='.
           05  ALOG-FAC.
               10  ALOG-R        PIC 99    VALUE 0.
               10  ALOG-SL       PIC X     VALUE SPACE.
               10  ALOG-R2       PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' H='.
           05  ALOG-HT           PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' W='.
           05  ALOG-WD           PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE EIBTRNID TO ALOG-TAG
           EXEC CICS ASSIGN STARTCODE(WS-SC) USERID(WS-USER)
           END-EXEC
           MOVE WS-SC TO ALOG-SC
           MOVE WS-USER TO ALOG-USER
           EXEC CICS ASSIGN FACILITY(WS-FAC) SCRNHT(WS-HT)
                     SCRNWD(WS-WD) RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-RESP = 0
               MOVE WS-FAC TO ALOG-FAC
               MOVE WS-HT TO ALOG-HT
               MOVE WS-WD TO ALOG-WD
           ELSE
               MOVE WS-RESP TO ALOG-R
               MOVE '/' TO ALOG-SL
               MOVE WS-RESP2 TO ALOG-R2
           END-IF
           EXEC CICS WRITEQ TS QUEUE('GTLOG') FROM(WS-ALOG)
                     LENGTH(38)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
