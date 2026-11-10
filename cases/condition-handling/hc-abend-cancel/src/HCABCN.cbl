       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCABCN.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-abend-cancel           *
      * Original program (Apache-2.0).                                *
      * HCAB reads its mode from the terminal input (HCAB C, R, K, N)*
      * and sets a HANDLE ABEND LABEL exit first:                     *
      *   C  HANDLE ABEND CANCEL, then ABEND HCC1                     *
      *   R  HANDLE ABEND CANCEL, HANDLE ABEND RESET, ABEND HCR1      *
      *   K  ABEND HCK1 CANCEL                                        *
      *   N  ABEND HCN1 NODUMP                                        *
      * The exit sends 'X ' and the ABCODE to the terminal and        *
      * RETURNs.                                                      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-ABCODE             PIC X(4)  VALUE SPACES.
       01  WS-TEXT.
           05  FILLER            PIC XX    VALUE 'X '.
           05  TXT-ABCODE        PIC X(4)  VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EXEC CICS HANDLE ABEND LABEL(MAIN-EXIT) END-EXEC
           EVALUATE WS-MODE
               WHEN 'C'
                   EXEC CICS HANDLE ABEND CANCEL END-EXEC
                   EXEC CICS ABEND ABCODE('HCC1') END-EXEC
               WHEN 'R'
                   EXEC CICS HANDLE ABEND CANCEL END-EXEC
                   EXEC CICS HANDLE ABEND RESET END-EXEC
                   EXEC CICS ABEND ABCODE('HCR1') END-EXEC
               WHEN 'K'
                   EXEC CICS ABEND ABCODE('HCK1') CANCEL END-EXEC
               WHEN 'N'
                   EXEC CICS ABEND ABCODE('HCN1') NODUMP END-EXEC
           END-EVALUATE
           EXEC CICS RETURN END-EXEC.
       MAIN-EXIT.
           EXEC CICS ASSIGN ABCODE(WS-ABCODE) END-EXEC
           MOVE WS-ABCODE TO TXT-ABCODE
           EXEC CICS SEND TEXT FROM(WS-TEXT) LENGTH(6) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
