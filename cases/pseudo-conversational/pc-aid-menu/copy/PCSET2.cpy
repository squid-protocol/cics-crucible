      * cics-crucible pc-aid-menu: symbolic maps of mapset PCSET2,
      * as BMS TYPE=DSECT lays them out (TIOAPFX=YES, no DSATTS).
      * Original (Apache-2.0).
       01  PCMNI.
           02  FILLER PIC X(12).
           02  OPTL    COMP  PIC  S9(4).
           02  OPTF    PICTURE X.
           02  FILLER REDEFINES OPTF.
             03 OPTA    PICTURE X.
           02  OPTI  PIC X(1).
           02  VISITSL    COMP  PIC  S9(4).
           02  VISITSF    PICTURE X.
           02  FILLER REDEFINES VISITSF.
             03 VISITSA    PICTURE X.
           02  VISITSI  PIC X(4).
           02  MSGL    COMP  PIC  S9(4).
           02  MSGF    PICTURE X.
           02  FILLER REDEFINES MSGF.
             03 MSGA    PICTURE X.
           02  MSGI  PIC X(40).
       01  PCMNO REDEFINES PCMNI.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  OPTO  PIC X(1).
           02  FILLER PICTURE X(3).
           02  VISITSO  PIC X(4).
           02  FILLER PICTURE X(3).
           02  MSGO  PIC X(40).
       01  PCDTI.
           02  FILLER PIC X(12).
           02  DVISITSL    COMP  PIC  S9(4).
           02  DVISITSF    PICTURE X.
           02  FILLER REDEFINES DVISITSF.
             03 DVISITSA    PICTURE X.
           02  DVISITSI  PIC X(4).
           02  DLASTL    COMP  PIC  S9(4).
           02  DLASTF    PICTURE X.
           02  FILLER REDEFINES DLASTF.
             03 DLASTA    PICTURE X.
           02  DLASTI  PIC X(4).
           02  DTRANL    COMP  PIC  S9(4).
           02  DTRANF    PICTURE X.
           02  FILLER REDEFINES DTRANF.
             03 DTRANA    PICTURE X.
           02  DTRANI  PIC X(4).
           02  DMSGL    COMP  PIC  S9(4).
           02  DMSGF    PICTURE X.
           02  FILLER REDEFINES DMSGF.
             03 DMSGA    PICTURE X.
           02  DMSGI  PIC X(40).
       01  PCDTO REDEFINES PCDTI.
           02  FILLER PIC X(12).
           02  FILLER PICTURE X(3).
           02  DVISITSO  PIC X(4).
           02  FILLER PICTURE X(3).
           02  DLASTO  PIC X(4).
           02  FILLER PICTURE X(3).
           02  DTRANO  PIC X(4).
           02  FILLER PICTURE X(3).
           02  DMSGO  PIC X(40).
