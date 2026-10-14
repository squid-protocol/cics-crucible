       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWPARS.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-web-parse-url                 *
      * Original program (Apache-2.0).                                *
      * GT71, a mode typed after the transid:                         *
      *   P  WEB PARSE URL of five well-formed URLs                   *
      *   E  WEB PARSE URL of two URLs IBM rejects (INVREQ)           *
      *   L  WEB PARSE URL with one output buffer too short at a time *
      *      (LENGERR)                                                *
      * Every result is a breadcrumb in TS queue GTWLOG (WEB PARSE    *
      * URL is not an event: it touches only the program's storage).  *
      * The leading slash of PATH and the leading question mark of    *
      * QUERYSTRING are not logged, and neither is PATHLENGTH or      *
      * QUERYSTRLEN: IBM does not say whether they count.             *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-URL                PIC X(64) VALUE SPACES.
       01  WS-ULEN               PIC S9(8) COMP VALUE 0.
       01  WS-SCHEME             PIC X(16) VALUE SPACES.
       01  WS-HOST               PIC X(116) VALUE SPACES.
       01  WS-HLEN               PIC S9(8) COMP VALUE 116.
       01  WS-PORT               PIC S9(8) COMP VALUE 0.
       01  WS-PATH               PIC X(256) VALUE SPACES.
       01  WS-PLEN               PIC S9(8) COMP VALUE 256.
       01  WS-QRY                PIC X(256) VALUE SPACES.
       01  WS-QLEN               PIC S9(8) COMP VALUE 256.
       01  WS-HIN                PIC S9(8) COMP VALUE 116.
       01  WS-PIN                PIC S9(8) COMP VALUE 256.
       01  WS-QIN                PIC S9(8) COMP VALUE 256.
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  CLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' S='.
           05  CLOG-RESP2        PIC 999   VALUE 0.
           05  FILLER            PIC X(5)  VALUE ' SCH='.
           05  CLOG-SCH          PIC X(5)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' P='.
           05  CLOG-PORT         PIC 9(5)  VALUE 0.
           05  FILLER            PIC X(4)  VALUE ' HL='.
           05  CLOG-HL           PIC 999   VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' H='.
           05  CLOG-HOST         PIC X(20) VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' P='.
           05  CLOG-PATH         PIC X(10) VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' Q='.
           05  CLOG-QRY          PIC X(10) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'P'
                   PERFORM PARSE-PARA
               WHEN 'E'
                   PERFORM ERROR-PARA
               WHEN 'L'
                   PERFORM LENGTH-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       PARSE-PARA.
           MOVE 'P1 ' TO CLOG-TAG
           MOVE 'https://example.com:8443/a/b?x=1&y=2' TO WS-URL
           MOVE 36 TO WS-ULEN
           PERFORM DO-PARSE
           MOVE 'P2 ' TO CLOG-TAG
           MOVE 'HtTp://example.org/docs?q=7' TO WS-URL
           MOVE 27 TO WS-ULEN
           PERFORM DO-PARSE
           MOVE 'P3 ' TO CLOG-TAG
           MOVE 'hTTps://example.net/s?k=v' TO WS-URL
           MOVE 25 TO WS-ULEN
           PERFORM DO-PARSE
           MOVE 'P4 ' TO CLOG-TAG
           MOVE 'http://192.0.2.7:8080/a?b=c' TO WS-URL
           MOVE 27 TO WS-ULEN
           PERFORM DO-PARSE
           MOVE 'P5 ' TO CLOG-TAG
           MOVE 'http://[2001:db8::1]:81/a?b=c' TO WS-URL
           MOVE 29 TO WS-ULEN
           PERFORM DO-PARSE.
       ERROR-PARA.
           MOVE 'E1 ' TO CLOG-TAG
           MOVE 'example.com/a?x=1' TO WS-URL
           MOVE 17 TO WS-ULEN
           PERFORM DO-PARSE
           MOVE 'E2 ' TO CLOG-TAG
           MOVE 'http://example.com/a%zz?x=1' TO WS-URL
           MOVE 27 TO WS-ULEN
           PERFORM DO-PARSE.
       LENGTH-PARA.
           MOVE 'http://example.com/a/b?x=1&y=2' TO WS-URL
           MOVE 30 TO WS-ULEN
           MOVE 'L1 ' TO CLOG-TAG
           MOVE 4 TO WS-HIN
           PERFORM DO-PARSE
           MOVE 116 TO WS-HIN
           MOVE 'L2 ' TO CLOG-TAG
           MOVE 1 TO WS-PIN
           PERFORM DO-PARSE
           MOVE 256 TO WS-PIN
           MOVE 'L3 ' TO CLOG-TAG
           MOVE 1 TO WS-QIN
           PERFORM DO-PARSE
           MOVE 256 TO WS-QIN.
       DO-PARSE.
           MOVE SPACES TO WS-SCHEME WS-HOST WS-PATH WS-QRY
           MOVE 0 TO WS-PORT
           MOVE WS-HIN TO WS-HLEN
           MOVE WS-PIN TO WS-PLEN
           MOVE WS-QIN TO WS-QLEN
           EXEC CICS WEB PARSE URL(WS-URL) URLLENGTH(WS-ULEN)
                     SCHEMENAME(WS-SCHEME)
                     HOST(WS-HOST) HOSTLENGTH(WS-HLEN)
                     PORTNUMBER(WS-PORT)
                     PATH(WS-PATH) PATHLENGTH(WS-PLEN)
                     QUERYSTRING(WS-QRY) QUERYSTRLEN(WS-QLEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE SPACES TO CLOG-SCH CLOG-HOST CLOG-PATH CLOG-QRY
           MOVE 0 TO CLOG-PORT CLOG-HL CLOG-RESP2
           MOVE WS-RESP TO CLOG-RESP
           IF WS-RESP = 0
               MOVE WS-SCHEME(1:5) TO CLOG-SCH
               MOVE WS-PORT TO CLOG-PORT
               MOVE WS-HLEN TO CLOG-HL
               MOVE WS-HOST(1:20) TO CLOG-HOST
               IF WS-PATH(1:1) = '/'
                   MOVE WS-PATH(2:10) TO CLOG-PATH
               ELSE
                   MOVE WS-PATH(1:10) TO CLOG-PATH
               END-IF
               IF WS-QRY(1:1) = '?'
                   MOVE WS-QRY(2:10) TO CLOG-QRY
               ELSE
                   MOVE WS-QRY(1:10) TO CLOG-QRY
               END-IF
           ELSE
               MOVE WS-RESP2 TO CLOG-RESP2
           END-IF
           EXEC CICS WRITEQ TS QUEUE('GTWLOG') FROM(WS-CLOG)
                     LENGTH(88)
           END-EXEC.
