       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTASGN.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-assign-startcode              *
      * Original program (Apache-2.0).                                *
      * GT31, a terminal task: logs what ASSIGN says about how it was *
      * started, by whom and where (STARTCODE, USERID, FACILITY,      *
      * SCRNHT, SCRNWD) to TS queue GTLOG. Modes typed after the      *
      * transid:                                                      *
      *   T  log, then START GT32 with FROM, GT32 without FROM and    *
      *      GT33 at terminal T001 without FROM                       *
      *   P  log, then RETURN TRANSID('GT31'): the next input runs    *
      *      GT31 again with a COMMAREA, which logs once more         *
      *   X  START GT34, which ASSIGNs FACILITY with no RESP          *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-MSG                PIC X(10) VALUE 'ORDER 0031'.
       01  WS-SC                 PIC X(2)  VALUE SPACES.
       01  WS-USER               PIC X(8)  VALUE SPACES.
       01  WS-FAC                PIC X(4)  VALUE SPACES.
       01  WS-HT                 PIC S9(4) COMP VALUE 0.
       01  WS-WD                 PIC S9(4) COMP VALUE 0.
       01  WS-ALOG.
           05  ALOG-TAG          PIC X(4)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' C='.
           05  ALOG-SC           PIC X(2)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' U='.
           05  ALOG-USER         PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' F='.
           05  ALOG-FAC          PIC X(5)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' H='.
           05  ALOG-HT           PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' W='.
           05  ALOG-WD           PIC 99    VALUE 0.
       01  WS-CA                 PIC X(4)  VALUE 'NEXT'.
       01  WS-TEXT               PIC X(20) VALUE 'ASSIGN LOGGED'.
       LINKAGE SECTION.
       01  DFHCOMMAREA           PIC X(4).
       PROCEDURE DIVISION.
       MAIN-PARA.
           IF EIBCALEN > 0
               MOVE 'P31B' TO ALOG-TAG
               PERFORM LOG-ASSIGN
               EXEC CICS SEND TEXT FROM(WS-TEXT) LENGTH(20) ERASE
               END-EXEC
               EXEC CICS RETURN END-EXEC
           END-IF
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'T'
                   MOVE 'T31A' TO ALOG-TAG
                   PERFORM LOG-ASSIGN
                   EXEC CICS START TRANSID('GT32') INTERVAL(0)
                             FROM(WS-MSG) LENGTH(10)
                   END-EXEC
                   EXEC CICS START TRANSID('GT32') INTERVAL(10)
                   END-EXEC
                   EXEC CICS START TRANSID('GT33') INTERVAL(20)
                             TERMID('T001')
                   END-EXEC
               WHEN 'P'
                   MOVE 'P31A' TO ALOG-TAG
                   PERFORM LOG-ASSIGN
                   EXEC CICS SEND TEXT FROM(WS-TEXT) LENGTH(20) ERASE
                   END-EXEC
                   EXEC CICS RETURN TRANSID('GT31') COMMAREA(WS-CA)
                             LENGTH(4)
                   END-EXEC
               WHEN 'X'
                   EXEC CICS START TRANSID('GT34') INTERVAL(0)
                   END-EXEC
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-TEXT) LENGTH(20) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       LOG-ASSIGN.
           EXEC CICS ASSIGN STARTCODE(WS-SC) USERID(WS-USER)
                     FACILITY(WS-FAC) SCRNHT(WS-HT) SCRNWD(WS-WD)
           END-EXEC
           MOVE WS-SC TO ALOG-SC
           MOVE WS-USER TO ALOG-USER
           MOVE WS-FAC TO ALOG-FAC
           MOVE WS-HT TO ALOG-HT
           MOVE WS-WD TO ALOG-WD
           EXEC CICS WRITEQ TS QUEUE('GTLOG') FROM(WS-ALOG)
                     LENGTH(38)
           END-EXEC.
