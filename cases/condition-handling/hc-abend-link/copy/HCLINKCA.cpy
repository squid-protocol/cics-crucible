      *---------------------------------------------------------------*
      * cics-crucible hc-abend-link: the 20-byte COMMAREA HCMAIN      *
      * passes to HCSUB on LINK. Original (Apache-2.0).               *
      *---------------------------------------------------------------*
           05  CA-MODE               PIC X.
           05  CA-TRAIL              PIC X(9).
           05  CA-RESULT             PIC X(4).
           05  CA-COUNT              PIC S9(4) COMP.
           05  CA-SPARE              PIC X(4).
