       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWPRT.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-web-open-port                 *
      * Original program (Apache-2.0).                                *
      * GT8P, a terminal task, as an HTTP client that names the port. *
      * The operator types GT8P A or GT8P B. A uses port 80, the HTTP *
      * default; B uses port 65536, one past the highest port. The    *
      * program                                                       *
      *   WEB OPENs host orders.example with PORTNUMBER(port),        *
      *   keeps RESP of the OPEN (RESP2 when it was not NORMAL),      *
      *   only if the OPEN was NORMAL: WEB CONVERSE GET /gt/item and  *
      *   WEB CLOSE,                                                  *
      * then SENDs TEXT: O=<resp> W=<resp2> S=<status> <body>.       *
      * The session token is kept in an 8-byte area, never shown.     *
      *---------------------------------------------------------------*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-IN                   PIC X(20) VALUE SPACES.
       01  WS-INLEN                PIC S9(4) COMP VALUE 20.
       01  WS-RESP                 PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                PIC S9(8) COMP VALUE 0.
       01  WS-TOKEN                PIC X(8)  VALUE LOW-VALUES.
       01  WS-HOST                 PIC X(14) VALUE 'orders.example'.
       01  WS-HLEN                 PIC S9(8) COMP VALUE 14.
       01  WS-PORT                 PIC S9(8) COMP VALUE 80.
       01  WS-PATH                 PIC X(8)  VALUE '/gt/item'.
       01  WS-PLEN                 PIC S9(8) COMP VALUE 8.
       01  WS-BODY                 PIC X(32) VALUE SPACES.
       01  WS-MAX                  PIC S9(8) COMP VALUE 32.
       01  WS-TOLEN                PIC S9(8) COMP VALUE 0.
       01  WS-STATUS               PIC S9(4) COMP VALUE 0.
       01  WS-OUT.
           05  FILLER              PIC X(7)  VALUE 'GT8P O='.
           05  OUT-O               PIC 99    VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' W='.
           05  OUT-W               PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' S='.
           05  OUT-S               PIC 999   VALUE 0.
           05  FILLER              PIC X     VALUE SPACE.
           05  OUT-B               PIC X(32) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-IN) LENGTH(WS-INLEN)
           END-EXEC
           IF WS-IN(6:1) = 'B'
               MOVE 65536 TO WS-PORT
           END-IF
           EXEC CICS WEB OPEN HOST(WS-HOST) HOSTLENGTH(WS-HLEN)
                     PORTNUMBER(WS-PORT)
                     SCHEME(DFHVALUE(HTTP)) SESSTOKEN(WS-TOKEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-O
           IF WS-RESP = DFHRESP(NORMAL)
               EXEC CICS WEB CONVERSE SESSTOKEN(WS-TOKEN)
                         PATH(WS-PATH) PATHLENGTH(WS-PLEN)
                         METHOD(DFHVALUE(GET))
                         INTO(WS-BODY) MAXLENGTH(WS-MAX)
                         TOLENGTH(WS-TOLEN) STATUSCODE(WS-STATUS)
                         RESP(WS-RESP) RESP2(WS-RESP2)
               END-EXEC
               MOVE WS-STATUS TO OUT-S
               MOVE WS-BODY TO OUT-B
               EXEC CICS WEB CLOSE SESSTOKEN(WS-TOKEN)
                         RESP(WS-RESP) RESP2(WS-RESP2)
               END-EXEC
           ELSE
               MOVE WS-RESP2 TO OUT-W
           END-IF
           EXEC CICS SEND TEXT FROM(WS-OUT) LENGTH(54)
                     ERASE FREEKB WAIT
           END-EXEC
           EXEC CICS RETURN END-EXEC.
