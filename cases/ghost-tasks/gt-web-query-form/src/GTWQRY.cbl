       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWQRY.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-web-query-form                 *
      * Original program (Apache-2.0).                                 *
      * The user application program of the SERVER URIMAP QRYURI       *
      * (alias transaction GT83). For every request it                 *
      *   WEB READs the keyword parameters k, NAME and zz and a        *
      *   second read of NAME into a 3-byte buffer,                    *
      *   WEB READNEXTs once before any browse,                        *
      *   browses the keyword parameters (WEB STARTBROWSE QUERYPARM,   *
      *   WEB READNEXT until ENDFILE, WEB ENDBROWSE QUERYPARM),        *
      * then WEB SENDs one 118-byte line of RESP / RESP2 and values.   *
      * None of these commands is an event: they touch only the        *
      * program's storage, so the response is the breadcrumb. No       *
      * length written back by a command is logged.                    *
      *---------------------------------------------------------------*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RESP                 PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                PIC S9(8) COMP VALUE 0.
       01  WS-V                    PIC X(8)  VALUE SPACES.
       01  WS-VL                   PIC S9(8) COMP VALUE 8.
       01  WS-V3                   PIC X(3)  VALUE SPACES.
       01  WS-V3L                  PIC S9(8) COMP VALUE 3.
       01  WS-NM                   PIC X(8)  VALUE SPACES.
       01  WS-NL                   PIC S9(8) COMP VALUE 8.
       01  WS-PTR                  PIC S9(4) COMP VALUE 1.
       01  WS-COUNT                PIC 9     VALUE 0.
       01  WS-FINAL                PIC S9(8) COMP VALUE 0.
       01  WS-STAT                 PIC X(2)  VALUE 'OK'.
       01  WS-OUT.
           05  FILLER              PIC X(2)  VALUE 'K='.
           05  OUT-KR              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-K2              PIC 999   VALUE 0.
           05  FILLER              PIC X     VALUE ' '.
           05  OUT-KV              PIC X(8)  VALUE SPACES.
           05  FILLER              PIC X(3)  VALUE ' U='.
           05  OUT-UR              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-U2              PIC 999   VALUE 0.
           05  FILLER              PIC X     VALUE ' '.
           05  OUT-UV              PIC X(8)  VALUE SPACES.
           05  FILLER              PIC X(3)  VALUE ' Z='.
           05  OUT-ZR              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-Z2              PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' S='.
           05  OUT-SR              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-S2              PIC 999   VALUE 0.
           05  FILLER              PIC X     VALUE ' '.
           05  OUT-SV              PIC X(3)  VALUE SPACES.
           05  FILLER              PIC X(3)  VALUE ' N='.
           05  OUT-NR              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-N2              PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' T='.
           05  OUT-TR              PIC 99    VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' C='.
           05  OUT-CNT             PIC 9     VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' F='.
           05  OUT-FR              PIC 99    VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' B='.
           05  OUT-PAIRS           PIC X(30) VALUE SPACES.
           05  FILLER              PIC X(3)  VALUE ' E='.
           05  OUT-ER              PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS WEB READ QUERYPARM('k') NAMELENGTH(1)
                     VALUE(WS-V) VALUELENGTH(WS-VL)
                     HOSTCODEPAGE('037')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-KR
           MOVE WS-RESP2 TO OUT-K2
           IF WS-RESP = 0
               MOVE WS-V TO OUT-KV
           END-IF
           MOVE SPACES TO WS-V
           MOVE 8 TO WS-VL
           EXEC CICS WEB READ QUERYPARM('NAME') NAMELENGTH(4)
                     VALUE(WS-V) VALUELENGTH(WS-VL)
                     HOSTCODEPAGE('037')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-UR
           MOVE WS-RESP2 TO OUT-U2
           IF WS-RESP = 0
               MOVE WS-V TO OUT-UV
           END-IF
           MOVE SPACES TO WS-V
           MOVE 8 TO WS-VL
           EXEC CICS WEB READ QUERYPARM('zz') NAMELENGTH(2)
                     VALUE(WS-V) VALUELENGTH(WS-VL)
                     HOSTCODEPAGE('037')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-ZR
           MOVE WS-RESP2 TO OUT-Z2
           EXEC CICS WEB READ QUERYPARM('name') NAMELENGTH(4)
                     VALUE(WS-V3) VALUELENGTH(WS-V3L)
                     HOSTCODEPAGE('037')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-SR
           MOVE WS-RESP2 TO OUT-S2
           MOVE WS-V3 TO OUT-SV
           EXEC CICS WEB READNEXT QUERYPARM(WS-NM) NAMELENGTH(WS-NL)
                     VALUE(WS-V) VALUELENGTH(WS-VL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-NR
           MOVE WS-RESP2 TO OUT-N2
           EXEC CICS WEB STARTBROWSE QUERYPARM
                     HOSTCODEPAGE('037')
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-TR
           MOVE 0 TO WS-FINAL
           MOVE 1 TO WS-PTR
           PERFORM NEXT-PARA UNTIL WS-FINAL NOT = 0 OR WS-COUNT = 6
           MOVE WS-COUNT TO OUT-CNT
           MOVE WS-FINAL TO OUT-FR
           EXEC CICS WEB ENDBROWSE QUERYPARM
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-ER
           EXEC CICS WEB SEND FROM(WS-OUT) FROMLENGTH(118)
                     MEDIATYPE('text/plain')
                     STATUSCODE(200) STATUSTEXT(WS-STAT) STATUSLEN(2)
                     SRVCONVERT CHARACTERSET('iso-8859-1')
                     HOSTCODEPAGE('037')
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       NEXT-PARA.
           MOVE SPACES TO WS-NM
           MOVE SPACES TO WS-V
           MOVE 8 TO WS-NL
           MOVE 8 TO WS-VL
           EXEC CICS WEB READNEXT QUERYPARM(WS-NM) NAMELENGTH(WS-NL)
                     VALUE(WS-V) VALUELENGTH(WS-VL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           IF WS-RESP = 0
               ADD 1 TO WS-COUNT
               STRING WS-NM DELIMITED BY SPACE
                      '=' DELIMITED BY SIZE
                      WS-V DELIMITED BY SPACE
                      ';' DELIMITED BY SIZE
                      INTO OUT-PAIRS WITH POINTER WS-PTR
           ELSE
               MOVE WS-RESP TO WS-FINAL
           END-IF.
