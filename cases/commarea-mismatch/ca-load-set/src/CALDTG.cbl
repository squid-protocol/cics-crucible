       IDENTIFICATION DIVISION.
       PROGRAM-ID. CALDTG.
      *---------------------------------------------------------------*
      * cics-crucible  commarea-mismatch / ca-load-set                *
      * Original program (Apache-2.0).                                *
      * The program the other two LOAD. It is never run: only its     *
      * address and length are asked for. Its bytes are not read.     *
      *---------------------------------------------------------------*
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RETURN END-EXEC.
