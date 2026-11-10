      * cics-crucible hc-send-map-freekb: symbolic maps of mapset
      * HCFSET, as BMS TYPE=DSECT lays them out (TIOAPFX=YES, no
      * DSATTS). Original (Apache-2.0).
       01  HCFAI.
           02  FILLER PIC X(12).
           02  AMSGL    COMP  PIC  S9(4).
           02  AMSGF    PICTURE X.
           02  FILLER REDEFINES AMSGF.
             03 AMSGA    PICTURE X.
           02  AMSGI  PIC X(12).
           02  ANAMEL    COMP  PIC  S9(4).
           02  ANAMEF    PICTURE X.
           02  FILLER REDEFINES ANAMEF.
             03 ANAMEA    PICTURE X.
           02  ANAMEI  PIC X(8).
       01  HCFAO REDEFINES HCFAI.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  AMSGO  PIC X(12).
           02  FILLER PICTURE X(3).
           02  ANAMEO  PIC X(8).
       01  HCFBI.
           02  FILLER PIC X(12).
           02  BMSGL    COMP  PIC  S9(4).
           02  BMSGF    PICTURE X.
           02  FILLER REDEFINES BMSGF.
             03 BMSGA    PICTURE X.
           02  BMSGI  PIC X(12).
           02  BNAMEL    COMP  PIC  S9(4).
           02  BNAMEF    PICTURE X.
           02  FILLER REDEFINES BNAMEF.
             03 BNAMEA    PICTURE X.
           02  BNAMEI  PIC X(8).
       01  HCFBO REDEFINES HCFBI.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  BMSGO  PIC X(12).
           02  FILLER PICTURE X(3).
           02  BNAMEO  PIC X(8).
