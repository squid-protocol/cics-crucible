       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWCLI.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-web-client                    *
      * Original program (Apache-2.0).                                *
      * GT85, a terminal task, as an HTTP client. The operator types  *
      * GT85 A or GT85 B; A names host orders.example, B names host   *
      * gone.example. The program                                     *
      *   WEB OPENs a connection to that host (HTTP, default port),   *
      *   WEB CONVERSEs: GET /gt/item, the body into a 32-byte area   *
      *   (MAXLENGTH 32), the status code and TOLENGTH returned,      *
      *   WEB CLOSEs the connection,                                  *
      * then SENDs TEXT of what came back: S=<status> L=<tolength>    *
      * <body>. The session token is kept in an 8-byte area and is    *
      * never shown. An unexpected RESP is shown as S=000.            *
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
       01  WS-PATH                 PIC X(8)  VALUE '/gt/item'.
       01  WS-PLEN                 PIC S9(8) COMP VALUE 8.
       01  WS-BODY                 PIC X(32) VALUE SPACES.
       01  WS-MAX                  PIC S9(8) COMP VALUE 32.
       01  WS-TOLEN                PIC S9(8) COMP VALUE 0.
       01  WS-STATUS               PIC S9(4) COMP VALUE 0.
       01  WS-OUT.
           05  FILLER              PIC X(7)  VALUE 'GT85 S='.
           05  OUT-S               PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' L='.
           05  OUT-L               PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE SPACE.
           05  OUT-B               PIC X(32) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-IN) LENGTH(WS-INLEN)
           END-EXEC
           IF WS-IN(6:1) = 'B'
               MOVE 'gone.example' TO WS-HOST
               MOVE 12 TO WS-HLEN
           ELSE
               MOVE 'orders.example' TO WS-HOST
               MOVE 14 TO WS-HLEN
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
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-RESP = DFHRESP(NORMAL)
               MOVE WS-STATUS TO OUT-S
               MOVE WS-TOLEN TO OUT-L
               MOVE WS-BODY TO OUT-B
           END-IF
           EXEC CICS WEB CLOSE SESSTOKEN(WS-TOKEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           EXEC CICS SEND TEXT FROM(WS-OUT) LENGTH(48)
                     ERASE FREEKB WAIT
           END-EXEC
           EXEC CICS RETURN END-EXEC.
