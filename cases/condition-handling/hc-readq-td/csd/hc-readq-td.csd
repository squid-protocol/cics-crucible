* cics-crucible condition-handling / hc-readq-td
DEFINE PROGRAM(HCRQTD) GROUP(CRUCHC) LANGUAGE(COBOL)
DEFINE TRANSACTION(HC82) GROUP(CRUCHC) PROGRAM(HCRQTD)
* One intrapartition queue, not recoverable, no trigger level (SPEC section 2).
* HCNQ, used by the undefined-queue mode, is deliberately not defined.
DEFINE TDQUEUE(HCQ1) GROUP(CRUCHC) TYPE(INTRA) RECOVSTATUS(NO)
