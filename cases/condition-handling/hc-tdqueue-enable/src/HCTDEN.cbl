       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCTDEN.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-tdqueue-enable         *
      * Original program (Apache-2.0).                                *
      * HCTD, a mode typed after the transid:                         *
      *   I  INQUIRE TDQUEUE of the defined queue HCQ1 (TYPE,         *
      *      ENABLESTATUS, RECOVSTATUS), then                         *
      *      INQUIRE TDQUEUE ENABLESTATUS of HCNQ, which the CSD does *
      *      not define                                               *
      *   S  SET TDQUEUE ENABLESTATUS DISABLED, INQUIRE, SET ENABLED, *
      *      INQUIRE                                                  *
      *   U  SET TDQUEUE ENABLESTATUS ENABLED of the undefined HCNQ   *
      *   V  SET TDQUEUE ENABLESTATUS(OPEN), a value that is not      *
      *      ENABLED or DISABLED, then INQUIRE                        *
      * INQUIRE and SET are not events (SPEC 6.2): each result is a   *
      * breadcrumb in TS queue HCLOG. Every command uses RESP, so a   *
      * condition never abends the task.                              *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-Q                  PIC X(4)  VALUE 'HCQ1'.
       01  WS-QN                 PIC X(4)  VALUE 'HCNQ'.
       01  WS-TYPE               PIC S9(8) COMP VALUE 0.
       01  WS-ENABLE             PIC S9(8) COMP VALUE 0.
       01  WS-RECOV              PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
      * Tag (3), R=resp (2), T=type, E=enable, V=recov
       01  WS-ILOG.
           05  ILOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  ILOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' T='.
           05  ILOG-TYPE         PIC 9(9)  VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' E='.
           05  ILOG-ENABLE       PIC 9(9)  VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' V='.
           05  ILOG-RECOV        PIC 9(9)  VALUE 0.
      * Tag (3), R=resp (2), E=enable
       01  WS-ELOG.
           05  ELOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  ELOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' E='.
           05  ELOG-ENABLE       PIC 9(9)  VALUE 0.
      * Tag (3), R=resp (2) of a SET that completed
       01  WS-DLOG.
           05  DLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  DLOG-RESP         PIC 99    VALUE 0.
      * Tag (3), R=resp (2), RESP2 (2) of a command that failed
       01  WS-FLOG.
           05  FLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  FLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(4)  VALUE ' R2='.
           05  FLOG-RESP2        PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'I'
                   PERFORM INQ-PARA
               WHEN 'S'
                   PERFORM TOGGLE-PARA
               WHEN 'U'
                   PERFORM UNDEF-PARA
               WHEN 'V'
                   PERFORM BADCVDA-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       INQ-PARA.
           EXEC CICS INQUIRE TDQUEUE(WS-Q) TYPE(WS-TYPE)
                     ENABLESTATUS(WS-ENABLE) RECOVSTATUS(WS-RECOV)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'I1 ' TO ILOG-TAG
           MOVE WS-RESP TO ILOG-RESP
           MOVE WS-TYPE TO ILOG-TYPE
           MOVE WS-ENABLE TO ILOG-ENABLE
           MOVE WS-RECOV TO ILOG-RECOV
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-ILOG)
                     LENGTH(44)
           END-EXEC
           MOVE 'I2 ' TO FLOG-TAG
           PERFORM INQ-UNDEFINED.
       TOGGLE-PARA.
           EXEC CICS SET TDQUEUE(WS-Q)
                     ENABLESTATUS(DFHVALUE(DISABLED)) RESP(WS-RESP)
           END-EXEC
           MOVE 'S1 ' TO DLOG-TAG
           PERFORM LOG-D
           PERFORM INQ-ENABLE
           MOVE 'S2 ' TO ELOG-TAG
           PERFORM LOG-E
           EXEC CICS SET TDQUEUE(WS-Q)
                     ENABLESTATUS(DFHVALUE(ENABLED)) RESP(WS-RESP)
           END-EXEC
           MOVE 'S3 ' TO DLOG-TAG
           PERFORM LOG-D
           PERFORM INQ-ENABLE
           MOVE 'S4 ' TO ELOG-TAG
           PERFORM LOG-E.
       UNDEF-PARA.
           EXEC CICS SET TDQUEUE(WS-QN)
                     ENABLESTATUS(DFHVALUE(ENABLED))
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'U1 ' TO FLOG-TAG
           PERFORM LOG-F.
       BADCVDA-PARA.
           EXEC CICS SET TDQUEUE(WS-Q)
                     ENABLESTATUS(DFHVALUE(OPEN))
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'V1 ' TO FLOG-TAG
           PERFORM LOG-F
           PERFORM INQ-ENABLE
           MOVE 'V2 ' TO ELOG-TAG
           PERFORM LOG-E.
       INQ-UNDEFINED.
           MOVE 0 TO WS-RESP2
           EXEC CICS INQUIRE TDQUEUE(WS-QN) ENABLESTATUS(WS-ENABLE)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           PERFORM LOG-F.
       INQ-ENABLE.
           MOVE 0 TO WS-ENABLE
           EXEC CICS INQUIRE TDQUEUE(WS-Q) ENABLESTATUS(WS-ENABLE)
                     RESP(WS-RESP)
           END-EXEC.
       LOG-D.
           MOVE WS-RESP TO DLOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-DLOG)
                     LENGTH(8)
           END-EXEC.
       LOG-E.
           MOVE WS-RESP TO ELOG-RESP
           MOVE WS-ENABLE TO ELOG-ENABLE
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-ELOG)
                     LENGTH(20)
           END-EXEC.
       LOG-F.
           MOVE WS-RESP TO FLOG-RESP
           MOVE WS-RESP2 TO FLOG-RESP2
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-FLOG)
                     LENGTH(14)
           END-EXEC.
