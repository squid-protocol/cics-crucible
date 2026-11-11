       IDENTIFICATION DIVISION.
       PROGRAM-ID. GTWHBR.
      *---------------------------------------------------------------*
      * cics-crucible  ghost-tasks / gt-web-header-browse             *
      * Original program (Apache-2.0).                                *
      * The user application program of the SERVER URIMAP HBRURI      *
      * (alias transaction GT91). For every request it                *
      *   WEB READs the HTTP header X-Crucible-Mode (1 to 5),         *
      *   P  WEB READNEXT HTTPHEADER before any browse,               *
      *   Q  WEB ENDBROWSE HTTPHEADER before any browse,              *
      *   T  WEB STARTBROWSE HTTPHEADER,                              *
      *   S  a second WEB STARTBROWSE HTTPHEADER inside the browse,   *
      *   R  the first WEB READNEXT HTTPHEADER, whose buffers the     *
      *      mode sets:                                               *
      *        mode 1  name 64 bytes, value 255 bytes (fit)           *
      *        mode 2  NAMELENGTH 1 (the name is truncated)           *
      *        mode 3  NAMELENGTH 0                                   *
      *        mode 4  VALUELENGTH 0                                  *
      *        mode 5  NAMELENGTH -1                                  *
      *   F  mode 1 only: WEB READNEXT until RESP is not NORMAL (at   *
      *      most 30), F is the RESP that ended it                    *
      *   E  WEB ENDBROWSE HTTPHEADER,                                *
      *   X  WEB READNEXT HTTPHEADER after the browse ended,          *
      * then WEB SENDs one 67-byte line of the modes and RESP/RESP2.  *
      * None of these commands is an event: the response is the       *
      * breadcrumb. The header names and how many headers a request   *
      * has are not logged: IBM does not say.                         *
      *---------------------------------------------------------------*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RESP                 PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                PIC S9(8) COMP VALUE 0.
       01  WS-MODE                 PIC X     VALUE SPACE.
       01  WS-NM                   PIC X(64) VALUE SPACES.
       01  WS-NL                   PIC S9(8) COMP VALUE 64.
       01  WS-V                    PIC X(255) VALUE SPACES.
       01  WS-VL                   PIC S9(8) COMP VALUE 255.
       01  WS-COUNT                PIC 99    VALUE 0.
       01  WS-FINAL                PIC S9(8) COMP VALUE 0.
       01  WS-BODY-STAT            PIC X(2)  VALUE 'OK'.
       01  WS-OUT.
           05  FILLER              PIC X(2)  VALUE 'M='.
           05  OUT-MODE            PIC X     VALUE SPACE.
           05  FILLER              PIC X(3)  VALUE ' P='.
           05  OUT-PR              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-P2              PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' Q='.
           05  OUT-QR              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-Q2              PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' T='.
           05  OUT-TR              PIC 99    VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' S='.
           05  OUT-SR              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-S2              PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' R='.
           05  OUT-RR              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-R2              PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' F='.
           05  OUT-FR              PIC 99    VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' E='.
           05  OUT-ER              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-E2              PIC 999   VALUE 0.
           05  FILLER              PIC X(3)  VALUE ' X='.
           05  OUT-XR              PIC 99    VALUE 0.
           05  FILLER              PIC X     VALUE '/'.
           05  OUT-X2              PIC 999   VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS WEB READ HTTPHEADER('X-Crucible-Mode')
                     NAMELENGTH(15)
                     VALUE(WS-MODE) VALUELENGTH(1)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-MODE TO OUT-MODE
           PERFORM RESET-PARA
           EXEC CICS WEB READNEXT HTTPHEADER(WS-NM)
                     NAMELENGTH(WS-NL)
                     VALUE(WS-V) VALUELENGTH(WS-VL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-PR
           MOVE WS-RESP2 TO OUT-P2
           EXEC CICS WEB ENDBROWSE HTTPHEADER
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-QR
           MOVE WS-RESP2 TO OUT-Q2
           EXEC CICS WEB STARTBROWSE HTTPHEADER
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-TR
           EXEC CICS WEB STARTBROWSE HTTPHEADER
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-SR
           MOVE WS-RESP2 TO OUT-S2
           PERFORM RESET-PARA
           EVALUATE WS-MODE
               WHEN '2'
                   MOVE 1 TO WS-NL
               WHEN '3'
                   MOVE 0 TO WS-NL
               WHEN '4'
                   MOVE 0 TO WS-VL
               WHEN '5'
                   MOVE -1 TO WS-NL
           END-EVALUATE
           EXEC CICS WEB READNEXT HTTPHEADER(WS-NM)
                     NAMELENGTH(WS-NL)
                     VALUE(WS-V) VALUELENGTH(WS-VL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-RR
           MOVE WS-RESP2 TO OUT-R2
           IF WS-MODE = '1'
               MOVE WS-RESP TO WS-FINAL
               PERFORM NEXT-PARA UNTIL WS-FINAL NOT = 0
                       OR WS-COUNT = 30
           END-IF
           MOVE WS-FINAL TO OUT-FR
           EXEC CICS WEB ENDBROWSE HTTPHEADER
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-ER
           MOVE WS-RESP2 TO OUT-E2
           PERFORM RESET-PARA
           EXEC CICS WEB READNEXT HTTPHEADER(WS-NM)
                     NAMELENGTH(WS-NL)
                     VALUE(WS-V) VALUELENGTH(WS-VL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE WS-RESP TO OUT-XR
           MOVE WS-RESP2 TO OUT-X2
           EXEC CICS WEB SEND FROM(WS-OUT) FROMLENGTH(67)
                     MEDIATYPE('text/plain')
                     STATUSCODE(200) STATUSTEXT(WS-BODY-STAT)
                     STATUSLEN(2)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       RESET-PARA.
           MOVE SPACES TO WS-NM
           MOVE SPACES TO WS-V
           MOVE 64 TO WS-NL
           MOVE 255 TO WS-VL.
       NEXT-PARA.
           PERFORM RESET-PARA
           EXEC CICS WEB READNEXT HTTPHEADER(WS-NM)
                     NAMELENGTH(WS-NL)
                     VALUE(WS-V) VALUELENGTH(WS-VL)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           ADD 1 TO WS-COUNT
           MOVE WS-RESP TO WS-FINAL.
