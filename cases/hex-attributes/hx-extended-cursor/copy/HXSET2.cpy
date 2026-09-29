      * cics-crucible hx-extended-cursor: symbolic map of mapset
      * HXSET2 as BMS TYPE=DSECT lays it out (TIOAPFX=YES,
      * DSATTS=(COLOR,HILIGHT)). Original (Apache-2.0).
       01  HXM2I.
           02  FILLER PIC X(12).
           02  ACCTL    COMP  PIC  S9(4).
           02  ACCTF    PICTURE X.
           02  FILLER REDEFINES ACCTF.
             03 ACCTA    PICTURE X.
           02  FILLER   PICTURE X(2).
           02  ACCTI  PIC X(6).
           02  AMOUNTL    COMP  PIC  S9(4).
           02  AMOUNTF    PICTURE X.
           02  FILLER REDEFINES AMOUNTF.
             03 AMOUNTA    PICTURE X.
           02  FILLER   PICTURE X(2).
           02  AMOUNTI  PIC X(7).
           02  MSGL    COMP  PIC  S9(4).
           02  MSGF    PICTURE X.
           02  FILLER REDEFINES MSGF.
             03 MSGA    PICTURE X.
           02  FILLER   PICTURE X(2).
           02  MSGI  PIC X(30).
       01  HXM2O REDEFINES HXM2I.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  ACCTC    PICTURE X.
           02  ACCTH    PICTURE X.
           02  ACCTO  PIC X(6).
           02  FILLER PICTURE X(3).
           02  AMOUNTC    PICTURE X.
           02  AMOUNTH    PICTURE X.
           02  AMOUNTO  PIC X(7).
           02  FILLER PICTURE X(3).
           02  MSGC    PICTURE X.
           02  MSGH    PICTURE X.
           02  MSGO  PIC X(30).
