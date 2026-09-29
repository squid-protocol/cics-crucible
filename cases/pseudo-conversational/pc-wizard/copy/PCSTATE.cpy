      *---------------------------------------------------------------*
      * cics-crucible pc-wizard: the 30-byte conversation state that  *
      * travels in the COMMAREA between the wizard's tasks.           *
      * Original (Apache-2.0).                                        *
      *---------------------------------------------------------------*
           05  PC-STEP               PIC 9.
           05  PC-NAME               PIC X(15).
           05  PC-AMOUNT             PIC S9(5)V99 COMP-3.
           05  PC-ERRORS             PIC S9(4) COMP.
           05  PC-BACK               PIC X.
           05  PC-SPARE              PIC X(7).
