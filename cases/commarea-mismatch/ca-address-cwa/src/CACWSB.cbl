       IDENTIFICATION DIVISION.
       PROGRAM-ID. CACWSB.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-address-cwa             *
      * Original program (Apache-2.0).                                *
      * The callee of CACWAD mode W: no COMMAREA, so the only way the *
      * two programs share data is the common work area. It reads the *
      * caller's stamp through its own view of the CWA, writes a      *
      * breadcrumb, then writes a reply into the CWA.                 *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PTR                POINTER.
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' P='.
           05  CLOG-P            PIC X(7)  VALUE SPACES.
           05  FILLER            PIC X(4)  VALUE ' V1='.
           05  CLOG-V1           PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X(4)  VALUE ' V2='.
           05  CLOG-V2           PIC X(8)  VALUE SPACES.
       LINKAGE SECTION.
       01  LS-CWA.
           05  CW-STAMP          PIC X(8).
           05  CW-REPLY          PIC X(8).
       PROCEDURE DIVISION.
       SUB-MAIN.
           EXEC CICS ADDRESS CWA(WS-PTR)
           END-EXEC
           SET ADDRESS OF LS-CWA TO WS-PTR
           MOVE 'W2 ' TO CLOG-TAG
           MOVE 'PRESENT' TO CLOG-P
           MOVE CW-STAMP TO CLOG-V1
           MOVE 'CWAECHO' TO CW-REPLY
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-CLOG)
                     LENGTH(37)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
