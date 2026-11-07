      * cics-crucible hx-cursor-offset: symbolic map of mapset HXSET5,
      * as BMS TYPE=DSECT lays it out (TIOAPFX=YES, no DSATTS).
      * Original (Apache-2.0).
       01  HXM5I.
           02  FILLER PIC X(12).
           02  MSGL    COMP  PIC  S9(4).
           02  MSGF    PICTURE X.
           02  FILLER REDEFINES MSGF.
             03 MSGA    PICTURE X.
           02  MSGI  PIC X(12).
           02  ACCTL    COMP  PIC  S9(4).
           02  ACCTF    PICTURE X.
           02  FILLER REDEFINES ACCTF.
             03 ACCTA    PICTURE X.
           02  ACCTI  PIC X(8).
           02  NOTEL    COMP  PIC  S9(4).
           02  NOTEF    PICTURE X.
           02  FILLER REDEFINES NOTEF.
             03 NOTEA    PICTURE X.
           02  NOTEI  PIC X(8).
       01  HXM5O REDEFINES HXM5I.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  MSGO  PIC X(12).
           02  FILLER PICTURE X(3).
           02  ACCTO  PIC X(8).
           02  FILLER PICTURE X(3).
           02  NOTEO  PIC X(8).
