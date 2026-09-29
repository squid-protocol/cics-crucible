      *---------------------------------------------------------------*
      * cics-crucible ca-link-lengths: the 100-byte request header    *
      * both programs share (level 10, placed under a 05 group).      *
      * Original (Apache-2.0).                                        *
      *---------------------------------------------------------------*
               10  CA-EYE            PIC X(4).
               10  CA-VERSION        PIC X.
               10  CA-RC             PIC X(2).
               10  CA-SEEN-LEN       PIC S9(4) COMP.
               10  CA-REQUEST        PIC X(20).
               10  CA-REPLY          PIC X(20).
               10  CA-SPARE          PIC X(51).
