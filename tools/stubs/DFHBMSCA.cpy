      * cics-crucible stand-in for IBM's DFHBMSCA copybook, written
      * for this repository (Apache-2.0), NOT IBM's copybook. Values
      * are the EBCDIC bytes IBM documents (CICS TS, BMS constants).
      * Used only by tools/syntax_check.py.
       01  DFHBMSCA.
           02  DFHBMPEM  PIC X VALUE X'19'.
           02  DFHBMPNL  PIC X VALUE X'15'.
           02  DFHBMASK  PIC X VALUE X'F0'.
           02  DFHBMUNP  PIC X VALUE X'40'.
           02  DFHBMUNN  PIC X VALUE X'50'.
           02  DFHBMPRO  PIC X VALUE X'60'.
           02  DFHBMBRY  PIC X VALUE X'C8'.
           02  DFHBMDAR  PIC X VALUE X'4C'.
           02  DFHBMFSE  PIC X VALUE X'C1'.
           02  DFHBMPRF  PIC X VALUE X'61'.
           02  DFHBMASF  PIC X VALUE X'F1'.
           02  DFHBMASB  PIC X VALUE X'F8'.
           02  DFHBMEOF  PIC X VALUE X'80'.
           02  DFHBMCUR  PIC X VALUE X'02'.
           02  DFHBMEC   PIC X VALUE X'82'.
           02  DFHBMFLG  PIC X VALUE X'00'.
           02  DFHBMDET  PIC X VALUE X'FF'.
           02  DFHDFT    PIC X VALUE X'FF'.
           02  DFHDFCOL  PIC X VALUE X'00'.
           02  DFHBLUE   PIC X VALUE X'F1'.
           02  DFHRED    PIC X VALUE X'F2'.
           02  DFHPINK   PIC X VALUE X'F3'.
           02  DFHGREEN  PIC X VALUE X'F4'.
           02  DFHTURQ   PIC X VALUE X'F5'.
           02  DFHYELLO  PIC X VALUE X'F6'.
           02  DFHNEUTR  PIC X VALUE X'F7'.
           02  DFHDFHI   PIC X VALUE X'00'.
           02  DFHBLINK  PIC X VALUE X'F1'.
           02  DFHREVRS  PIC X VALUE X'F2'.
           02  DFHUNDLN  PIC X VALUE X'F4'.
           02  DFHUNNOD  PIC X VALUE X'4D'.
           02  DFHUNIMD  PIC X VALUE X'C9'.
           02  DFHUNNUM  PIC X VALUE X'D1'.
           02  DFHUNNUB  PIC X VALUE X'D8'.
           02  DFHUNINT  PIC X VALUE X'D9'.
           02  DFHUNNON  PIC X VALUE X'5D'.
           02  DFHPROTI  PIC X VALUE X'E8'.
           02  DFHPROTN  PIC X VALUE X'6C'.
