#lang racket

(require ffi/unsafe
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

;; this half works with my hacked version of zmq
;; butt hits an error

(define uri "tcp://127.0.0.1:1337")

(define (zmq-recv-no/block socket)
  (let ([msg (zmq:make-empty-msg)])
    (zmq:socket-recv-msg! msg socket 'NOBLOCK)
    (dynamic-wind
      void
      (lambda ()
        (bytes-copy (zmq:msg-data msg)))
      (lambda ()
        (zmq:msg-close! msg)
        (free msg)))))

(define (zmq-send-no/block socket bytes)
  (let ([zmq-msg (zmq:make-msg-with-data bytes)])
	(dynamic-wind
	  void
	  (lambda ()
		(zmq:socket-send-msg! zmq-msg socket 'NOBLOCK)
		(void))
	  (lambda ()
		(zmq:msg-close! zmq-msg)
		(free zmq-msg)))))

;; responder
(thread
 (lambda ()
   (let* ([context (zmq:context 1)]
          [socket (zmq:socket context 'REP)])
     (zmq:socket-bind! socket uri)
     (define (printf-recvd recv-bytes)
       (printf (string-append
                "Received Data: "
                (bytes->string/utf-8 recv-bytes)
                "\n")))
     (define (make-response-bytes recv-bytes)
       (string->bytes/utf-8
        (string-append (bytes->string/utf-8 recv-bytes) " - echoed!")))
     (define (send-response recv-bytes)
       (zmq-send-no/block socket (make-response-bytes recv-bytes))
       (printf "responder-responded\n"))
     (let listen ()
       (let ([received (zmq:socket-recv! socket)])
         (printf "responder-listening\n")
         (send-response received))
       (listen))
     (zmq:socket-close! socket)
     (zmq:context-close! context))))

;; requester
(thread
 (lambda ()
   (let* ([context (zmq:context 1)]
          [socket (zmq:socket context 'REQ)])
	 (zmq:socket-connect! socket uri)
	 (define (make-request-bytes count)
	   (string->bytes/utf-8
		(string-append
		 "Hello, "
		 (number->string count))))
	 (define (printf-response recv-bytes)
	   (printf (string-append (bytes->string/utf-8 recv-bytes) "\n")))
     (for ([count 5])
	   (printf "requester-sending\n")
	   (zmq-send-no/block socket (make-request-bytes count))
	   (printf "requester-receiving\n")
	   (let ([rcvd (zmq-recv-no/block socket)])
		 (printf-response rcvd)))
	 (zmq:socket-close! socket)
	 (zmq:context-close! context))))

(sleep 10)
