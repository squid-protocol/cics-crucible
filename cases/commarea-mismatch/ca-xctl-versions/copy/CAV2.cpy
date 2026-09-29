      *---------------------------------------------------------------*
      * cics-crucible ca-xctl-versions: version-2 customer COMMAREA,  *
      * 80 bytes. Its first 10 bytes are the version-1 layout.        *
      * Original (Apache-2.0).                                        *
      *---------------------------------------------------------------*
           05  V2-VERSION            PIC X.
           05  V2-CUSTID             PIC X(5).
           05  V2-VISITS             PIC 9(4).
           05  V2-TIER               PIC X(10).
           05  V2-BALANCE            PIC S9(7)V99 COMP-3.
           05  V2-NOTE               PIC X(55).
