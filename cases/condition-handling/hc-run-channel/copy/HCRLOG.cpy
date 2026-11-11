      * One trace record, 45 bytes, written to a TS queue after a
      * command (containers and a channel's name are not events).
       01  WS-REC.
           05  LG-WHO            PIC X(2).
           05  LG-CHAN           PIC X(16).
           05  LG-RESP           PIC 9(3).
           05  LG-RESP2          PIC 9(3).
           05  LG-LEN            PIC 9(5).
           05  LG-DATA           PIC X(16).
