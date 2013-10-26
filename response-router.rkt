#lang racket

;; run this with racket -tm example.rkt

(provide main)
(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         "example-support.rkt"
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

(define worker-url "inproc://responders")
(define server-url "tcp://127.0.0.1:1337")
(provide (all-defined-out))

(define (make-worker-place)
  (printf/f "defining worker\n")
  (place
   worker-channel
   (call-with-rep-socket
      ;; block until we receive the context and the url from the proxy))
      (place-channel-get worker-channel)
      (lambda (socket)
        (printf/f "connect worker to ~a\n" worker-url)
        (zmq:socket-connect! socket worker-url)
        (let listen ()
          (printf/f "worker-listening\n")
          (let ([recv-bytes (zmq:socket-recv! socket)])
            (printf-recvd recv-bytes)
            (printf/f "worker-responding\n")
            (zmq:socket-send! socket (make-response-bytes recv-bytes)))
          (listen))))))

(define (main)
  (printf/f "defining proxy\n")
  (place-wait
   (place
    place-channel
    (call-with-context (lambda (context)
      (zmq-router-dealer-proxy
       context
       (lambda (router-socket dealer-socket)
         (printf/f "binding router of proxy to ~a\n" server-url)
         (zmq:socket-bind! router-socket server-url)
         (printf/f "binding dealer of proxy to ~a\n" worker-url)
         (zmq:socket-bind! dealer-socket worker-url)
         (for ([count 5])
           ;; since this is a zmq inproc transfer, the context must be shared
          ;; between the proxy and the workers
          ;; make the worker, and then send the worker the context
           (place-channel-put (make-worker-place) context)))))))))
