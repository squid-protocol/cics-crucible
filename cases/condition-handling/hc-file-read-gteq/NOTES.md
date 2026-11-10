# hc-file-read-gteq: READ with GTEQ, GENERIC and GENERIC GTEQ on a KSDS, KEYLENGTH shorter than the key; NOTFND (RESP2 80)

## The trap

`HCRGTQ` (transaction `HC85`) is typed with a mode after `HC85`. It works on file `HCRG`, a KSDS seeded from `data/HCRG.dat` (five
16-byte records: key 4, name 8, quantity 4; keys `A100`, `A200`, `A300`, `B100`, `B300`) and logs each read to TS queue `HCLOG`.
Every read is the `INTO` form with `LENGTH` a data area set to 16. No case so far issues a search read: `hc-file-read-set` and
`hc-file-into-browse` read an exact full key. Item format, 38 bytes: tag (3), ` R=`, RESP (2), ` S=`, RESP2 (3), ` L=`, the length
after the read (2), ` D=`, the 16-byte record (blank unless NORMAL). `RIDFLD` is never logged after a read (see Avoided ambiguities).

* **G**: `READ GTEQ KEYLENGTH(4)` of `A150`, `B100`, `B400`, `A000`.
* **P**: eight reads whose `RIDFLD` field is exactly `KEYLENGTH` bytes: `GENERIC` of `A`, `B`, `C` (KEYLENGTH 1); `GENERIC GTEQ` of
  `A2`, `B2` (KEYLENGTH 2); `GENERIC` of `A4` (KEYLENGTH 2), `GENERIC GTEQ` of `A4`; `GENERIC` of `A20` (KEYLENGTH 3).

## Why a naive translation breaks

* A port that treats `GTEQ` as `EQUAL` answers NOTFND for `A150` and `A000`.
* A port that takes `GENERIC` as an exact match on the shortened key, or ignores `KEYLENGTH`, finds nothing for `A` or `B`.
* A port that lets `GENERIC` fall through to the next greater key (as `GTEQ` does) returns a record for `A4` and `C`, which IBM answers
  with NOTFND.

## Expected behaviour

Model (SPEC section 2): file `HCRG` is a local VSAM KSDS, enabled, opened on first use, `READ(YES)`; each scenario starts at
10:00:00 on 2026-03-02 with `HC85 <mode>` typed on T001. NOTFND is RESP 13, RESP2 80 [READ].

* **`gteq`** (G): `GTEQ` returns the record with the key equal to or the first key greater than the search key [READ].
  G1 `A150` returns `A200BRAVO   0020`; G2 `B100` returns `B100DELTA   0040`; G3 `B400` has no greater key, NOTFND RESP2 80;
  G4 `A000` returns `A100ALPHA   0010`.
* **`generic`** (P): `GENERIC` with `KEYLENGTH(n)` searches on the first n bytes of the key and returns the first record that matches
  them [READ]. P1 `A` returns `A100`; P2 `B` returns `B100`; P3 `C` has no match, NOTFND RESP2 80. P4 `A2` `GENERIC GTEQ` returns
  `A200`. P5 `A4` `GENERIC` has no match, NOTFND RESP2 80; P6 `A4` `GENERIC GTEQ` returns the next greater, `B100`. P7 `B2`
  `GENERIC GTEQ` returns `B300`. P8 `A20` with `KEYLENGTH(3)` returns `A200`.
* In every scenario the program sends `DONE OK` and RETURNs; the file is never changed, so `final.files` is the seed.

## What a correct port must do

* Position a `GTEQ` read on the first record at or above the key, and answer NOTFND RESP2 80 above the last key.
* Honour `KEYLENGTH` on `GENERIC`: match only the first n bytes, return the first record with that prefix, NOTFND RESP2 80 otherwise.
* Combine `GENERIC` with `GTEQ`: first the prefix match, otherwise the first record above the shortened key.
* Return the whole record in `INTO` and its length in `LENGTH`.

## Avoided ambiguities

* **RIDFLD after READ**: the READ page documents no update of `RIDFLD` on a read, so the program never reads it afterwards.
* **What the log records as the READ event's `ridfld`**: IBM does not settle it for a shortened key, so every `RIDFLD` field is
  exactly `KEYLENGTH` bytes long (`WS-KEY1`, `WS-KEY2`, `WS-KEY3`); the event's `ridfld` is then the field in full whatever it is.
* **KEYLENGTH errors (INVREQ RESP2 25 with `GENERIC` and `KEYLENGTH` not below the full key, 26 `KEYLENGTH` without `GENERIC` and not
  the key length, 42 `GENERIC` with `KEYLENGTH` below 0)**: not in this case. The translated Java port does not record a READ event
  when it refuses `KEYLENGTH`, so the expected log (which has one) cannot pass there; a Remaining slice for the translator and
  runtime, never an edit of the log.
* **LENGERR / a short area**, `UPDATE` / `TOKEN`, `RBA` / `XRBA`, recoverable files, locks, RLS: not used.

## Citations

All CICS TS 6.x (IBM Documentation, SSJL4D_6.x, fetched 2026-11-10).

* [READ] EXEC CICS READ, DATASET, INTO, LENGTH, RIDFLD, KEYLENGTH, GENERIC, GTEQ, NOTFND (RESP2 80), INVREQ (RESP2 25, 26, 42):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_read.html

## Stated key

`jcl/DEFVSAM.jcl` is the IDCAMS DEFINE CLUSTER for the CSD file's DSNAME: INDEXED, `KEYS(4 0)` (the key is the first 4 bytes, the
length the full-key `KEYLENGTH` and the prefix lengths of the case refer to), `RECORDSIZE(16 16)` (the seed record width). IBM (z/OS
DFSMS Access Method Services, DEFINE CLUSTER): KEYS(length offset) specifies the length and position of the key field of the records.
A CICS file definition carries no key, so the case states it here; without it the det port has a "no key" hole.
