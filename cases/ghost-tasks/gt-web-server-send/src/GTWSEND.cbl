       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWSEND.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-web-server-send               *
      * Original program (Apache-2.0).                                *
      * The user application program of the SERVER URIMAP SENDURI     *
      * (alias transaction GT83). For every request it                *
      *   WEB READs the HTTP header X-Crucible-Code (the status code  *
      *   to answer with: 200, 201 or 404),                           *
      *   WEB EXTRACTs the query string (the body of the response),   *
      *   WEB WRITEs the response header X-Crucible-Reply, then       *
      *   WEB SENDs the body with that status, its reason phrase and  *
      *   its media type, ACTION(IMMEDIATE).                          *
      * If the request also carries X-Crucible-Again it WEB SENDs a   *
      * second response, which IBM says is an error after an          *
      * IMMEDIATE first one. The reason phrase and media type come    *
      * from the code here, so no length written back by a WEB        *
      * command is used. A leading question mark of QUERYSTRING is    *
      * dropped if present.                                           *
      *---------------------------------------------------------------*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RESP                 PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                PIC S9(8) COMP VALUE 0.
       01  WS-CODE-X               PIC X(3)  VALUE SPACES.
       01  WS-CODE-N               PIC 9(3)  VALUE 0.
       01  WS-CODE                 PIC S9(4) COMP VALUE 200.
       01  WS-AGAIN                PIC X     VALUE SPACE.
       01  WS-QRY                  PIC X(256) VALUE SPACES.
       01  WS-QLEN                 PIC S9(8) COMP VALUE 256.
       01  WS-OUT                  PIC X(20) VALUE SPACES.
       01  WS-STAT                 PIC X(9)  VALUE SPACES.
       01  WS-SLEN                 PIC S9(8) COMP VALUE 2.
       01  WS-MT                   PIC X(56) VALUE SPACES.
       01  WS-RPLY.
           05  FILLER              PIC X(6)  VALUE 'reply-'.
           05  RPLY-CODE           PIC X(3)  VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS WEB READ HTTPHEADER('X-Crucible-Code')
                     NAMELENGTH(15)
                     VALUE(WS-CODE-X) VALUELENGTH(3)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-CODE-X IS NUMERIC
               MOVE WS-CODE-X TO WS-CODE-N
               MOVE WS-CODE-N TO WS-CODE
           END-IF
           MOVE WS-CODE-X TO RPLY-CODE
           EVALUATE WS-CODE
               WHEN 201
                   MOVE 'Created' TO WS-STAT
                   MOVE 7 TO WS-SLEN
                   MOVE 'application/json' TO WS-MT
               WHEN 404
                   MOVE 'Not Found' TO WS-STAT
                   MOVE 9 TO WS-SLEN
                   MOVE 'text/plain' TO WS-MT
               WHEN OTHER
                   MOVE 'OK' TO WS-STAT
                   MOVE 2 TO WS-SLEN
                   MOVE 'text/plain' TO WS-MT
           END-EVALUATE
           EXEC CICS WEB READ HTTPHEADER('X-Crucible-Again')
                     NAMELENGTH(16)
                     VALUE(WS-AGAIN) VALUELENGTH(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-RESP NOT = 0
               MOVE SPACE TO WS-AGAIN
           END-IF
           EXEC CICS WEB EXTRACT QUERYSTRING(WS-QRY)
                     QUERYSTRLEN(WS-QLEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-QRY(1:1) = '?'
               MOVE WS-QRY(2:20) TO WS-OUT
           ELSE
               MOVE WS-QRY(1:20) TO WS-OUT
           END-IF
           EXEC CICS WEB WRITE HTTPHEADER('X-Crucible-Reply')
                     NAMELENGTH(16)
                     VALUE(WS-RPLY) VALUELENGTH(9)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           EXEC CICS WEB SEND FROM(WS-OUT) FROMLENGTH(20)
                     MEDIATYPE(WS-MT)
                     STATUSCODE(WS-CODE) STATUSTEXT(WS-STAT)
                     STATUSLEN(WS-SLEN)
                     ACTION(DFHVALUE(IMMEDIATE))
                     SRVCONVERT CHARACTERSET('iso-8859-1')
                     HOSTCODEPAGE('037')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-AGAIN = 'Y'
               EXEC CICS WEB SEND FROM(WS-OUT) FROMLENGTH(20)
                         MEDIATYPE(WS-MT)
                         STATUSCODE(WS-CODE) STATUSTEXT(WS-STAT)
                         STATUSLEN(WS-SLEN)
                         ACTION(DFHVALUE(IMMEDIATE))
                         SRVCONVERT CHARACTERSET('iso-8859-1')
                         HOSTCODEPAGE('037')
                         RESP(WS-RESP) RESP2(WS-RESP2)
               END-EXEC
           END-IF
           EXEC CICS RETURN END-EXEC.
