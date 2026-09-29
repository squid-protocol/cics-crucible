      * cics-crucible pc-wizard: symbolic maps of mapset PCSET, as
      * BMS TYPE=DSECT lays them out (TIOAPFX=YES, no DSATTS).
      * Original (Apache-2.0).
       01  PCM1I.
           02  FILLER PIC X(12).
           02  NAMEL    COMP  PIC  S9(4).
           02  NAMEF    PICTURE X.
           02  FILLER REDEFINES NAMEF.
             03 NAMEA    PICTURE X.
           02  NAMEI  PIC X(15).
           02  MSG1L    COMP  PIC  S9(4).
           02  MSG1F    PICTURE X.
           02  FILLER REDEFINES MSG1F.
             03 MSG1A    PICTURE X.
           02  MSG1I  PIC X(40).
       01  PCM1O REDEFINES PCM1I.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  NAMEO  PIC X(15).
           02  FILLER PICTURE X(3).
           02  MSG1O  PIC X(40).
       01  PCM2I.
           02  FILLER PIC X(12).
           02  NAMEOUTL    COMP  PIC  S9(4).
           02  NAMEOUTF    PICTURE X.
           02  FILLER REDEFINES NAMEOUTF.
             03 NAMEOUTA    PICTURE X.
           02  NAMEOUTI  PIC X(15).
           02  AMTL    COMP  PIC  S9(4).
           02  AMTF    PICTURE X.
           02  FILLER REDEFINES AMTF.
             03 AMTA    PICTURE X.
           02  AMTI  PIC X(7).
           02  MSG2L    COMP  PIC  S9(4).
           02  MSG2F    PICTURE X.
           02  FILLER REDEFINES MSG2F.
             03 MSG2A    PICTURE X.
           02  MSG2I  PIC X(40).
       01  PCM2O REDEFINES PCM2I.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  NAMEOUTO  PIC X(15).
           02  FILLER PICTURE X(3).
           02  AMTO  PIC X(7).
           02  FILLER PICTURE X(3).
           02  MSG2O  PIC X(40).
       01  PCM3I.
           02  FILLER PIC X(12).
           02  SUMNAMEL    COMP  PIC  S9(4).
           02  SUMNAMEF    PICTURE X.
           02  FILLER REDEFINES SUMNAMEF.
             03 SUMNAMEA    PICTURE X.
           02  SUMNAMEI  PIC X(15).
           02  SUMAMTL    COMP  PIC  S9(4).
           02  SUMAMTF    PICTURE X.
           02  FILLER REDEFINES SUMAMTF.
             03 SUMAMTA    PICTURE X.
           02  SUMAMTI  PIC X(10).
           02  MSG3L    COMP  PIC  S9(4).
           02  MSG3F    PICTURE X.
           02  FILLER REDEFINES MSG3F.
             03 MSG3A    PICTURE X.
           02  MSG3I  PIC X(40).
       01  PCM3O REDEFINES PCM3I.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  SUMNAMEO  PIC X(15).
           02  FILLER PICTURE X(3).
           02  SUMAMTO  PIC X(10).
           02  FILLER PICTURE X(3).
           02  MSG3O  PIC X(40).
