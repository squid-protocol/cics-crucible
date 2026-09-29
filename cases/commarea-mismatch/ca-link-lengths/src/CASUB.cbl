       IDENTIFICATION DIVISION.
       PROGRAM-ID. CASUB.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-link-lengths            *
      * Original program (Apache-2.0).                                *
      * Declares a 500-byte COMMAREA (header + extension) but only    *
      * trusts what EIBCALEN says the caller passed.                  *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-MSG                PIC X(11) VALUE 'NO COMMAREA'.
       LINKAGE SECTION.
       01  DFHCOMMAREA.
           05  CA-HEAD.
               COPY CAHDR.
           05  CA-EXT.
               10  CA-EXT-FLAG       PIC X.
               10  CA-EXT-DATA       PIC X(399).
       PROCEDURE DIVISION.
       SUB-MAIN.
           IF EIBCALEN = 0
               EXEC CICS WRITEQ TS QUEUE('CATRACE') FROM(WS-MSG)
                         LENGTH(11)
               END-EXEC
               EXEC CICS RETURN END-EXEC
           END-IF
           MOVE EIBCALEN TO CA-SEEN-LEN
           MOVE 'PONG' TO CA-REPLY
           IF EIBCALEN >= LENGTH OF DFHCOMMAREA
               MOVE 'Y' TO CA-EXT-FLAG
               MOVE 'CALLEE-WROTE-HERE' TO CA-EXT-DATA
               MOVE '00' TO CA-RC
           ELSE
               MOVE '04' TO CA-RC
           END-IF
           EXEC CICS RETURN END-EXEC.
