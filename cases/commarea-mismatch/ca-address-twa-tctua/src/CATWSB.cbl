       IDENTIFICATION DIVISION.
       PROGRAM-ID. CATWSB.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-address-twa-tctua       *
      * Original program (Apache-2.0).                                *
      * The callee of CATWAD mode W: no COMMAREA, so the only way the *
      * two programs share data is the transaction work area. It      *
      * reads the caller's stamp through its own view of the TWA,     *
      * writes a breadcrumb, then writes a reply into the TWA.        *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PTR                POINTER.
       01  WS-PTR-X REDEFINES WS-PTR PIC X(4).
       01  WS-CLOG.
           05  CLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' P='.
           05  CLOG-P            PIC X(7)  VALUE SPACES.
           05  FILLER            PIC X(4)  VALUE ' V1='.
           05  CLOG-V1           PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X(4)  VALUE ' V2='.
           05  CLOG-V2           PIC X(8)  VALUE SPACES.
       LINKAGE SECTION.
       01  LS-TWA.
           05  TW-STAMP          PIC X(8).
           05  TW-REPLY          PIC X(8).
       PROCEDURE DIVISION.
       SUB-MAIN.
           EXEC CICS ADDRESS TWA(WS-PTR)
           END-EXEC
           MOVE 'W2 ' TO CLOG-TAG
           IF WS-PTR-X = X'FF000000'
               MOVE 'ABSENT' TO CLOG-P
           ELSE
               MOVE 'PRESENT' TO CLOG-P
               SET ADDRESS OF LS-TWA TO WS-PTR
               MOVE TW-STAMP TO CLOG-V1
               MOVE 'TWAECHO' TO TW-REPLY
           END-IF
           EXEC CICS WRITEQ TS QUEUE('CALOG') FROM(WS-CLOG)
                     LENGTH(37)
           END-EXEC
           EXEC CICS RETURN END-EXEC.
