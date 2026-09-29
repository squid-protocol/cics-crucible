       IDENTIFICATION DIVISION.
       PROGRAM-ID. CAXB.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-xctl-versions           *
      * Original program (Apache-2.0).                                *
      * Speaks the 80-byte version-2 COMMAREA. It trusts EIBCALEN:    *
      * fewer than 80 bytes means an old caller, so the rest is       *
      * defaulted; 80 bytes means every field is taken as given.      *
      * Pseudo-conversational under transaction CA03; PF3 ends.       *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY DFHAID.
       01  WS-V2.
           COPY CAV2.
       01  WS-CALEN-D            PIC 9(4)  VALUE 0.
       01  WS-BAL-ED             PIC +9(7).99.
       01  WS-REPORT             PIC X(80) VALUE SPACES.
       01  WS-BYE                PIC X(13) VALUE 'SESSION ENDED'.
       LINKAGE SECTION.
       01  DFHCOMMAREA.
           COPY CAV2.
       PROCEDURE DIVISION.
       MAIN-PARA.
           IF EIBAID = DFHPF3 AND EIBTRNID = 'CA03'
               EXEC CICS SEND TEXT FROM(WS-BYE) LENGTH(13) ERASE
               END-EXEC
               EXEC CICS RETURN END-EXEC
           END-IF
           INITIALIZE WS-V2
           MOVE 'STANDARD' TO V2-TIER OF WS-V2
           MOVE 'UPGRADED FROM V1' TO V2-NOTE OF WS-V2
           IF EIBCALEN > 0
               IF EIBCALEN < LENGTH OF WS-V2
                   MOVE DFHCOMMAREA(1:EIBCALEN) TO WS-V2(1:EIBCALEN)
                   MOVE '2' TO V2-VERSION OF WS-V2
               ELSE
                   MOVE DFHCOMMAREA(1:LENGTH OF WS-V2) TO WS-V2
               END-IF
           END-IF
           ADD 1 TO V2-VISITS OF WS-V2
           MOVE EIBCALEN TO WS-CALEN-D
           MOVE V2-BALANCE OF WS-V2 TO WS-BAL-ED
           STRING 'V=' V2-VERSION OF WS-V2
                  ' C=' V2-CUSTID OF WS-V2
                  ' N=' V2-VISITS OF WS-V2
                  ' T=' V2-TIER OF WS-V2
                  ' B=' WS-BAL-ED
                  ' L=' WS-CALEN-D
                  ' ' V2-NOTE OF WS-V2(1:16)
               DELIMITED BY SIZE INTO WS-REPORT
           EXEC CICS SEND TEXT FROM(WS-REPORT) LENGTH(80) ERASE
           END-EXEC
           EXEC CICS RETURN TRANSID('CA03') COMMAREA(WS-V2) LENGTH(80)
           END-EXEC.
