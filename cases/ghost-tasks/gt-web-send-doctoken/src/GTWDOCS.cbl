       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWDOCS.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-web-send-doctoken             *
      * Original program (Apache-2.0).                                *
      * The user application program of the SERVER URIMAP DOCURI     *
      * (alias transaction GT88). For every request it                *
      *   WEB READs the HTTP header X-Crucible-Mode (1, 2 or 3),      *
      *   DOCUMENT CREATEs a document from TEXT (its length differs   *
      *   per mode),                                                  *
      *   WEB SENDs the document with DOCTOKEN (no FROM), with the    *
      *   DOCSTATUS the mode names:                                   *
      *     1  none given (the default)                               *
      *     2  DOCDELETE                                              *
      *     3  NODOCDELETE, stated                                    *
      *   then DOCUMENT RETRIEVEs the document again and logs the     *
      *   RESP to TS queue GTDOCLOG: the document is still there or   *
      *   it is gone.                                                 *
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
       01  WS-MT                   PIC X(56) VALUE SPACES.
       01  WS-CODE                 PIC S9(4) COMP VALUE 200.
       01  WS-STAT                 PIC X(2)  VALUE 'OK'.
       01  WS-SLEN                 PIC S9(8) COMP VALUE 2.
       01  WS-BUF                  PIC X(20) VALUE SPACES.
       01  WS-BLEN                 PIC S9(8) COMP VALUE 0.
       01  WS-LOG.
           05  FILLER              PIC X     VALUE 'M'.
           05  LOG-MODE            PIC X     VALUE SPACE.
           05  FILLER              PIC X(3)  VALUE ' R='.
           05  LOG-RESP            PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS WEB READ HTTPHEADER('X-Crucible-Mode')
                     NAMELENGTH(15)
                     VALUE(WS-MODE) VALUELENGTH(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           EVALUATE WS-MODE
               WHEN '2'
                   MOVE '<b>bravo</b>' TO WS-TXT
                   MOVE 12 TO WS-TLEN
                   MOVE 'text/xml' TO WS-MT
               WHEN '3'
                   MOVE 'c=3' TO WS-TXT
                   MOVE 3 TO WS-TLEN
                   MOVE 'text/plain' TO WS-MT
               WHEN OTHER
                   MOVE 'alpha=111' TO WS-TXT
                   MOVE 9 TO WS-TLEN
                   MOVE 'text/plain' TO WS-MT
           END-EVALUATE
           EXEC CICS DOCUMENT CREATE DOCTOKEN(WS-TOKEN)
                     TEXT(WS-TXT) LENGTH(WS-TLEN)
                     RESP(WS-RESP)
           END-EXEC
           EVALUATE WS-MODE
               WHEN '2'
                   EXEC CICS WEB SEND DOCTOKEN(WS-TOKEN)
                             DOCSTATUS(DFHVALUE(DOCDELETE))
                             MEDIATYPE(WS-MT)
                             STATUSCODE(WS-CODE) STATUSTEXT(WS-STAT)
                             STATUSLEN(WS-SLEN)
                             ACTION(DFHVALUE(IMMEDIATE))
                             SRVCONVERT CHARACTERSET('iso-8859-1')
                             RESP(WS-RESP) RESP2(WS-RESP2)
                   END-EXEC
               WHEN '3'
                   EXEC CICS WEB SEND DOCTOKEN(WS-TOKEN)
                             DOCSTATUS(DFHVALUE(NODOCDELETE))
                             MEDIATYPE(WS-MT)
                             STATUSCODE(WS-CODE) STATUSTEXT(WS-STAT)
                             STATUSLEN(WS-SLEN)
                             ACTION(DFHVALUE(IMMEDIATE))
                             SRVCONVERT CHARACTERSET('iso-8859-1')
                             RESP(WS-RESP) RESP2(WS-RESP2)
                   END-EXEC
               WHEN OTHER
                   EXEC CICS WEB SEND DOCTOKEN(WS-TOKEN)
                             MEDIATYPE(WS-MT)
                             STATUSCODE(WS-CODE) STATUSTEXT(WS-STAT)
                             STATUSLEN(WS-SLEN)
                             ACTION(DFHVALUE(IMMEDIATE))
                             SRVCONVERT CHARACTERSET('iso-8859-1')
                             RESP(WS-RESP) RESP2(WS-RESP2)
                   END-EXEC
           END-EVALUATE
           MOVE 20 TO WS-BLEN
           EXEC CICS DOCUMENT RETRIEVE DOCTOKEN(WS-TOKEN)
                     INTO(WS-BUF) LENGTH(WS-BLEN) MAXLENGTH(20)
                     RESP(WS-RESP)
           END-EXEC
           MOVE WS-MODE TO LOG-MODE
           MOVE WS-RESP TO LOG-RESP
           EXEC CICS WRITEQ TS QUEUE('GTDOCLOG') FROM(WS-LOG)
                     LENGTH(7)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
