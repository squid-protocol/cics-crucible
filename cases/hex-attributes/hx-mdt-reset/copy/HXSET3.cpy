      * cics-crucible hx-mdt-reset: symbolic map of mapset HXSET3,
      * as BMS TYPE=DSECT lays it out (TIOAPFX=YES, no DSATTS).
      * Original (Apache-2.0).
       01  HXM3I.
           02  FILLER PIC X(12).
           02  MSGL    COMP  PIC  S9(4).
           02  MSGF    PICTURE X.
           02  FILLER REDEFINES MSGF.
             03 MSGA    PICTURE X.
           02  MSGI  PIC X(12).
           02  NAMEL    COMP  PIC  S9(4).
           02  NAMEF    PICTURE X.
           02  FILLER REDEFINES NAMEF.
             03 NAMEA    PICTURE X.
           02  NAMEI  PIC X(8).
           02  NOTEL    COMP  PIC  S9(4).
           02  NOTEF    PICTURE X.
           02  FILLER REDEFINES NOTEF.
             03 NOTEA    PICTURE X.
           02  NOTEI  PIC X(8).
       01  HXM3O REDEFINES HXM3I.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  MSGO  PIC X(12).
           02  FILLER PICTURE X(3).
           02  NAMEO  PIC X(8).
           02  FILLER PICTURE X(3).
           02  NOTEO  PIC X(8).
