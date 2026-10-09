      * cics-crucible hc-map-not-in-mapset: map of mapset HCSET3,
      * as BMS TYPE=DSECT lays it out (TIOAPFX=YES, no DSATTS).
      * Original (Apache-2.0).
       01  HCM3I.
           02  FILLER PIC X(12).
           02  NAMEL    COMP  PIC  S9(4).
           02  NAMEF    PICTURE X.
           02  FILLER REDEFINES NAMEF.
             03 NAMEA    PICTURE X.
           02  NAMEI  PIC X(12).
       01  HCM3O REDEFINES HCM3I.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  NAMEO  PIC X(12).
