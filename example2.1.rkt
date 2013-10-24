#lang racket

;; run this with racket -tm example.rkt

(provide main)
(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

;; since this is a zmq inproc transfer, the context must be
;; shared

(define (proxy-p)
  (place
   p
   (define (worker-channels-put-context worker-channels context)
     (for-each (lambda (channel)
                 (place-channel-put channel context))
               worker-channels))
   (call-with-context
    (lambda (context)
      (let ([router-socket (zmq:socket context 'ROUTER)]
            [dealer-socket (zmq:socket context 'DEALER)])
        (zmq:socket-bind! router-socket "tcp://127.0.0.1:1337")
        (zmq:socket-bind! dealer-socket "inproc://responders")
        ;; get the worker places
        (worker-channels-put-context (place-channel-get p) context)
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
  (printf/f "defining worker\n")
  (place
   w
   (call-with-socket
    ;; get the context from the proxy
    (place-channel-get w)
    'REP
    (lambda (socket)
      ;; Just a note - there seems to be a bug in 0mq where socket connect has to be
      ;; called before socket bind for inproc
      (zmq:socket-connect! socket "inproc://responders")
      (let listen ()
        (printf/f "worker-listening\n")
        (let ([recv-bytes (zmq:socket-recv! socket)])
          (printf/f "worker-sending\n")
          (zmq:socket-send! socket (make-response-bytes recv-bytes)))
        (listen))))))

(define (workers-list count)
  (for/fold ([workers '()])
      ([i count])
    (append workers (list (worker-p)))))

(define (main)
  (let ([proxy (proxy-p)])
    ;; send the proxy the workers, so the proxy can send the worker the context
    (place-channel-put proxy (workers-list 5))
    (place-channel-get proxy)))
