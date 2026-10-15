       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTHECHO.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-http-inbound                  *
      * Original program (Apache-2.0).                                *
      * The user application program of the SERVER URIMAP ECHOURI     *
      * (alias transaction GT81): WEB RECEIVE the request body, WEB   *
      * SEND it back after the five characters ECHO:, status 200.     *
      * Body and response are converted between ISO-8859-1 (the      *
      * client) and code page 037 (the host) by CICS, stated on both  *
      * commands so that no default is relied on.                     *
      *---------------------------------------------------------------*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-IN                   PIC X(32) VALUE SPACES.
       01  WS-LEN                  PIC S9(8) COMP VALUE 0.
       01  WS-MAX                  PIC S9(8) COMP VALUE 32.
       01  WS-OUT                  PIC X(40) VALUE 'ECHO:'.
       01  WS-OUTLEN               PIC S9(8) COMP VALUE 0.
       01  WS-STAT                 PIC X(2)  VALUE 'OK'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS WEB RECEIVE INTO(WS-IN) LENGTH(WS-LEN)
                     MAXLENGTH(WS-MAX) SRVCONVERT
                     CHARACTERSET('iso-8859-1')
                     HOSTCODEPAGE('037')
           END-EXEC
           MOVE WS-IN(1:WS-LEN) TO WS-OUT(6:WS-LEN)
           COMPUTE WS-OUTLEN = WS-LEN + 5
           EXEC CICS WEB SEND FROM(WS-OUT) FROMLENGTH(WS-OUTLEN)
                     MEDIATYPE('text/plain')
                     STATUSCODE(200) STATUSTEXT(WS-STAT) STATUSLEN(2)
                     SRVCONVERT CHARACTERSET('iso-8859-1')
                     HOSTCODEPAGE('037')
           END-EXEC
           EXEC CICS RETURN END-EXEC.
