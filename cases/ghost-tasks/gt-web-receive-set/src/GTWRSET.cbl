       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWRSET.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-web-receive-set               *
      * Original program (Apache-2.0).                                *
      * The user application program of the SERVER URIMAP RSETURI     *
      * (alias transaction GT87). For every request it                *
      *   WEB RECEIVEs the body with SET (CICS acquires the storage), *
      *   asks for the request's media type (MEDIATYPE) and says      *
      *   NOSRVCONVERT, then reads the body through the pointer, and  *
      *   WEB SENDs one 37-byte line of what it saw. The only event   *
      *   besides the SEND is the RECEIVE itself, so the response is  *
      *   the breadcrumb. Only the first LENGTH bytes (at most 8) of  *
      *   the body are read, and only the first 10 bytes of the       *
      *   media type are logged: IBM does not say what the rest of    *
      *   either area holds.                                          *
      *---------------------------------------------------------------*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PTR                  USAGE POINTER.
       01  WS-LEN                  PIC S9(8) COMP VALUE 0.
       01  WS-N                    PIC S9(8) COMP VALUE 0.
       01  WS-MT                   PIC X(56) VALUE SPACES.
       01  WS-RESP                 PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                PIC S9(8) COMP VALUE 0.
       01  WS-STAT                 PIC X(2)  VALUE 'OK'.
       01  WS-OUT.
           05  FILLER              PIC X(4)  VALUE 'RCV='.
           05  OUT-RR              PIC 99    VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' L='.
           05  OUT-LEN             PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' B='.
           05  OUT-BODY            PIC X(8)  VALUE SPACES.
           05  FILLER              PIC X(4)  VALUE ' MT='.
           05  OUT-MT              PIC X(10) VALUE SPACES.
       LINKAGE SECTION.
       01  LS-BODY                 PIC X(8).
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS WEB RECEIVE SET(WS-PTR) LENGTH(WS-LEN)
                     MEDIATYPE(WS-MT) NOSRVCONVERT
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-RR
           MOVE WS-LEN TO OUT-LEN
           MOVE WS-MT(1:10) TO OUT-MT
           IF WS-LEN > 8
              MOVE 8 TO WS-N
           ELSE
              MOVE WS-LEN TO WS-N
           END-IF
           SET ADDRESS OF LS-BODY TO WS-PTR
           MOVE LS-BODY(1:WS-N) TO OUT-BODY(1:WS-N)
           EXEC CICS WEB SEND FROM(WS-OUT) FROMLENGTH(37)
                     MEDIATYPE('text/plain')
                     STATUSCODE(200) STATUSTEXT(WS-STAT) STATUSLEN(2)
                     SRVCONVERT CHARACTERSET('iso-8859-1')
                     HOSTCODEPAGE('037')
           END-EXEC
           EXEC CICS RETURN END-EXEC.
