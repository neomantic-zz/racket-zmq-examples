#lang racket

;; run this with racket -tm example.rkt

(provide main)
(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

(define (proxy-p)
  (place
   p
   (call-with-context
    (lambda (context)
      (let ([router-socket (zmq:socket context 'ROUTER)]
            [dealer-socket (zmq:socket context 'DEALER)])
        (zmq:socket-bind! router-socket "tcp://127.0.0.1:1337")
        (zmq:socket-bind! dealer-socket "inproc://responders")
        ;; get the worker place
        ;; send the worker place, the context - so it's shared
        (place-channel-put (place-channel-get p) context)
        (dynamic-wind
          void
          (lambda ()
            (printf/f "proxying bitches\n")
            (zmq:proxy! router-socket dealer-socket)
            (void))
          (lambda ()
            (zmq:socket-close! router-socket)
            (zmq:socket-close! dealer-socket))))))))

(define (worker-p)
  (place
   w
   (call-with-socket
    ;; get the context from the proxy
    (place-channel-get w)
    'REP
    (lambda (socket)
      (zmq:socket-connect! socket "inproc://responders")
      (let listen ()
        (printf/f "worker-listening\n")
        (let ([recv-bytes (zmq:socket-recv! socket)])
          (printf/f "worker-sending\n")
          (zmq:socket-send! socket (make-response-bytes recv-bytes)))
        (listen))))))

(define (main)
  (let ([worker (worker-p)]
        [proxy  (proxy-p)])
    ;; send the proxy the worker, so the proxy can send the worker the context
    (place-channel-put proxy worker)
    (place-channel-get proxy)))
