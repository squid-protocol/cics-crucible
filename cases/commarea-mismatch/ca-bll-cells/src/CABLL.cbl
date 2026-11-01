       IDENTIFICATION DIVISION.
       PROGRAM-ID. CABLL.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-bll-cells               *
      * Original program (Apache-2.0).                                *
      * OS/VS COBOL addressing: no ADDRESS OF, no POINTER. The cells  *
      * of BLL-CELLS (S9(8) COMP) address the 01s after it, in order. *
      * CA0N, a mode typed after the transid:                         *
      *   R  WRITEQ TS then READQ TS SET(cell), SERVICE RELOAD the    *
      *      record, read it through the record                       *
      *   L  GETMAIN SET(cell) of 5400 bytes (a record over 4096      *
      *      bytes takes two cells: the second is the first + 4096),  *
      *      write the head and the tail through the record, MOVE the *
      *      first cell to another cell, read the head back through   *
      *      the record that cell addresses                           *
      * The result is in the SEND TEXT report.                        *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-IMG                PIC X     VALUE '*'.
       01  WS-ITEM               PIC X(12) VALUE 'QUEUED-ITEM1'.
       01  WS-LEN                PIC S9(4) COMP VALUE 0.
       01  WS-LEND               PIC 99    VALUE 0.
       01  WS-REPORT             PIC X(40) VALUE SPACES.
       LINKAGE SECTION.
       01  DFHCOMMAREA           PIC X(4).
       01  BLL-CELLS.
           02  FILLER            PIC S9(8) COMP.
           02  QPTR              PIC S9(8) COMP.
           02  FRPTR             PIC S9(8) COMP.
           02  FRPTR1            PIC S9(8) COMP.
           02  TSPTR             PIC S9(8) COMP.
       01  Q-REC                 PIC X(12).
       01  FILE-REC.
           02  FIELD1            PIC X(4000).
           02  FIELD2            PIC X(1000).
           02  FIELD3            PIC X(400).
       01  TS-REC.
           02  TFIELD            PIC X(10).
           02  FILLER            PIC X(390).
       PROCEDURE DIVISION.
           SERVICE RELOAD BLL-CELLS.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
                END-EXEC.
           MOVE WS-INPUT(6:1) TO WS-MODE.
           IF WS-MODE = 'R' PERFORM READ-PARA.
           IF WS-MODE = 'L' PERFORM LONG-PARA.
           EXEC CICS SEND TEXT FROM(WS-REPORT) LENGTH(40) ERASE
                END-EXEC.
           EXEC CICS RETURN END-EXEC.
       READ-PARA.
           EXEC CICS WRITEQ TS QUEUE('BLLQ') FROM(WS-ITEM)
                LENGTH(12) END-EXEC.
           EXEC CICS READQ TS QUEUE('BLLQ') SET(QPTR)
                LENGTH(WS-LEN) ITEM(1) END-EXEC.
           SERVICE RELOAD Q-REC.
           MOVE WS-LEN TO WS-LEND.
           MOVE 'MODE=R REC=' TO WS-REPORT(1:11).
           MOVE Q-REC TO WS-REPORT(12:12).
           MOVE ' LEN=' TO WS-REPORT(24:5).
           MOVE WS-LEND TO WS-REPORT(29:2).
       LONG-PARA.
           EXEC CICS GETMAIN SET(FRPTR) FLENGTH(5400)
                INITIMG(WS-IMG) END-EXEC.
           ADD 4096, FRPTR
               GIVING FRPTR1.
           SERVICE RELOAD FILE-REC.
           MOVE 'HEAD' TO FIELD1(1:4).
           MOVE 'TAIL-BYTES' TO FIELD3(1:10).
           MOVE FRPTR TO TSPTR SERVICE RELOAD TS-REC.
           MOVE 'MODE=L VIEW=' TO WS-REPORT(1:12).
           MOVE TFIELD TO WS-REPORT(13:10).
           MOVE ' TAIL=' TO WS-REPORT(23:6).
           MOVE FIELD3(1:10) TO WS-REPORT(29:10).
