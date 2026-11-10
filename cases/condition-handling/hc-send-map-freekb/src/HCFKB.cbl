       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCFKB.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-send-map-freekb        *
      * Original program (Apache-2.0).                                *
      * HC43 reads its mode from the terminal input (HC43 x) and does *
      * ONE SEND MAP, then ends the task:                             *
      *   A  map HCFA, ERASE FREEKB                                   *
      *   B  map HCFA, ERASE ALARM FREEKB                             *
      *   C  map HCFA, DATAONLY FREEKB                                *
      *   D  map HCFA, MAPONLY ERASE FREEKB                           *
      *   E  map HCFA, ERASE only (no FREEKB anywhere)                *
      *   F  map HCFB, ERASE only (CTRL=(FREEKB) is on the map)       *
      * The screen text names the mode. FREEKB is a send option: the  *
      * log records it only when the program wrote it.                *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY HCFSET.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           MOVE LOW-VALUES TO HCFAO
           MOVE LOW-VALUES TO HCFBO
           MOVE 'MODE ' TO AMSGO
           MOVE WS-MODE TO AMSGO(6:1)
           MOVE AMSGO TO BMSGO
           EVALUATE WS-MODE
               WHEN 'A'
                   EXEC CICS SEND MAP('HCFA') MAPSET('HCFSET')
                             FROM(HCFAO) ERASE FREEKB
                   END-EXEC
               WHEN 'B'
                   EXEC CICS SEND MAP('HCFA') MAPSET('HCFSET')
                             FROM(HCFAO) ERASE ALARM FREEKB
                   END-EXEC
               WHEN 'C'
                   EXEC CICS SEND MAP('HCFA') MAPSET('HCFSET')
                             FROM(HCFAO) DATAONLY FREEKB
                   END-EXEC
               WHEN 'D'
                   EXEC CICS SEND MAP('HCFA') MAPSET('HCFSET')
                             MAPONLY ERASE FREEKB
                   END-EXEC
               WHEN 'E'
                   EXEC CICS SEND MAP('HCFA') MAPSET('HCFSET')
                             FROM(HCFAO) ERASE
                   END-EXEC
               WHEN 'F'
                   EXEC CICS SEND MAP('HCFB') MAPSET('HCFSET')
                             FROM(HCFBO) ERASE
                   END-EXEC
           END-EVALUATE
           EXEC CICS RETURN
           END-EXEC.
