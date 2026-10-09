       IDENTIFICATION DIVISION.
       PROGRAM-ID. PCIMMB.
      *---------------------------------------------------------------*
      * cics-crucible  pseudo-conversational / pc-return-immediate    *
      * Original program (Apache-2.0).                                *
      * PC52, the transaction RETURN IMMEDIATE attaches. Stage 1 logs *
      * and RETURNs TRANSID(PC52) with the COMMAREA, not immediate:   *
      * the next operator step starts stage 2.                        *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CALEN              PIC 99    VALUE 0.
       01  WS-BLOG.
           05  BLOG-TAG          PIC X(3)  VALUE SPACES.
           05  BLOG-TEXT         PIC X(7)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' C='.
           05  BLOG-CALEN        PIC 99    VALUE 0.
       LINKAGE SECTION.
       01  DFHCOMMAREA.
           05  CA-STAGE          PIC X.
           05  CA-TEXT           PIC X(7).
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE EIBCALEN TO WS-CALEN
           MOVE WS-CALEN TO BLOG-CALEN
           MOVE CA-TEXT TO BLOG-TEXT
           IF CA-STAGE = '1'
               MOVE 'B1 ' TO BLOG-TAG
               PERFORM LOG-B
               MOVE '2' TO CA-STAGE
               EXEC CICS RETURN TRANSID('PC52') COMMAREA(DFHCOMMAREA)
                         LENGTH(8)
               END-EXEC
           ELSE
               MOVE 'B2 ' TO BLOG-TAG
               PERFORM LOG-B
               EXEC CICS RETURN END-EXEC
           END-IF.
       LOG-B.
           EXEC CICS WRITEQ TS QUEUE('PCLOG') FROM(WS-BLOG)
                     LENGTH(15)
           END-EXEC.
