#lang racket

;; run this with racket -tm example.rkt

(provide main)
(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

(define uri "tcp://127.0.0.1:1344")

;; this is a literally a copy-paste from zmq.rks
;; sock-recv! procedure, with only the 'NOBLOCK
;; added
(define (zmq-recv-noblock socket)
  (let ([msg (zmq:make-empty-msg)])
    (zmq:socket-recv-msg! msg socket 'NOBLOCK)
    (dynamic-wind
      void
      (lambda ()
        (bytes-copy (zmq:msg-data msg)))
      (lambda ()
        (zmq:msg-close! msg)
        (free msg)))))

(define (zmq-send-noblock socket bytes)
  (let ([zmq-msg (zmq:make-msg-with-data bytes)])
	(dynamic-wind
	  void
	  (lambda ()
		(zmq:socket-send-msg! zmq-msg socket 'NOBLOCK)
		(void))
	  (lambda ()
		(zmq:msg-close! zmq-msg)
		(free zmq-msg)))))

;; just a wrapper around zmq.rkt's socket-recv!
(define (zmq-recv-empty socket)
  (zmq:socket-recv! socket))

(define (make-request-bytes count)
          (string->bytes/utf-8
           (string-append
            "Hello, "
            (number->string count))))

(define (make-response-bytes recv-bytes)
  (string->bytes/utf-8
   (string-append (bytes->string/utf-8 recv-bytes) " - echoed!")))

(define (printf-response recv-bytes)
          (printf/f (string-append (bytes->string/utf-8 recv-bytes) "\n")))

(define (printf-recvd recv-bytes)
  (printf/f (string-append
             "Received Data: "
             (bytes->string/utf-8 recv-bytes)
             "\n")))

(define (request)
  (call-with-context
   (lambda (context)
     (call-with-socket
      context 'REQ
      (lambda (socket)
        (zmq:socket-connect! socket uri)
        (for ([count 5])
          (printf "requester-sending\n")
          (zmq-send-noblock socket (make-request-bytes count))
          (printf "requester-receiving\n")
          (let ([rcvd (zmq-recv-empty socket)])
            (printf-response rcvd))))))))

(define (respond)
  (call-with-context
   (lambda (context)
     (call-with-socket
      context 'REP
      (lambda (socket)
        (zmq:socket-bind! socket uri)
        (let listen ()
          (printf/f "responder-listening\n")
          (let ([recv-bytes (zmq-recv-empty socket)])
            (printf-recvd recv-bytes)
            (zmq-send-noblock socket (make-response-bytes recv-bytes))
            (printf/f "responder-responded\n"))
          ;; this let fails, no message is received and printed
          ;; (let ([recv-bytes (zmq-recv-noblock socket)])
          ;;   (printf-recvd recv-bytes)
          ;;   (zmq-send-noblock socket (make-response-bytes recv-bytes))
          ;;   (printf "responder-responded\n"))
          (listen)))))))

(define (main)
  (place
     ch
     (request))
  (place-channel-get
   (place
    ch1
    (respond))))
