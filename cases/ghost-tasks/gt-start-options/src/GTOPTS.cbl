       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTOPTS.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-start-options                 *
      * Original program (Apache-2.0).                                *
      * Starts background (non-terminal) GT22 / GT23 tasks with the   *
      * START options gt-start-retrieve leaves out. Modes typed after *
      * the transid:                                                  *
      *   D  FROM data with RTRANSID, RTERMID and QUEUE (GT22)        *
      *   E  FROM data only: GT22 asks for RTRANSID too (ENVDEFERR)   *
      *   N  RTRANSID only, no FROM: GT23 RETRIEVEs with no INTO      *
      *   A  AFTER MINUTES(1); AFTER 0 h 0 m 30 s; AT 10:45; and      *
      *      TIME(250000), 01:00 tomorrow                             *
      *   V  four STARTs out of range: INVREQ with RESP2 6, 5, 6, 4   *
      *   I  the same REQID twice with FROM: the second is IOERR      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-MSG                PIC X(20) VALUE 'ORDER 0021 READY'.
       01  WS-MSG2               PIC X(20) VALUE 'ORDER 0022 AGAIN'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-SLOG.
           05  FILLER            PIC X(2)  VALUE 'S='.
           05  SLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X     VALUE '/'.
           05  SLOG-RESP2        PIC 99    VALUE 0.
       01  WS-TEXT               PIC X(20) VALUE 'STARTS ISSUED'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'D'
                   EXEC CICS START TRANSID('GT22') INTERVAL(0)
                             FROM(WS-MSG) LENGTH(20)
                             RTRANSID('GT21') RTERMID('T001')
                             QUEUE('GTQUEUE1')
                   END-EXEC
               WHEN 'E'
                   EXEC CICS START TRANSID('GT22') INTERVAL(0)
                             FROM(WS-MSG) LENGTH(20)
                   END-EXEC
               WHEN 'N'
                   EXEC CICS START TRANSID('GT23') INTERVAL(0)
                             RTRANSID('GT21')
                   END-EXEC
               WHEN 'A'
                   EXEC CICS START TRANSID('GT23') AFTER MINUTES(1)
                             RTRANSID('AFT1')
                   END-EXEC
                   EXEC CICS START TRANSID('GT23') AFTER HOURS(0)
                             MINUTES(0) SECONDS(30) RTRANSID('AFT2')
                   END-EXEC
                   EXEC CICS START TRANSID('GT23') AT HOURS(10)
                             MINUTES(45) RTRANSID('AT01')
                   END-EXEC
                   EXEC CICS START TRANSID('GT23') TIME(250000)
                             RTRANSID('TOMO')
                   END-EXEC
               WHEN 'V'
                   EXEC CICS START TRANSID('GT23') INTERVAL(70)
                             RESP(WS-RESP) RESP2(WS-RESP2)
                   END-EXEC
                   PERFORM LOG-START
                   EXEC CICS START TRANSID('GT23') AFTER HOURS(1)
                             MINUTES(60) RESP(WS-RESP) RESP2(WS-RESP2)
                   END-EXEC
                   PERFORM LOG-START
                   EXEC CICS START TRANSID('GT23')
                             AFTER SECONDS(360000)
                             RESP(WS-RESP) RESP2(WS-RESP2)
                   END-EXEC
                   PERFORM LOG-START
                   EXEC CICS START TRANSID('GT23') AFTER HOURS(100)
                             RESP(WS-RESP) RESP2(WS-RESP2)
                   END-EXEC
                   PERFORM LOG-START
               WHEN 'I'
                   EXEC CICS START TRANSID('GT23') INTERVAL(30)
                             REQID('GTR00001') FROM(WS-MSG) LENGTH(20)
                             RTRANSID('REQ1') RESP(WS-RESP)
                   END-EXEC
                   PERFORM LOG-START
                   EXEC CICS START TRANSID('GT23') INTERVAL(30)
                             REQID('GTR00001') FROM(WS-MSG2) LENGTH(20)
                             RTRANSID('REQ2') RESP(WS-RESP)
                   END-EXEC
                   PERFORM LOG-START
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-TEXT) LENGTH(20) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       LOG-START.
           MOVE WS-RESP TO SLOG-RESP
           MOVE WS-RESP2 TO SLOG-RESP2
           EXEC CICS WRITEQ TS QUEUE('GTSLOG') FROM(WS-SLOG)
                     LENGTH(7)
           END-EXEC.
