      * cics-crucible hc-handle-mapfail: symbolic map of mapset HMSET,
      * as BMS TYPE=DSECT lays it out (TIOAPFX=YES, no DSATTS).
      * Original (Apache-2.0).
       01  HMAPI.
           02  FILLER PIC X(12).
           02  OPTL    COMP  PIC  S9(4).
           02  OPTF    PICTURE X.
           02  FILLER REDEFINES OPTF.
             03 OPTA    PICTURE X.
           02  OPTI  PIC X(1).
       01  HMAPO REDEFINES HMAPI.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  OPTO  PIC X(1).
