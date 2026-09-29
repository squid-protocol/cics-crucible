       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTSTART.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-start-retrieve                *
      * Original program (Apache-2.0).                                *
      * Starts background (non-terminal) GT02 tasks. Modes typed      *
      * after the transid:                                            *
      *   A  INTERVAL(0) with FROM data                               *
      *   N  INTERVAL(0) without data  (RETRIEVE gets ENDDATA)        *
      *   T  TIME(103000) and TIME(093000) at 10:00 (the second is    *
      *      in the past, within six hours: it expires at once)       *
      *   L  30 bytes of FROM data for a 20-byte RETRIEVE area        *
      *   X  one START, one START PROTECT, then an ABEND              *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-MSG                PIC X(20) VALUE 'ORDER 0001 READY'.
       01  WS-MSG2               PIC X(20) VALUE 'ORDER 0002 LATE'.
       01  WS-LONG               PIC X(30)
                                 VALUE 'THIRTY BYTE PAYLOAD 0123456789'.
       01  WS-UNPROT             PIC X(20) VALUE 'UNPROTECTED START'.
       01  WS-PROT               PIC X(20) VALUE 'PROTECTED START'.
       01  WS-TEXT               PIC X(20) VALUE 'STARTS ISSUED'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'A'
                   EXEC CICS START TRANSID('GT02') INTERVAL(0)
                             FROM(WS-MSG) LENGTH(20)
                   END-EXEC
               WHEN 'N'
                   EXEC CICS START TRANSID('GT02') INTERVAL(0)
                   END-EXEC
               WHEN 'T'
                   EXEC CICS START TRANSID('GT02') TIME(103000)
                             FROM(WS-MSG) LENGTH(20)
                   END-EXEC
                   EXEC CICS START TRANSID('GT02') TIME(093000)
                             FROM(WS-MSG2) LENGTH(20)
                   END-EXEC
               WHEN 'L'
                   EXEC CICS START TRANSID('GT02') INTERVAL(0)
                             FROM(WS-LONG) LENGTH(30)
                   END-EXEC
               WHEN 'X'
                   EXEC CICS START TRANSID('GT02') INTERVAL(0)
                             FROM(WS-UNPROT) LENGTH(20)
                   END-EXEC
                   EXEC CICS START TRANSID('GT02') INTERVAL(0)
                             FROM(WS-PROT) LENGTH(20) PROTECT
                   END-EXEC
                   EXEC CICS ABEND ABCODE('GTAB') END-EXEC
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-TEXT) LENGTH(20) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
