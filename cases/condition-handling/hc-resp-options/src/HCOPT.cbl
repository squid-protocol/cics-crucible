       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCOPT.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-resp-options           *
      * Original program (Apache-2.0).                                *
      * HC51, modes typed after the transid:                          *
      *   F  ASKTIME without ABSTIME (NOHANDLE), ASKTIME ABSTIME,     *
      *      FORMATTIME with RESP / RESP2 on a valid ABSTIME and on   *
      *      an ABSTIME below zero                                    *
      *   Q  READQ TS ... LENGTH(LENGTH OF area): a longer item is    *
      *      truncated (LENGERR), a fitting one is not                *
      *   A  SEND MAP, then (transaction HC52) RECEIVE MAP ... ASIS   *
      * Every result is a breadcrumb in TS queue HCLOG (ASKTIME and   *
      * FORMATTIME are not events).                                   *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY HCSET1.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-ABS                PIC S9(15) COMP-3 VALUE 0.
       01  WS-DATE               PIC X(10) VALUE SPACES.
       01  WS-TIME               PIC X(8)  VALUE SPACES.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-R-D                PIC 99    VALUE 0.
       01  WS-ITEM               PIC S9(4) COMP VALUE 0.
       01  WS-QAREA              PIC X(20) VALUE 'ABCDEFGHIJKLMNOPQRST'.
       01  WS-QSHORT             PIC X(12) VALUE 'abcdefghijkl'.
       01  WS-SMALL              PIC X(12) VALUE SPACES.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-FLOG.
           05  FLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FLOG-DATE         PIC X(10) VALUE SPACES.
           05  FILLER            PIC X     VALUE SPACE.
           05  FLOG-TIME         PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  FLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' 2='.
           05  FLOG-RESP2        PIC XX    VALUE '--'.
       01  WS-QLOG.
           05  QLOG-TAG          PIC X(3)  VALUE SPACES.
           05  QLOG-TEXT         PIC X(12) VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  QLOG-RESP         PIC 99    VALUE 0.
       01  WS-ALOG.
           05  ALOG-TAG          PIC X(3)  VALUE 'A1 '.
           05  ALOG-TEXT         PIC X(12) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           IF EIBTRNID = 'HC52'
               PERFORM ASIS-PARA
           ELSE
               EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
               END-EXEC
               MOVE WS-INPUT(6:1) TO WS-MODE
               EVALUATE WS-MODE
                   WHEN 'F'
                       PERFORM FORMAT-PARA
                   WHEN 'Q'
                       PERFORM READQ-PARA
                   WHEN 'A'
                       PERFORM SHOW-PARA
               END-EVALUATE
           END-IF
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       FORMAT-PARA.
           EXEC CICS ASKTIME NOHANDLE
           END-EXEC
           EXEC CICS ASKTIME ABSTIME(WS-ABS) NOHANDLE
           END-EXEC
           EXEC CICS FORMATTIME ABSTIME(WS-ABS)
                     DDMMYYYY(WS-DATE) DATESEP('/')
                     TIME(WS-TIME) TIMESEP(':')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'F1 ' TO FLOG-TAG
           MOVE WS-DATE TO FLOG-DATE
           MOVE WS-TIME TO FLOG-TIME
           MOVE WS-RESP TO FLOG-RESP
           MOVE '--' TO FLOG-RESP2
           PERFORM LOG-F
           MOVE -1 TO WS-ABS
           EXEC CICS FORMATTIME ABSTIME(WS-ABS)
                     DDMMYYYY(WS-DATE) DATESEP('/')
                     TIME(WS-TIME) TIMESEP(':')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'F2 ' TO FLOG-TAG
           MOVE SPACES TO FLOG-DATE
           MOVE SPACES TO FLOG-TIME
           MOVE WS-RESP TO FLOG-RESP
           MOVE WS-RESP2 TO WS-R-D
           MOVE WS-R-D TO FLOG-RESP2
           PERFORM LOG-F.
       LOG-F.
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-FLOG)
                     LENGTH(32)
           END-EXEC.
       READQ-PARA.
           EXEC CICS WRITEQ TS QUEUE('HCQ') FROM(WS-QAREA)
                     LENGTH(20)
           END-EXEC
           EXEC CICS WRITEQ TS QUEUE('HCQ') FROM(WS-QSHORT)
                     LENGTH(12)
           END-EXEC
           MOVE 1 TO WS-ITEM
           MOVE SPACES TO WS-SMALL
           EXEC CICS READQ TS QUEUE('HCQ') INTO(WS-SMALL)
                     LENGTH(LENGTH OF WS-SMALL) ITEM(WS-ITEM)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'Q1 ' TO QLOG-TAG
           MOVE WS-SMALL TO QLOG-TEXT
           MOVE WS-RESP TO QLOG-RESP
           PERFORM LOG-Q
           MOVE 2 TO WS-ITEM
           MOVE SPACES TO WS-SMALL
           EXEC CICS READQ TS QUEUE('HCQ') INTO(WS-SMALL)
                     LENGTH(LENGTH OF WS-SMALL) ITEM(WS-ITEM)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'Q2 ' TO QLOG-TAG
           MOVE WS-SMALL TO QLOG-TEXT
           MOVE WS-RESP TO QLOG-RESP
           PERFORM LOG-Q.
       LOG-Q.
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-QLOG)
                     LENGTH(20)
           END-EXEC.
       SHOW-PARA.
           MOVE LOW-VALUES TO HCM1O
           EXEC CICS SEND MAP('HCM1') MAPSET('HCSET1') FROM(HCM1O)
                     ERASE
           END-EXEC
           EXEC CICS RETURN TRANSID('HC52')
           END-EXEC.
       ASIS-PARA.
           MOVE LOW-VALUES TO HCM1I
           EXEC CICS RECEIVE MAP('HCM1') MAPSET('HCSET1')
                     INTO(HCM1I) ASIS
           END-EXEC
           MOVE NAMEI TO ALOG-TEXT
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-ALOG)
                     LENGTH(15)
           END-EXEC.
