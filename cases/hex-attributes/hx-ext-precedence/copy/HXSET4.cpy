      * cics-crucible hx-ext-precedence: symbolic map of mapset
      * HXSET4 as BMS TYPE=DSECT lays it out (TIOAPFX=YES,
      * DSATTS=(COLOR,HILIGHT)). Original (Apache-2.0).
       01  HXM4I.
           02  FILLER PIC X(12).
           02  FAL    COMP  PIC  S9(4).
           02  FAF    PICTURE X.
           02  FILLER REDEFINES FAF.
             03 FAA    PICTURE X.
           02  FILLER   PICTURE X(2).
           02  FAI  PIC X(8).
           02  FBL    COMP  PIC  S9(4).
           02  FBF    PICTURE X.
           02  FILLER REDEFINES FBF.
             03 FBA    PICTURE X.
           02  FILLER   PICTURE X(2).
           02  FBI  PIC X(8).
           02  FCL    COMP  PIC  S9(4).
           02  FCF    PICTURE X.
           02  FILLER REDEFINES FCF.
             03 FCA    PICTURE X.
           02  FILLER   PICTURE X(2).
           02  FCI  PIC X(8).
       01  HXM4O REDEFINES HXM4I.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  FAC    PICTURE X.
           02  FAH    PICTURE X.
           02  FAO  PIC X(8).
           02  FILLER PICTURE X(3).
           02  FBC    PICTURE X.
           02  FBH    PICTURE X.
           02  FBO  PIC X(8).
           02  FILLER PICTURE X(3).
           02  FCC    PICTURE X.
           02  FCH    PICTURE X.
           02  FCO  PIC X(8).
