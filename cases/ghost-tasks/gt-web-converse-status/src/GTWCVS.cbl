       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWCVS.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-web-converse-status           *
      * Original program (Apache-2.0).                                *
      * GT86, a terminal task, as an HTTP client that reads the       *
      * whole status line and content type of a response. The         *
      * operator types GT86 A, GT86 B or GT86 C; each names a         *
      * different host. The program                                   *
      *   WEB OPENs a connection to that host (HTTP, default port),   *
      *   WEB CONVERSEs: GET /gt/status, the body into a 32-byte      *
      *   area, TOLENGTH and STATUSCODE returned, the reason phrase   *
      *   into a 19-byte area (STATUSLEN 19), the media type into a   *
      *   56-byte area (MEDIATYPE),                                   *
      *   WEB CLOSEs the connection,                                  *
      * then SENDs TEXT of what came back:                            *
      *   S=<status> L=<tolength> T=<reason phrase> M=<media type>    *
      * The areas for the phrase and the media type start as blanks.  *
      * An unexpected RESP is shown as S=000.                         *
      *---------------------------------------------------------------*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-IN                   PIC X(20) VALUE SPACES.
       01  WS-INLEN                PIC S9(4) COMP VALUE 20.
       01  WS-RESP                 PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                PIC S9(8) COMP VALUE 0.
       01  WS-TOKEN                PIC X(8)  VALUE LOW-VALUES.
       01  WS-HOST                 PIC X(16) VALUE SPACES.
       01  WS-HLEN                 PIC S9(8) COMP VALUE 0.
       01  WS-PATH                 PIC X(10) VALUE '/gt/status'.
       01  WS-PLEN                 PIC S9(8) COMP VALUE 10.
       01  WS-BODY                 PIC X(32) VALUE SPACES.
       01  WS-MAX                  PIC S9(8) COMP VALUE 32.
       01  WS-TOLEN                PIC S9(8) COMP VALUE 0.
       01  WS-STATUS               PIC S9(4) COMP VALUE 0.
       01  WS-STEXT                PIC X(19) VALUE SPACES.
       01  WS-STLEN                PIC S9(8) COMP VALUE 19.
       01  WS-MTYPE                PIC X(56) VALUE SPACES.
       01  WS-OUT.
           05  FILLER              PIC X(7)  VALUE 'GT86 S='.
           05  OUT-S               PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' L='.
           05  OUT-L               PIC 99    VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' T='.
           05  OUT-T               PIC X(19) VALUE SPACES.
           05  FILLER              PIC X(3)  VALUE ' M='.
           05  OUT-M               PIC X(56) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-IN) LENGTH(WS-INLEN)
           END-EXEC
           IF WS-IN(6:1) = 'B'
               MOVE 'missing.example' TO WS-HOST
               MOVE 15 TO WS-HLEN
           ELSE
               IF WS-IN(6:1) = 'C'
                   MOVE 'busy.example' TO WS-HOST
                   MOVE 12 TO WS-HLEN
               ELSE
                   MOVE 'ok.example' TO WS-HOST
                   MOVE 10 TO WS-HLEN
               END-IF
           END-IF
           EXEC CICS WEB OPEN HOST(WS-HOST) HOSTLENGTH(WS-HLEN)
                     SCHEME(DFHVALUE(HTTP)) SESSTOKEN(WS-TOKEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           EXEC CICS WEB CONVERSE SESSTOKEN(WS-TOKEN)
                     PATH(WS-PATH) PATHLENGTH(WS-PLEN)
                     METHOD(DFHVALUE(GET))
                     INTO(WS-BODY) MAXLENGTH(WS-MAX) TOLENGTH(WS-TOLEN)
                     STATUSCODE(WS-STATUS)
                     STATUSTEXT(WS-STEXT) STATUSLEN(WS-STLEN)
                     MEDIATYPE(WS-MTYPE)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-RESP = DFHRESP(NORMAL)
               MOVE WS-STATUS TO OUT-S
               MOVE WS-TOLEN TO OUT-L
               MOVE WS-STEXT TO OUT-T
               MOVE WS-MTYPE TO OUT-M
           END-IF
           EXEC CICS WEB CLOSE SESSTOKEN(WS-TOKEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           EXEC CICS SEND TEXT FROM(WS-OUT) LENGTH(96)
                     ERASE FREEKB WAIT
           END-EXEC
           EXEC CICS RETURN END-EXEC.
