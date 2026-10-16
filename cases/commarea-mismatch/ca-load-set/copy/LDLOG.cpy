      * One trace record: what a LOAD returned and what the program
      * then saw, written to TS queue LDLOG after it. PTR and LEN are
      * flags, never values: Y = the pointer is not null / LENGTH is
      * above zero, N = it is not, - = not read (the command failed).
       01  WS-LOG.
           05  LG-TAG            PIC X(4).
           05  LG-RESP           PIC 9(3).
           05  LG-RESP2          PIC 9(3).
           05  LG-PTR            PIC X.
           05  LG-LEN            PIC X.
