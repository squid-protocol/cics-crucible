       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCINQD.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-inquire-deleteq        *
      * Original program (Apache-2.0).                                *
      * HC61, modes typed after the transid:                          *
      *   I  EXEC CICS INQUIRE ASSOCIATION(EIBTASKN): all five origin *
      *      options with RESP / RESP2, then two of them with no RESP *
      *   D  EXEC CICS DELETEQ TS: a queue with a NEXT position, the  *
      *      same queue again, a name of binary zeros, and the queue  *
      *      written anew                                             *
      *   M  SEND MAP, then (transaction HC62) RECEIVE MAP ...        *
      *      TERMINAL ASIS                                            *
      * Every result is a breadcrumb in TS queue HCLOG (INQUIRE and   *
      * DELETEQ are not events).                                      *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY HCSET2.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-APPLID             PIC X(8)  VALUE SPACES.
       01  WS-USERID             PIC X(8)  VALUE SPACES.
       01  WS-FACIL              PIC X(8)  VALUE SPACES.
       01  WS-NETID              PIC X(8)  VALUE SPACES.
       01  WS-FTYPE              PIC S9(8) COMP VALUE 0.
       01  WS-ZQ                 PIC X(8)  VALUE LOW-VALUES.
       01  WS-Q1                 PIC X(3)  VALUE 'ONE'.
       01  WS-Q2                 PIC X(3)  VALUE 'TWO'.
       01  WS-Q3                 PIC X(5)  VALUE 'THREE'.
       01  WS-RBUF               PIC X(5)  VALUE SPACES.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-ILOG.
           05  ILOG-TAG          PIC X(3)  VALUE SPACES.
           05  ILOG-APPLID       PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X     VALUE SPACE.
           05  ILOG-USERID       PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X     VALUE SPACE.
           05  ILOG-FACIL        PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X     VALUE SPACE.
           05  ILOG-NETID        PIC X(8)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' T='.
           05  ILOG-TYPE         PIC 9(9)  VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  ILOG-RESP         PIC 99    VALUE 0.
       01  WS-DLOG.
           05  DLOG-TAG          PIC X(3)  VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  DLOG-RESP         PIC 99    VALUE 0.
       01  WS-MLOG.
           05  MLOG-TAG          PIC X(3)  VALUE 'M1 '.
           05  MLOG-TEXT         PIC X(12) VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  MLOG-RESP         PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           IF EIBTRNID = 'HC62'
               PERFORM RECEIVE-PARA
           ELSE
               EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
               END-EXEC
               MOVE WS-INPUT(6:1) TO WS-MODE
               EVALUATE WS-MODE
                   WHEN 'I'
                       PERFORM ASSOC-PARA
                   WHEN 'D'
                       PERFORM DELETEQ-PARA
                   WHEN 'M'
                       PERFORM SHOW-PARA
               END-EVALUATE
           END-IF
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       ASSOC-PARA.
           EXEC CICS INQUIRE ASSOCIATION(EIBTASKN)
                     ODAPPLID(WS-APPLID) ODUSERID(WS-USERID)
                     ODFACILNAME(WS-FACIL) ODNETWORKID(WS-NETID)
                     ODFACILTYPE(WS-FTYPE)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'I1 ' TO ILOG-TAG
           PERFORM LOG-I
           MOVE SPACES TO WS-APPLID WS-USERID WS-FACIL WS-NETID
           MOVE 0 TO WS-FTYPE
           EXEC CICS INQUIRE ASSOCIATION(EIBTASKN)
                     ODNETWORKID(WS-NETID) ODFACILTYPE(WS-FTYPE)
           END-EXEC
           MOVE 0 TO WS-RESP
           MOVE 'I2 ' TO ILOG-TAG
           PERFORM LOG-I.
       LOG-I.
           MOVE WS-APPLID TO ILOG-APPLID
           MOVE WS-USERID TO ILOG-USERID
           MOVE WS-FACIL TO ILOG-FACIL
           MOVE WS-NETID TO ILOG-NETID
           MOVE WS-FTYPE TO ILOG-TYPE
           MOVE WS-RESP TO ILOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-ILOG)
                     LENGTH(55)
           END-EXEC.
       DELETEQ-PARA.
           EXEC CICS WRITEQ TS QUEUE('HCQ') FROM(WS-Q1) LENGTH(3)
           END-EXEC
           EXEC CICS WRITEQ TS QUEUE('HCQ') FROM(WS-Q2) LENGTH(3)
           END-EXEC
           EXEC CICS READQ TS QUEUE('HCQ') INTO(WS-RBUF) NEXT
                     RESP(WS-RESP)
           END-EXEC
           EXEC CICS DELETEQ TS QUEUE('HCQ') RESP(WS-RESP)
           END-EXEC
           MOVE 'D1 ' TO DLOG-TAG
           PERFORM LOG-D
           EXEC CICS READQ TS QUEUE('HCQ') INTO(WS-RBUF) ITEM(1)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'D2 ' TO DLOG-TAG
           PERFORM LOG-D
           EXEC CICS DELETEQ TS QUEUE('HCQ') RESP(WS-RESP)
           END-EXEC
           MOVE 'D3 ' TO DLOG-TAG
           PERFORM LOG-D
           EXEC CICS WRITEQ TS QUEUE('HCQ') FROM(WS-Q3) LENGTH(5)
           END-EXEC
           EXEC CICS READQ TS QUEUE('HCQ') INTO(WS-RBUF) NEXT
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'D4 ' TO DLOG-TAG
           PERFORM LOG-D
           EXEC CICS DELETEQ TS QUEUE(WS-ZQ) RESP(WS-RESP)
           END-EXEC
           MOVE 'D5 ' TO DLOG-TAG
           PERFORM LOG-D.
       LOG-D.
           MOVE WS-RESP TO DLOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-DLOG)
                     LENGTH(8)
           END-EXEC.
       SHOW-PARA.
           MOVE LOW-VALUES TO HCM2O
           EXEC CICS SEND MAP('HCM2') MAPSET('HCSET2') FROM(HCM2O)
                     ERASE
           END-EXEC
           EXEC CICS RETURN TRANSID('HC62')
           END-EXEC.
       RECEIVE-PARA.
           MOVE LOW-VALUES TO HCM2I
           EXEC CICS RECEIVE MAP('HCM2') MAPSET('HCSET2')
                     INTO(HCM2I) TERMINAL ASIS
                     RESP(WS-RESP)
           END-EXEC
           MOVE NAMEI TO MLOG-TEXT
           MOVE WS-RESP TO MLOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-MLOG)
                     LENGTH(20)
           END-EXEC.
