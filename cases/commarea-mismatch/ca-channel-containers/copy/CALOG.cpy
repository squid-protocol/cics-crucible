      * One trace record: what a command returned, written to TS
      * queue CALOG after it (containers are not events).
       01  WS-LOG.
           05  LG-TAG            PIC X(4).
           05  LG-RESP           PIC 9(3).
           05  LG-RESP2          PIC 9(3).
           05  LG-LEN            PIC 9(5).
           05  LG-DATA           PIC X(16).
