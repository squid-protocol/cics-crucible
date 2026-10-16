       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWRECV.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-web-server-receive            *
      * Original program (Apache-2.0).                                *
      * The user application program of the SERVER URIMAP RECVURI     *
      * (alias transaction GT82). For every request it                *
      *   WEB RECEIVEs the body into an 8-byte buffer (MAXLENGTH 8),  *
      *   WEB EXTRACTs the method, host, path and query string, and   *
      *   WEB READs the HTTP header X-Crucible-Tag,                   *
      * then WEB SENDs one 107-byte line of everything it saw. WEB    *
      * EXTRACT and WEB READ HTTPHEADER are not events: they touch    *
      * only the program's storage, so the response is the           *
      * breadcrumb. The leading slash of PATH and the question mark   *
      * of QUERYSTRING are dropped if present, and no length         *
      * written by EXTRACT or READ HTTPHEADER is logged: IBM does not *
      * say whether they count.                                       *
      *---------------------------------------------------------------*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-IN                   PIC X(8)  VALUE SPACES.
       01  WS-LEN                  PIC S9(8) COMP VALUE 0.
       01  WS-MAX                  PIC S9(8) COMP VALUE 8.
       01  WS-RESP                 PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                PIC S9(8) COMP VALUE 0.
       01  WS-METH                 PIC X(8)  VALUE SPACES.
       01  WS-MLEN                 PIC S9(8) COMP VALUE 8.
       01  WS-HOST                 PIC X(116) VALUE SPACES.
       01  WS-HLEN                 PIC S9(8) COMP VALUE 116.
       01  WS-PATH                 PIC X(256) VALUE SPACES.
       01  WS-PLEN                 PIC S9(8) COMP VALUE 256.
       01  WS-QRY                  PIC X(256) VALUE SPACES.
       01  WS-QLEN                 PIC S9(8) COMP VALUE 256.
       01  WS-TAG                  PIC X(10) VALUE SPACES.
       01  WS-TLEN                 PIC S9(8) COMP VALUE 10.
       01  WS-STAT                 PIC X(2)  VALUE 'OK'.
       01  WS-OUT.
           05  FILLER              PIC X(4)  VALUE 'RCV='.
           05  OUT-RR              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-R2              PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' L='.
           05  OUT-LEN             PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' B='.
           05  OUT-BODY            PIC X(8)  VALUE SPACES.
           05  FILLER              PIC X(3)  VALUE ' M='.
           05  OUT-METH            PIC X(6)  VALUE SPACES.
           05  FILLER              PIC X(3)  VALUE ' H='.
           05  OUT-HOST            PIC X(20) VALUE SPACES.
           05  FILLER              PIC X(3)  VALUE ' P='.
           05  OUT-PATH            PIC X(10) VALUE SPACES.
           05  FILLER              PIC X(3)  VALUE ' Q='.
           05  OUT-QRY             PIC X(10) VALUE SPACES.
           05  FILLER              PIC X(3)  VALUE ' T='.
           05  OUT-TR              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-T2              PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' V='.
           05  OUT-TAG             PIC X(10) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS WEB RECEIVE INTO(WS-IN) LENGTH(WS-LEN)
                     MAXLENGTH(WS-MAX) SRVCONVERT
                     CHARACTERSET('iso-8859-1')
                     HOSTCODEPAGE('037')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-RR
           MOVE WS-RESP2 TO OUT-R2
           MOVE WS-LEN TO OUT-LEN
           MOVE WS-IN TO OUT-BODY
           EXEC CICS WEB EXTRACT HTTPMETHOD(WS-METH)
                     METHODLENGTH(WS-MLEN)
                     HOST(WS-HOST) HOSTLENGTH(WS-HLEN)
                     PATH(WS-PATH) PATHLENGTH(WS-PLEN)
                     QUERYSTRING(WS-QRY) QUERYSTRLEN(WS-QLEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-METH(1:6) TO OUT-METH
           MOVE WS-HOST(1:20) TO OUT-HOST
           IF WS-PATH(1:1) = '/'
               MOVE WS-PATH(2:10) TO OUT-PATH
           ELSE
               MOVE WS-PATH(1:10) TO OUT-PATH
           END-IF
           IF WS-QRY(1:1) = '?'
               MOVE WS-QRY(2:10) TO OUT-QRY
           ELSE
               MOVE WS-QRY(1:10) TO OUT-QRY
           END-IF
           EXEC CICS WEB READ HTTPHEADER('X-Crucible-Tag')
                     NAMELENGTH(14)
                     VALUE(WS-TAG) VALUELENGTH(WS-TLEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-TR
           MOVE WS-RESP2 TO OUT-T2
           IF WS-RESP = 0
               MOVE WS-TAG TO OUT-TAG
           END-IF
           EXEC CICS WEB SEND FROM(WS-OUT) FROMLENGTH(107)
                     MEDIATYPE('text/plain')
                     STATUSCODE(200) STATUSTEXT(WS-STAT) STATUSLEN(2)
                     SRVCONVERT CHARACTERSET('iso-8859-1')
                     HOSTCODEPAGE('037')
           END-EXEC
           EXEC CICS RETURN END-EXEC.
