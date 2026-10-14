      * One trace record: what a command returned and what the
      * program then saw through its pointer, written to TS queue
      * RSLOG after the command.
       01  WS-LOG.
           05  LG-TAG            PIC X(4).
           05  LG-RESP           PIC 9(3).
           05  LG-LEN            PIC 9(4).
           05  LG-DATA           PIC X(20).
