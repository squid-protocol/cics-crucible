* cics-crucible commarea-mismatch / ca-address-eib-commarea
DEFINE PROGRAM(CAEBCA) GROUP(CRUCCAA) LANGUAGE(COBOL)
DEFINE PROGRAM(CAEBSB) GROUP(CRUCCAA) LANGUAGE(COBOL)
DEFINE TRANSACTION(CA0K) GROUP(CRUCCAA) PROGRAM(CAEBCA)
* CANQ, used by mode Q, is deliberately not defined (the READQ TD gives QIDERR)
