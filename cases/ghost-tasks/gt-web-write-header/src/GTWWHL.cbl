       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWWHL.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-web-write-header              *
      * Original program (Apache-2.0).                                *
      * The user application program of the SERVER URIMAP WHURI       *
      * (alias transaction GT90). For every request it                *
      *   WEB READs the HTTP header X-Crucible-Mode (1 to 5),         *
      *   WEB WRITEs the response header X-Crucible-Note: ok with     *
      *   mode 1  both lengths valid (15 and 2)                       *
      *   mode 2  NAMELENGTH 0                                        *
      *   mode 3  NAMELENGTH -1                                       *
      *   mode 4  VALUELENGTH 0                                       *
      *   mode 5  VALUELENGTH -1                                      *
      * and on a non-NORMAL RESP logs "M<mode> R=<RESP> E=<RESP2>" to *
      * TS queue GTWHLOG. It always answers WEB SEND FROM, 200.       *
      *---------------------------------------------------------------*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RESP                 PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                PIC S9(8) COMP VALUE 0.
       01  WS-MODE                 PIC X     VALUE SPACE.
       01  WS-NAME                 PIC X(15) VALUE 'X-Crucible-Note'.
       01  WS-NLEN                 PIC S9(8) COMP VALUE 15.
       01  WS-VAL                  PIC X(2)  VALUE 'ok'.
       01  WS-VLEN                 PIC S9(8) COMP VALUE 2.
       01  WS-BODY                 PIC X(4)  VALUE 'done'.
       01  WS-BLEN                 PIC S9(8) COMP VALUE 4.
       01  WS-MT                   PIC X(56) VALUE 'text/plain'.
       01  WS-CODE                 PIC S9(4) COMP VALUE 200.
       01  WS-STAT                 PIC X(2)  VALUE 'OK'.
       01  WS-SLEN                 PIC S9(8) COMP VALUE 2.
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
           EVALUATE WS-MODE
               WHEN '2'
                   MOVE 0 TO WS-NLEN
               WHEN '3'
                   MOVE -1 TO WS-NLEN
               WHEN '4'
                   MOVE 0 TO WS-VLEN
               WHEN '5'
                   MOVE -1 TO WS-VLEN
           END-EVALUATE
           EXEC CICS WEB WRITE HTTPHEADER(WS-NAME)
                     NAMELENGTH(WS-NLEN)
                     VALUE(WS-VAL) VALUELENGTH(WS-VLEN)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-RESP NOT = DFHRESP(NORMAL)
               MOVE WS-MODE TO LOG-MODE
               MOVE WS-RESP TO LOG-RESP
               MOVE WS-RESP2 TO LOG-RESP2
               EXEC CICS WRITEQ TS QUEUE('GTWHLOG') FROM(WS-LOG)
                         LENGTH(14)
               END-EXEC
           END-IF
           EXEC CICS WEB SEND FROM(WS-BODY) FROMLENGTH(WS-BLEN)
                     MEDIATYPE(WS-MT)
                     STATUSCODE(WS-CODE) STATUSTEXT(WS-STAT)
                     STATUSLEN(WS-SLEN)
                     ACTION(DFHVALUE(IMMEDIATE))
                     SRVCONVERT CHARACTERSET('iso-8859-1')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
