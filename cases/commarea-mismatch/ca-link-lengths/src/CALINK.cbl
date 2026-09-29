       IDENTIFICATION DIVISION.
       PROGRAM-ID. CALINK.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-link-lengths            *
      * Original program (Apache-2.0).                                *
      * LINKs to CASUB, which declares a 500-byte DFHCOMMAREA, with   *
      * a 100-byte request header. Modes (typed after the transid):   *
      *   S  LENGTH(100)  - the callee sees 100 bytes                 *
      *   L  LENGTH(500)  - the callee sees the header AND the next   *
      *                     400 bytes of this program's storage       *
      *   Z  no COMMAREA  - EIBCALEN = 0                              *
      *   P  LINK to a program that is not defined (PGMIDERR)         *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-RESP-D             PIC 99    VALUE 0.
       01  WS-RESP2-D            PIC 99    VALUE 0.
       01  WS-SEEN-D             PIC 9(4)  VALUE 0.
       01  WS-REPORT             PIC X(80) VALUE SPACES.
       01  WS-BLOCK.
           05  WS-CA100.
               COPY CAHDR.
           05  WS-AFTER.
               10  WS-AFTER-FLAG     PIC X      VALUE 'N'.
               10  WS-AFTER-DATA     PIC X(399) VALUE 'CALLER-OWNED'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           INITIALIZE WS-CA100
           MOVE 'CAHD' TO CA-EYE
           MOVE '1' TO CA-VERSION
           MOVE 'PING' TO CA-REQUEST
           EVALUATE WS-MODE
               WHEN 'S'
                   EXEC CICS LINK PROGRAM('CASUB') COMMAREA(WS-CA100)
                             LENGTH(100)
                   END-EXEC
               WHEN 'L'
                   EXEC CICS LINK PROGRAM('CASUB') COMMAREA(WS-CA100)
                             LENGTH(500)
                   END-EXEC
               WHEN 'Z'
                   EXEC CICS LINK PROGRAM('CASUB') END-EXEC
               WHEN OTHER
                   EXEC CICS LINK PROGRAM('CAGONE') COMMAREA(WS-CA100)
                             LENGTH(100) RESP(WS-RESP) RESP2(WS-RESP2)
                   END-EXEC
           END-EVALUATE
           MOVE CA-SEEN-LEN TO WS-SEEN-D
           MOVE WS-RESP TO WS-RESP-D
           MOVE WS-RESP2 TO WS-RESP2-D
           STRING 'MODE=' WS-MODE ' RC=' CA-RC ' SEEN=' WS-SEEN-D
                  ' REPLY=' CA-REPLY(1:4) ' AFTER=' WS-AFTER-FLAG
                  ' ' WS-AFTER-DATA(1:17) ' RESP=' WS-RESP-D '/'
                  WS-RESP2-D
               DELIMITED BY SIZE INTO WS-REPORT
           EXEC CICS SEND TEXT FROM(WS-REPORT) LENGTH(80) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
