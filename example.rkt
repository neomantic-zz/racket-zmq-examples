#lang racket

;; run this with racket -tm example.rkt

(provide main)
(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         "example-support.rkt"
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

(define uri "tcp://127.0.0.1:1344")

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
