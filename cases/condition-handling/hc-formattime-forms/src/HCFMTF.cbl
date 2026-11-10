       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCFMTF.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-formattime-forms       *
      * Original program (Apache-2.0).                                *
      * HCFT reads its mode from the terminal input (HCFT D, T or L): *
      *   D  ASKTIME, then FORMATTIME in each of the ten date forms,  *
      *      with DATESEP('-'), DATESEP with no value, or no DATESEP  *
      *   T  ASKTIME, then FORMATTIME TIME (TIMESEP value / none /    *
      *      no value) and the six binary forms                       *
      *   L  a fixed ABSTIME (31 Dec 2028 23:59:59.999, a leap year): *
      *      date, day-of-year, time and binary forms                 *
      * Each result is a 13-byte item in TS queue HCLOG: tag (2), a   *
      * space, the value (10, padded); FORMATTIME is not an event.    *
      * The date and time areas are cleared after each result: CICS   *
      * writes only the form's own length.                            *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-ABS                PIC S9(15) COMP-3 VALUE 0.
       01  WS-DATE               PIC X(10) VALUE SPACES.
       01  WS-TIME               PIC X(8)  VALUE SPACES.
       01  WS-BIN                PIC S9(8) COMP VALUE 0.
       01  WS-NUM                PIC 9(8)  VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-LOG.
           05  LOG-TAG           PIC XX    VALUE SPACES.
           05  FILLER            PIC X     VALUE SPACE.
           05  LOG-VAL           PIC X(10) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'D'
                   PERFORM DATE-PARA
               WHEN 'T'
                   PERFORM TIME-PARA
               WHEN 'L'
                   PERFORM LEAP-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       DATE-PARA.
           EXEC CICS ASKTIME ABSTIME(WS-ABS)
           END-EXEC
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) YYYYMMDD(WS-DATE)
           END-EXEC
           MOVE 'D1' TO LOG-TAG
           PERFORM LOG-DATE
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) MMDDYYYY(WS-DATE)
                     DATESEP('-')
           END-EXEC
           MOVE 'D2' TO LOG-TAG
           PERFORM LOG-DATE
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) DDMMYYYY(WS-DATE)
                     DATESEP('.')
           END-EXEC
           MOVE 'D3' TO LOG-TAG
           PERFORM LOG-DATE
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) YYMMDD(WS-DATE)
                     DATESEP
           END-EXEC
           MOVE 'D4' TO LOG-TAG
           PERFORM LOG-DATE
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) MMDDYY(WS-DATE)
           END-EXEC
           MOVE 'D5' TO LOG-TAG
           PERFORM LOG-DATE
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) DDMMYY(WS-DATE)
                     DATESEP('-')
           END-EXEC
           MOVE 'D6' TO LOG-TAG
           PERFORM LOG-DATE
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) YYDDD(WS-DATE)
           END-EXEC
           MOVE 'D7' TO LOG-TAG
           PERFORM LOG-DATE
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) YYYYDDD(WS-DATE)
                     DATESEP('-')
           END-EXEC
           MOVE 'D8' TO LOG-TAG
           PERFORM LOG-DATE
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) YYDDMM(WS-DATE)
                     DATESEP('.')
           END-EXEC
           MOVE 'D9' TO LOG-TAG
           PERFORM LOG-DATE
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) YYYYDDMM(WS-DATE)
           END-EXEC
           MOVE 'DA' TO LOG-TAG
           PERFORM LOG-DATE.
       TIME-PARA.
           EXEC CICS ASKTIME ABSTIME(WS-ABS)
           END-EXEC
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) TIME(WS-TIME)
           END-EXEC
           MOVE 'T1' TO LOG-TAG
           PERFORM LOG-TIME
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) TIME(WS-TIME)
                     TIMESEP('.')
           END-EXEC
           MOVE 'T2' TO LOG-TAG
           PERFORM LOG-TIME
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) TIME(WS-TIME)
                     TIMESEP
           END-EXEC
           MOVE 'T3' TO LOG-TAG
           PERFORM LOG-TIME
           PERFORM BIN-PARA.
       LEAP-PARA.
           MOVE 4070908799999 TO WS-ABS
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) MMDDYYYY(WS-DATE)
                     DATESEP('/')
           END-EXEC
           MOVE 'L1' TO LOG-TAG
           PERFORM LOG-DATE
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) YYYYDDD(WS-DATE)
           END-EXEC
           MOVE 'L2' TO LOG-TAG
           PERFORM LOG-DATE
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) YYDDD(WS-DATE)
                     DATESEP('-')
           END-EXEC
           MOVE 'L3' TO LOG-TAG
           PERFORM LOG-DATE
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) TIME(WS-TIME)
                     TIMESEP(':')
           END-EXEC
           MOVE 'L4' TO LOG-TAG
           PERFORM LOG-TIME
           PERFORM BIN-PARA.
       BIN-PARA.
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) DAYCOUNT(WS-BIN)
           END-EXEC
           MOVE 'N1' TO LOG-TAG
           PERFORM LOG-BIN
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) DAYOFWEEK(WS-BIN)
           END-EXEC
           MOVE 'N2' TO LOG-TAG
           PERFORM LOG-BIN
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) DAYOFMONTH(WS-BIN)
           END-EXEC
           MOVE 'N3' TO LOG-TAG
           PERFORM LOG-BIN
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) MONTHOFYEAR(WS-BIN)
           END-EXEC
           MOVE 'N4' TO LOG-TAG
           PERFORM LOG-BIN
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) YEAR(WS-BIN)
           END-EXEC
           MOVE 'N5' TO LOG-TAG
           PERFORM LOG-BIN
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) MILLISECONDS(WS-BIN)
           END-EXEC
           MOVE 'N6' TO LOG-TAG
           PERFORM LOG-BIN.
       LOG-DATE.
           MOVE WS-DATE TO LOG-VAL
           MOVE SPACES TO WS-DATE
           PERFORM LOG-WRITE.
       LOG-TIME.
           MOVE WS-TIME TO LOG-VAL
           MOVE SPACES TO WS-TIME
           PERFORM LOG-WRITE.
       LOG-BIN.
           MOVE WS-BIN TO WS-NUM
           MOVE WS-NUM TO LOG-VAL
           PERFORM LOG-WRITE.
       LOG-WRITE.
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG)
                     LENGTH(13)
           END-EXEC.
