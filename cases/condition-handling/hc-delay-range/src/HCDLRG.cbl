       IDENTIFICATION DIVISION.
       PROGRAM-ID. HCDLRG.
      *---------------------------------------------------------------*
      * cics-crucible  condition-handling / hc-delay-range            *
      * Original program (Apache-2.0).                                *
      * HCDR reads its mode from the terminal input (HCDR B or G):    *
      *   B  eight DELAYs, each with ONE value out of IBM's range:    *
      *      tag, RESP and RESP2 go to TS queue HCLOG (DELAY is not   *
      *      an event)                                                *
      *   G  seven DELAYs, each at the top of its range: tag and RESP *
      *---------------------------------------------------------------*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT              PIC X(8)  VALUE SPACES.
       01  WS-INLEN              PIC S9(4) COMP VALUE 8.
       01  WS-MODE               PIC X     VALUE SPACE.
       01  WS-INT-MIN60          PIC S9(7) COMP-3 VALUE 6000.
       01  WS-INT-SEC60          PIC S9(7) COMP-3 VALUE 60.
       01  WS-INT-OK             PIC S9(7) COMP-3 VALUE 5959.
       01  WS-RESP               PIC S9(8) COMP VALUE 0.
       01  WS-RESP2              PIC S9(8) COMP VALUE 0.
       01  WS-DONE               PIC X(8)  VALUE 'DONE OK '.
       01  WS-BLOG.
           05  BLOG-TAG          PIC XX    VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  BLOG-RESP         PIC 99    VALUE 0.
           05  FILLER            PIC X(3)  VALUE ' 2='.
           05  BLOG-RESP2        PIC 99    VALUE 0.
       01  WS-GLOG.
           05  GLOG-TAG          PIC XX    VALUE SPACES.
           05  FILLER            PIC X(3)  VALUE ' R='.
           05  GLOG-RESP         PIC 99    VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           EXEC CICS RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)
           END-EXEC
           MOVE WS-INPUT(6:1) TO WS-MODE
           EVALUATE WS-MODE
               WHEN 'B'
                   PERFORM BAD-PARA
               WHEN 'G'
                   PERFORM GOOD-PARA
           END-EVALUATE
           EXEC CICS SEND TEXT FROM(WS-DONE) LENGTH(8) ERASE
           END-EXEC
           EXEC CICS RETURN END-EXEC.
       BAD-PARA.
           EXEC CICS DELAY FOR HOURS(100) RESP(WS-RESP)
                     RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B1' TO BLOG-TAG
           PERFORM BLOG-PARA
           EXEC CICS DELAY FOR HOURS(1) MINUTES(60) RESP(WS-RESP)
                     RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B2' TO BLOG-TAG
           PERFORM BLOG-PARA
           EXEC CICS DELAY FOR MINUTES(1) SECONDS(60) RESP(WS-RESP)
                     RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B3' TO BLOG-TAG
           PERFORM BLOG-PARA
           EXEC CICS DELAY FOR SECONDS(1) MILLISECS(1000)
                     RESP(WS-RESP) RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B4' TO BLOG-TAG
           PERFORM BLOG-PARA
           EXEC CICS DELAY INTERVAL(WS-INT-MIN60) RESP(WS-RESP)
                     RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B5' TO BLOG-TAG
           PERFORM BLOG-PARA
           EXEC CICS DELAY INTERVAL(WS-INT-SEC60) RESP(WS-RESP)
                     RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B6' TO BLOG-TAG
           PERFORM BLOG-PARA
           EXEC CICS DELAY FOR MINUTES(6000) RESP(WS-RESP)
                     RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B7' TO BLOG-TAG
           PERFORM BLOG-PARA
           EXEC CICS DELAY FOR SECONDS(360000) RESP(WS-RESP)
                     RESP2(WS-RESP2)
           END-EXEC
           MOVE 'B8' TO BLOG-TAG
           PERFORM BLOG-PARA.
       GOOD-PARA.
           EXEC CICS DELAY FOR HOURS(99) RESP(WS-RESP)
           END-EXEC
           MOVE 'G1' TO GLOG-TAG
           PERFORM GLOG-PARA
           EXEC CICS DELAY FOR HOURS(1) MINUTES(59) RESP(WS-RESP)
           END-EXEC
           MOVE 'G2' TO GLOG-TAG
           PERFORM GLOG-PARA
           EXEC CICS DELAY FOR MINUTES(1) SECONDS(59) RESP(WS-RESP)
           END-EXEC
           MOVE 'G3' TO GLOG-TAG
           PERFORM GLOG-PARA
           EXEC CICS DELAY FOR SECONDS(1) MILLISECS(999)
                     RESP(WS-RESP)
           END-EXEC
           MOVE 'G4' TO GLOG-TAG
           PERFORM GLOG-PARA
           EXEC CICS DELAY INTERVAL(WS-INT-OK) RESP(WS-RESP)
           END-EXEC
           MOVE 'G5' TO GLOG-TAG
           PERFORM GLOG-PARA
           EXEC CICS DELAY FOR MINUTES(5999) RESP(WS-RESP)
           END-EXEC
           MOVE 'G6' TO GLOG-TAG
           PERFORM GLOG-PARA
           EXEC CICS DELAY FOR SECONDS(359999) RESP(WS-RESP)
           END-EXEC
           MOVE 'G7' TO GLOG-TAG
           PERFORM GLOG-PARA.
       BLOG-PARA.
           MOVE WS-RESP TO BLOG-RESP
           MOVE WS-RESP2 TO BLOG-RESP2
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-BLOG)
                     LENGTH(12)
           END-EXEC.
       GLOG-PARA.
           MOVE WS-RESP TO GLOG-RESP
           EXEC CICS WRITEQ TS QUEUE('HCLOG') FROM(WS-GLOG)
                     LENGTH(7)
           END-EXEC.
