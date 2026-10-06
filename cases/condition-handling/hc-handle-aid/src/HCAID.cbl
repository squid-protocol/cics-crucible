       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCAID.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-handle-aid             *
      * Original program (Apache-2.0).                                *
      * HANDLE AID on a terminal RECEIVE. Each transaction sets its   *
      * HANDLE AID labels (a key's own, ANYKEY, a key deactivated, a  *
      * PUSH HANDLE suspending them, a POP HANDLE restoring them, RESP *
      * on the RECEIVE) and then reads the input; the key the operator *
      * pressed picks the label, or none. HA06 only RETURNs TRANSID    *
      * HA07, so the next key -- CLEAR or PA1, which send no data --   *
      * starts HA07, whose first RECEIVE returns no data. Every path   *
      * leaves a breadcrumb in WS-TRAIL, sent with SEND TEXT.          *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TRAIL              PIC X(40) VALUE SPACES.
       01  WS-PTR                PIC S9(4) COMP VALUE 1.
       01  WS-INPUT              PIC X(20) VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 20.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP-D             PIC 99    VALUE 0.
       01  WS-LEN-D              PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EVALUATE EIBTRNID
      *        A key's own label, ANYKEY for the other PA / PF keys
               WHEN 'HA01'
                   EXEC CICS HANDLE AID PF7(GOT-PF7) ANYKEY(GOT-ANY)
                   END-EXEC
                   EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
                   END-EXEC
                   STRING 'n' DELIMITED BY SIZE
                       INTO WS-TRAIL WITH POINTER WS-PTR
                   PERFORM NOTE-INPUT
      *        PF7's label, then deactivated by HANDLE AID PF7 alone
               WHEN 'HA02'
                   EXEC CICS HANDLE AID PF7(GOT-PF7) END-EXEC
                   EXEC CICS HANDLE AID PF7 END-EXEC
                   EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
                   END-EXEC
                   STRING 'n' DELIMITED BY SIZE
                       INTO WS-TRAIL WITH POINTER WS-PTR
                   PERFORM NOTE-INPUT
      *        RESP on the RECEIVE: no AID label is taken
               WHEN 'HA03'
                   EXEC CICS HANDLE AID PF7(GOT-PF7) END-EXEC
                   EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
                             RESP(WS-RESP)
                   END-EXEC
                   MOVE WS-RESP TO WS-RESP-D
                   STRING 'r' WS-RESP-D DELIMITED BY SIZE
                       INTO WS-TRAIL WITH POINTER WS-PTR
                   PERFORM NOTE-INPUT
      *        PUSH HANDLE suspends the HANDLE AID
               WHEN 'HA04'
                   EXEC CICS HANDLE AID PF7(GOT-PF7) END-EXEC
                   EXEC CICS PUSH HANDLE END-EXEC
                   EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
                   END-EXEC
                   STRING 'u' DELIMITED BY SIZE
                       INTO WS-TRAIL WITH POINTER WS-PTR
                   PERFORM NOTE-INPUT
      *        POP HANDLE restores it
               WHEN 'HA05'
                   EXEC CICS HANDLE AID PF7(GOT-PF7) END-EXEC
                   EXEC CICS PUSH HANDLE END-EXEC
                   EXEC CICS POP HANDLE END-EXEC
                   EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
                   END-EXEC
                   STRING 'o' DELIMITED BY SIZE
                       INTO WS-TRAIL WITH POINTER WS-PTR
                   PERFORM NOTE-INPUT
      *        The first leg: the next key starts HA07
               WHEN 'HA06'
                   STRING 'w' DELIMITED BY SIZE
                       INTO WS-TRAIL WITH POINTER WS-PTR
                   EXEC CICS SEND TEXT FROM(WS-TRAIL) LENGTH(40) ERASE
                   END-EXEC
                   EXEC CICS RETURN TRANSID('HA07') END-EXEC
      *        HA07, started by CLEAR or a PA key: no data
               WHEN OTHER
                   EXEC CICS HANDLE AID CLEAR(GOT-CLEAR) ANYKEY(GOT-ANY)
                   END-EXEC
                   EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
                   END-EXEC
                   STRING 'n' DELIMITED BY SIZE
                       INTO WS-TRAIL WITH POINTER WS-PTR
                   PERFORM NOTE-INPUT
           END-EVALUATE
           GO TO SEND-TRAIL.
      *    The labels show the input: it was moved before the transfer
       GOT-PF7.
           STRING 'p' DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR
           PERFORM NOTE-INPUT
           GO TO SEND-TRAIL.
       GOT-ANY.
           STRING 'a' DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR
           PERFORM NOTE-INPUT
           GO TO SEND-TRAIL.
       GOT-CLEAR.
           STRING 'c' DELIMITED BY SIZE
               INTO WS-TRAIL WITH POINTER WS-PTR
           PERFORM NOTE-INPUT.
       SEND-TRAIL.
           EXEC CICS SEND TEXT FROM(WS-TRAIL) LENGTH(40) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       NOTE-INPUT.
           MOVE WS-INLEN TO WS-LEN-D
           STRING WS-LEN-D ' ' WS-INPUT(1:8)
               DELIMITED BY SIZE INTO WS-TRAIL WITH POINTER WS-PTR.
