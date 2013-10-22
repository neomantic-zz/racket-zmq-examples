#lang racket

;; run this with racket -tm example.rkt

(provide main)
(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

(define (main)
  (call-with-context
   (lambda (context)
     (let ([router-socket (zmq:socket context 'ROUTER)]
           [dealer-socket (zmq:socket context 'DEALER)])
       (zmq:socket-bind! router-socket "tcp://127.0.0.1:1337")
       (zmq:socket-bind! dealer-socket "inproc://responders")
       (dynamic-wind
         void
         (lambda ()
           (printf/f "defining workers\n")
           (for ([workers 5])
             (define worker-place
               (place
                worker-channel
                (printf/f "waiting for context\n")
                (define worker-context (place-channel-get worker-channel))
                (let ([socket (zmq:socket worker-context 'REP)])
                  (zmq:socket-connect! socket "inproc://responders")
                  (let listen ()
                    (printf/f "worker-listening\n")
                    (let ([recv-bytes (zmq:socket-recv! socket)])
                      (printf/f "worker-sending\n")
                      (zmq-send-noblock socket (make-response-bytes recv-bytes)))
                    (listen)))))
             (place-channel-put worker-place context))
           (printf/f "proxying bitches\n")
           (zmq:proxy! router-socket dealer-socket)
           (void))
         (lambda ()
           (zmq:socket-close! router-socket)
           (zmq:socket-close! dealer-socket)))))))
