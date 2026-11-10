       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCENQD.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-enq-deq                *
      * Original program (Apache-2.0).                                *
      * HC94 issues five ENQ / DEQ pairs, each command with RESP, and *
      * logs the RESP of each to TS queue HCLOG (ENQ and DEQ are not  *
      * events). Each DEQ follows its ENQ; no resource is held twice: *
      *   1 RESOURCE only                                             *
      *   2 RESOURCE and LENGTH(8)                                    *
      *   3 ENQ with NOSUSPEND on a free resource                     *
      *   4 ENQ with MAXLIFETIME(UOW)                                 *
      *   5 ENQ with MAXLIFETIME(TASK)                                *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RES                PIC X(8)  VALUE 'ACCTLOCK'.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-LOG.
           05  LOG-TAG           PIC XX    VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  LOG-RESP          PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS ENQ RESOURCE(WS-RES)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'E1' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS DEQ RESOURCE(WS-RES)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'D1' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS ENQ RESOURCE(WS-RES) LENGTH(8)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'E2' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS DEQ RESOURCE(WS-RES) LENGTH(8)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'D2' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS ENQ RESOURCE(WS-RES) NOSUSPEND
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'E3' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS DEQ RESOURCE(WS-RES)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'D3' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS ENQ RESOURCE(WS-RES) MAXLIFETIME(DFHVALUE(UOW))
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'E4' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS DEQ RESOURCE(WS-RES)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'D4' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS ENQ RESOURCE(WS-RES) MAXLIFETIME(DFHVALUE(TASK))
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'E5' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS DEQ RESOURCE(WS-RES)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'D5' TO LOG-TAG
           PERFORM LOG-PARA
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       LOG-PARA.
           MOVE WS-RESP TO LOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-LOG)
                     LENGTH(7)
           END-EXEC.
