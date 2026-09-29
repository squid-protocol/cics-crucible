       IDENTIFICATION DIVISION.
       PROGRAM-ID. CAXA.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-xctl-versions           *
      * Original program (Apache-2.0).                                *
      * An old (version-1, 10-byte COMMAREA) front end that XCTLs to  *
      * CAXB, which speaks version 2 (80 bytes). Modes typed after    *
      * the transid:                                                  *
      *   S  XCTL LENGTH(10)    - a true version-1 COMMAREA           *
      *   L  XCTL LENGTH(80)    - 10 bytes of V1 + 70 bytes of        *
      *                           whatever this program keeps next    *
      *   X  XCTL LENGTH(32767) - outside 0..32763: LENGERR           *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-BIGLEN             PIC S9(4) COMP-5 VALUE 32767.
       01  WS-REPORT             PIC X(40) VALUE SPACES.
       01  WS-RESP-D             PIC 99    VALUE 0.
       01  WS-RESP2-D            PIC 99    VALUE 0.
       01  WS-BLOCK.
           05  WS-V1.
               10  V1-VERSION        PIC X      VALUE '1'.
               10  V1-CUSTID         PIC X(5)   VALUE 'C0042'.
               10  V1-VISITS         PIC 9(4)   VALUE 7.
           05  WS-NEIGHBOUR.
               10  NB-TIER           PIC X(10)  VALUE 'GOLD'.
               10  NB-BALANCE        PIC S9(7)V99 COMP-3
                                     VALUE +12345.67.
               10  NB-NOTE           PIC X(55)
                                     VALUE 'NEIGHBOUR STORAGE, NOT V1'.
       01  WS-BIG                PIC X(32767) VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'S'
                   EXEC CICS XCTL PROGRAM('CAXB') COMMAREA(WS-V1)
                             LENGTH(10)
                   END-EXEC
               WHEN 'L'
                   EXEC CICS XCTL PROGRAM('CAXB') COMMAREA(WS-V1)
                             LENGTH(80)
                   END-EXEC
               WHEN OTHER
                   EXEC CICS XCTL PROGRAM('CAXB') COMMAREA(WS-BIG)
                             LENGTH(WS-BIGLEN)
                             RESP(WS-RESP) RESP2(WS-RESP2)
                   END-EXEC
           END-EVALUATE
      *    only reached when the XCTL failed
           MOVE WS-RESP TO WS-RESP-D
           MOVE WS-RESP2 TO WS-RESP2-D
           STRING 'XCTL FAILED RESP=' WS-RESP-D ' RESP2=' WS-RESP2-D
               DELIMITED BY SIZE INTO WS-REPORT
           EXEC CICS SEND TEXT FROM(WS-REPORT) LENGTH(40) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
