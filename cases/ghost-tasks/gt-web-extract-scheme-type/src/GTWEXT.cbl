       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWEXT.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-web-extract-scheme-type       *
      * Original program (Apache-2.0).                                *
      * The user application program of the SERVER URIMAP EXTURI     *
      * (alias transaction GT87). For every request it issues five    *
      * WEB EXTRACTs, none of which reads a piece of the request that *
      * the case does not state:                                      *
      *   1. SCHEME and REQUESTTYPE together: each CVDA is compared   *
      *      with the 88-levels for HTTP (1096) / HTTPYES (1033)     *
      *      (DFHVALUE is not stubbed outside a command) and shown   *
      *      as Y or N, never as a number,                           *
      *   2. HTTPVERSION with VERSIONLEN 0,                           *
      *   3. PATH with PATHLENGTH 0,                                  *
      *   4. HOST with HOSTLENGTH 0,                                  *
      *   5. HTTPVERSION with VERSIONLEN 10 (RESP only: the version   *
      *      text is not stated by the case and is not shown),        *
      * then WEB SENDs one 56-byte line of the RESP / RESP2 values.   *
      * WEB EXTRACT is not an event: the response is the breadcrumb.  *
      *---------------------------------------------------------------*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SCH                  PIC S9(8) COMP VALUE 0.
           88  SCH-HTTP            VALUE 1096.
       01  WS-RTY                  PIC S9(8) COMP VALUE 0.
           88  RTY-HTTPYES         VALUE 1033.
       01  WS-VER                  PIC X(10) VALUE SPACES.
       01  WS-VLEN                 PIC S9(8) COMP VALUE 0.
       01  WS-PATH                 PIC X(256) VALUE SPACES.
       01  WS-PLEN                 PIC S9(8) COMP VALUE 0.
       01  WS-HOST                 PIC X(116) VALUE SPACES.
       01  WS-HLEN                 PIC S9(8) COMP VALUE 0.
       01  WS-RESP                 PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                PIC S9(8) COMP VALUE 0.
       01  WS-STAT                 PIC X(2)  VALUE 'OK'.
       01  WS-OUT.
           05  FILLER              PIC X(2)  VALUE 'S='.
           05  OUT-S               PIC X     VALUE 'N'.
           05  FILLER              PIC X(3)  VALUE ' R='.
           05  OUT-R               PIC X     VALUE 'N'.
           05  FILLER              PIC X(3)  VALUE ' E='.
           05  OUT-E1              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-E2              PIC 999   VALUE 0.
           05  FILLER              PIC X(4)  VALUE ' V0='.
           05  OUT-V1              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-V2              PIC 999   VALUE 0.
           05  FILLER              PIC X(4)  VALUE ' P0='.
           05  OUT-P1              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-P2              PIC 999   VALUE 0.
           05  FILLER              PIC X(4)  VALUE ' H0='.
           05  OUT-H1              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-H2              PIC 999   VALUE 0.
           05  FILLER              PIC X(4)  VALUE ' VN='.
           05  OUT-N1              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-N2              PIC 999   VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS WEB EXTRACT SCHEME(WS-SCH) REQUESTTYPE(WS-RTY)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-E1
           MOVE WS-RESP2 TO OUT-E2
           IF WS-RESP = 0
               IF SCH-HTTP
                   MOVE 'Y' TO OUT-S
               END-IF
               IF RTY-HTTPYES
                   MOVE 'Y' TO OUT-R
               END-IF
           END-IF
           MOVE 0 TO WS-VLEN
           EXEC CICS WEB EXTRACT HTTPVERSION(WS-VER)
                     VERSIONLEN(WS-VLEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-V1
           MOVE WS-RESP2 TO OUT-V2
           MOVE 0 TO WS-PLEN
           EXEC CICS WEB EXTRACT PATH(WS-PATH) PATHLENGTH(WS-PLEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-P1
           MOVE WS-RESP2 TO OUT-P2
           MOVE 0 TO WS-HLEN
           EXEC CICS WEB EXTRACT HOST(WS-HOST) HOSTLENGTH(WS-HLEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-H1
           MOVE WS-RESP2 TO OUT-H2
           MOVE 10 TO WS-VLEN
           EXEC CICS WEB EXTRACT HTTPVERSION(WS-VER)
                     VERSIONLEN(WS-VLEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-N1
           MOVE WS-RESP2 TO OUT-N2
           EXEC CICS WEB SEND FROM(WS-OUT) FROMLENGTH(56)
                     MEDIATYPE('text/plain')
                     STATUSCODE(200) STATUSTEXT(WS-STAT) STATUSLEN(2)
                     SRVCONVERT CHARACTERSET('iso-8859-1')
                     HOSTCODEPAGE('037')
           END-EXEC
           EXEC CICS RETURN END-EXEC.
