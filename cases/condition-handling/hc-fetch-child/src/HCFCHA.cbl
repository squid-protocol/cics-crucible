       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCFCHA.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-fetch-child            *
      * Original program (Apache-2.0).                                *
      * HCFE, a RUN TRANSID child of HCFPAR: abends with code HCFX,   *
      * with no HANDLE ABEND exit.                                    *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DUMMY              PIC X     VALUE SPACE.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS ABEND ABCODE('HCFX') END-EXEC.
