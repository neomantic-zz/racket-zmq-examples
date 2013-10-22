#lang racket

(provide main)

(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))


(define (main)
  (define worker-url (string-append "inproc://" "dc52047c-3b12-11e3-9057-0090f5ccb4d3"))
  (call-with-context
   (lambda (context)
     (printf/f "defining proxy-place\n")
     (define proxy-place
       (place
        proxy-channel
        (define proxy-context-url (place-channel-get proxy-channel))
        (let ([client-socket (zmq:socket (car proxy-context-url) 'ROUTER)]
              [worker-socket (zmq:socket (car proxy-context-url) 'DEALER)])
          (zmq:socket-connect! client-socket "tcp://127.0.0.1:1337")
          (zmq:socket-bind! worker-socket (cadr proxy-context-url))
          (dynamic-wind
            void
            (lambda ()
              (zmq:proxy! client-socket worker-socket)
              (void))
            (lambda ()
              (zmq:socket-close! client-socket)
              (zmq:socket-close! worker-socket))))))
     (place-channel-put proxy-place (list context worker-url))
     (printf/f "defining workers\n")
     (for ([worker-count 1])
       (printf/f "defining worker\n")
       (define worker-place
         (place
          worker-channel
          (printf/f "waiting for context\n")
          (define worker-context-url (place-channel-get worker-channel))
          (printf/f "got context for worker ~a\n" (+ (caddr worker-context-url) 1))
          (call-with-socket
           (car worker-context-url)
           'REQ
           (lambda (socket)
             (printf/f "connecting worker ~a\n" (+ (caddr worker-context-url) 1))
             (zmq:socket-connect! socket (cadr worker-context-url))
             (printf/f "requester-sending: ~a\n" (+ (caddr worker-context-url) 1))
             (zmq:socket-send! socket (make-request-bytes (caddr worker-context-url)))
             (printf "requester-receiving ~a\n" (+ (caddr worker-context-url) 1))
             (let ([rcvd (zmq:socket-recv! socket)])
               (printf-response rcvd))))))
       (place-channel-put worker-place (list context worker-url worker-count)))
     (place-channel-get proxy-place))))
