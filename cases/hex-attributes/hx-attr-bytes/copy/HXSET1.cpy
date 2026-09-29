      * cics-crucible hx-attr-bytes: symbolic map of mapset HXSET1,
      * as BMS TYPE=DSECT lays it out (TIOAPFX=YES, no DSATTS).
      * Original (Apache-2.0).
       01  HXM1I.
           02  FILLER PIC X(12).
           02  STATL    COMP  PIC  S9(4).
           02  STATF    PICTURE X.
           02  FILLER REDEFINES STATF.
             03 STATA    PICTURE X.
           02  STATI  PIC X(12).
           02  BRITEL    COMP  PIC  S9(4).
           02  BRITEF    PICTURE X.
           02  FILLER REDEFINES BRITEF.
             03 BRITEA    PICTURE X.
           02  BRITEI  PIC X(12).
           02  NAMEL    COMP  PIC  S9(4).
           02  NAMEF    PICTURE X.
           02  FILLER REDEFINES NAMEF.
             03 NAMEA    PICTURE X.
           02  NAMEI  PIC X(10).
           02  SECRETL    COMP  PIC  S9(4).
           02  SECRETF    PICTURE X.
           02  FILLER REDEFINES SECRETF.
             03 SECRETA    PICTURE X.
           02  SECRETI  PIC X(8).
           02  RAWL    COMP  PIC  S9(4).
           02  RAWF    PICTURE X.
           02  FILLER REDEFINES RAWF.
             03 RAWA    PICTURE X.
           02  RAWI  PIC X(8).
           02  BLINKYL    COMP  PIC  S9(4).
           02  BLINKYF    PICTURE X.
           02  FILLER REDEFINES BLINKYF.
             03 BLINKYA    PICTURE X.
           02  BLINKYI  PIC X(8).
           02  TWIDDLEL    COMP  PIC  S9(4).
           02  TWIDDLEF    PICTURE X.
           02  FILLER REDEFINES TWIDDLEF.
             03 TWIDDLEA    PICTURE X.
           02  TWIDDLEI  PIC X(8).
           02  LEFTOVRL    COMP  PIC  S9(4).
           02  LEFTOVRF    PICTURE X.
           02  FILLER REDEFINES LEFTOVRF.
             03 LEFTOVRA    PICTURE X.
           02  LEFTOVRI  PIC X(8).
           02  NULATRL    COMP  PIC  S9(4).
           02  NULATRF    PICTURE X.
           02  FILLER REDEFINES NULATRF.
             03 NULATRA    PICTURE X.
           02  NULATRI  PIC X(8).
           02  FSETFL    COMP  PIC  S9(4).
           02  FSETFF    PICTURE X.
           02  FILLER REDEFINES FSETFF.
             03 FSETFA    PICTURE X.
           02  FSETFI  PIC X(8).
       01  HXM1O REDEFINES HXM1I.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  STATO  PIC X(12).
           02  FILLER PICTURE X(3).
           02  BRITEO  PIC X(12).
           02  FILLER PICTURE X(3).
           02  NAMEO  PIC X(10).
           02  FILLER PICTURE X(3).
           02  SECRETO  PIC X(8).
           02  FILLER PICTURE X(3).
           02  RAWO  PIC X(8).
           02  FILLER PICTURE X(3).
           02  BLINKYO  PIC X(8).
           02  FILLER PICTURE X(3).
           02  TWIDDLEO  PIC X(8).
           02  FILLER PICTURE X(3).
           02  LEFTOVRO  PIC X(8).
           02  FILLER PICTURE X(3).
           02  NULATRO  PIC X(8).
           02  FILLER PICTURE X(3).
           02  FSETFO  PIC X(8).
