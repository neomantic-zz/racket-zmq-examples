#lang racket

;; run this with racket -tm example.rkt

(provide main)
(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         "example-support.rkt"
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

(define uri "tcp://127.0.0.1:1337")

(define (request)
  (call-with-context
   (lambda (context)
     (call-with-socket
      context 'REQ
      (lambda (socket)
        (zmq:socket-connect! socket uri)
        (for ([count 5])
          (printf "requester-sending\n")
          (zmq:socket-send! socket (make-request-bytes "1 requester" count))
          (printf "requester-receiving\n")
          (let ([rcvd (zmq:socket-recv! socket)])
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
          (let ([recv-bytes (zmq:socket-recv! socket)])
            (printf-recvd recv-bytes)
            (zmq:socket-send! socket (make-response-bytes recv-bytes))
            (printf/f "responder-responded\n"))
          (listen)))))))

(define (main)
  (place request-channel (request))
  (place-wait (place response-channel (respond))))
