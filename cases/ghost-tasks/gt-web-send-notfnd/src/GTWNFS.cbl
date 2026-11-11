       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWNFS.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-web-send-notfnd               *
      * Original program (Apache-2.0).                                *
      * The user application program of the SERVER URIMAP NFURI      *
      * (alias transaction GT89). For every request it                *
      *   WEB READs the HTTP header X-Crucible-Mode (1 or 2),         *
      *   mode 1: DOCUMENT CREATEs a document and WEB SENDs it with   *
      *           DOCTOKEN (NORMAL: the response);                    *
      *   mode 2: WEB SENDs DOCTOKEN of a document that was never     *
      *           created (the token is still LOW-VALUES): NOTFND,    *
      *           so nothing is sent; the program logs RESP and RESP2 *
      *           to TS queue GTNFLOG, then answers with a WEB SEND   *
      *           FROM, status 404.                                   *
      *---------------------------------------------------------------*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RESP                 PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                PIC S9(8) COMP VALUE 0.
       01  WS-MODE                 PIC X     VALUE SPACE.
       01  WS-TOKEN                PIC X(16) VALUE LOW-VALUES.
       01  WS-TXT                  PIC X(20) VALUE SPACES.
       01  WS-TLEN                 PIC S9(8) COMP VALUE 0.
       01  WS-MT                   PIC X(56) VALUE 'text/plain'.
       01  WS-CODE                 PIC S9(4) COMP VALUE 200.
       01  WS-STAT                 PIC X(9)  VALUE 'OK'.
       01  WS-SLEN                 PIC S9(8) COMP VALUE 2.
       01  WS-BODY                 PIC X(4)  VALUE 'gone'.
       01  WS-BLEN                 PIC S9(8) COMP VALUE 4.
       01  WS-LOG.
           05  FILLER              PIC X     VALUE 'M'.
           05  LOG-MODE            PIC X     VALUE SPACE.
           05  FILLER              PIC X(3)  VALUE ' R='.
           05  LOG-RESP            PIC 99    VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' E='.
           05  LOG-RESP2           PIC 9999  VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS WEB READ HTTPHEADER('X-Crucible-Mode')
                     NAMELENGTH(15)
                     VALUE(WS-MODE) VALUELENGTH(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-MODE = '1'
               MOVE 'alpha=111' TO WS-TXT
               MOVE 9 TO WS-TLEN
               EXEC CICS DOCUMENT CREATE DOCTOKEN(WS-TOKEN)
                         TEXT(WS-TXT) LENGTH(WS-TLEN)
                         RESP(WS-RESP)
               END-EXEC
           END-IF
           EXEC CICS WEB SEND DOCTOKEN(WS-TOKEN)
                     MEDIATYPE(WS-MT)
                     STATUSCODE(WS-CODE) STATUSTEXT(WS-STAT)
                     STATUSLEN(WS-SLEN)
                     ACTION(DFHVALUE(IMMEDIATE))
                     SRVCONVERT CHARACTERSET('iso-8859-1')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-RESP NOT = DFHRESP(NORMAL)
               MOVE WS-MODE TO LOG-MODE
               MOVE WS-RESP TO LOG-RESP
               MOVE WS-RESP2 TO LOG-RESP2
               EXEC CICS WRITEQ TS QUEUE('GTNFLOG') FROM(WS-LOG)
                         LENGTH(14)
               END-EXEC
               MOVE 404 TO WS-CODE
               MOVE 'Not Found' TO WS-STAT
               MOVE 9 TO WS-SLEN
               EXEC CICS WEB SEND FROM(WS-BODY) FROMLENGTH(WS-BLEN)
                         MEDIATYPE(WS-MT)
                         STATUSCODE(WS-CODE) STATUSTEXT(WS-STAT)
                         STATUSLEN(WS-SLEN)
                         ACTION(DFHVALUE(IMMEDIATE))
                         SRVCONVERT CHARACTERSET('iso-8859-1')
                         RESP(WS-RESP) RESP2(WS-RESP2)
               END-EXEC
           END-IF
           EXEC CICS RETURN END-EXEC.
