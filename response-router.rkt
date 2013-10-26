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
  (printf/f "defining proxy\n")
  (place
   place-channel
   (define worker-url "inproc://responders")
   (define server-url "tcp://127.0.0.1:1337")
   (define (workers-channels-put-context-and-url worker-channels context url)
     (for-each (lambda (channel)
                 (place-channel-put channel (list context url)))
               worker-channels))
   (call-with-context
    (lambda (context)
      (let ([router-socket (zmq:socket context 'ROUTER)]
            [dealer-socket (zmq:socket context 'DEALER)])
        (printf/f "binding router of proxy to ~a\n" server-url)
        (zmq:socket-bind! router-socket server-url)
        (printf/f "binding dealter of proxy to ~a\n" worker-url)
        (zmq:socket-bind! dealer-socket worker-url)
        ;; block untill we receive all the workers
        ;; and send them the context and the worker-url
        (workers-channels-put-context-and-url
         (place-channel-get place-channel) context worker-url)
        (dynamic-wind
          void
          (lambda ()
            (printf/f "connecting router to dealer\n")
            (zmq:proxy! router-socket dealer-socket #f)
            (void))
          (lambda ()
            (zmq:socket-close! router-socket)
            (zmq:socket-close! dealer-socket))))))))

(define (worker-p)
  (printf/f "defining worker\n")
  (place
   worker-channel
   (let* ([context-and-url (place-channel-get worker-channel)]
          [context (car context-and-url)]
          [url (cadr context-and-url)])
     (call-with-socket context
      'REP
      (lambda (socket)
        ;; Just a note - there seems to be a bug in 0mq where socket connect has to be
        ;; called before socket bind for inproc
        (printf/f "connect worker to ~a\n" url)
        (zmq:socket-connect! socket url)
        (let listen ()
          (printf/f "worker-listening\n")
          (let ([recv-bytes (zmq:socket-recv! socket)])
            (printf-recvd recv-bytes)
            (printf/f "worker-responding\n")
            (zmq:socket-send! socket (make-response-bytes recv-bytes)))
          (listen)))))))

(define (workers-list count)
  (for/fold ([workers '()])
      ([i count])
    (append workers (list (worker-p)))))

(define (main)
  (let ([proxy (proxy-p)])
    ;; send the proxy the workers, so the proxy can send the worker the context
    (place-channel-put proxy (workers-list 5))
    (place-channel-get proxy)))
