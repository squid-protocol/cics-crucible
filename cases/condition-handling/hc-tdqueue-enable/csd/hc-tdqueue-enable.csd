DEFINE PROGRAM(HCTDEN) GROUP(CRUCHC) LANGUAGE(COBOL)
DEFINE TRANSACTION(HCTD) GROUP(CRUCHC) PROGRAM(HCTDEN)
* One intrapartition queue, not recoverable, no trigger level (SPEC section 2).
* HCNQ, used by the undefined-queue mode, is deliberately not defined.
DEFINE TDQUEUE(HCQ1) GROUP(CRUCHC) TYPE(INTRA) RECOVSTATUS(NO)
