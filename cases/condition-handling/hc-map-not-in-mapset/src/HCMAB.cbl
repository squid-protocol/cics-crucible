       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCMAB.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-map-not-in-mapset      *
      * Original program (Apache-2.0).                                *
      * HC61, modes typed after the transid.  Mapset HCSET3 holds     *
      * one map, HCM3.                                                *
      *   O  SEND MAP('HCM3') MAPSET('HCSET3'): the map is in the     *
      *      mapset                                                   *
      *   S  SEND MAP('HCSET3') with no MAPSET: MAPSET defaults to    *
      *      the MAP name, so CICS looks for map HCSET3 in mapset     *
      *      HCSET3, which holds only HCM3                            *
      *   X  HANDLE ABEND LABEL(MAP-ABEND), then SEND MAP('HCNONE')   *
      *      MAPSET('HCSET3'): a map the mapset does not hold; the    *
      *      exit logs the abend code (ASSIGN ABCODE is not an event) *
      *   R  RECEIVE MAP('HCSET3') with no MAPSET, as S               *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY HCSET3.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-ABC                PIC X(4)  VALUE SPACES.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-XLOG.
           05  XLOG-TAG          PIC X(3)  VALUE 'X1 '.
           05  XLOG-CODE         PIC X(4)  VALUE SPACES.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           MOVE LOW-VALUES TO HCM3O
           EVALUATE WS-MODE
               WHEN 'O'
                   EXEC CICS SEND MAP('HCM3') MAPSET('HCSET3')
                             FROM(HCM3O) ERASE
                   END-EXEC
               WHEN 'S'
                   EXEC CICS SEND MAP('HCSET3') FROM(HCM3O) ERASE
                   END-EXEC
               WHEN 'X'
                   EXEC CICS HANDLE ABEND LABEL(MAP-ABEND)
                   END-EXEC
                   EXEC CICS SEND MAP('HCNONE') MAPSET('HCSET3')
                             FROM(HCM3O) ERASE
                   END-EXEC
               WHEN 'R'
                   MOVE LOW-VALUES TO HCM3I
                   EXEC CICS RECEIVE MAP('HCSET3') INTO(HCM3I)
                   END-EXEC
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       MAP-ABEND.
           EXEC CICS ASSIGN ABCODE(WS-ABC)
           END-EXEC
           MOVE WS-ABC TO XLOG-CODE
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-XLOG)
                     LENGTH(7)
           END-EXEC
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
