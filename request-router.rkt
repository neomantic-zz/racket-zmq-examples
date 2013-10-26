#lang racket

(provide main)

(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         "example-support.rkt"
         (planet zitterbewegung/uuid-v4:2:0/uuid-v4)
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))


(define server-url "tcp://127.0.0.1:1337")
(provide (all-defined-out))

(define (make-worker-place)
  (printf/f "creating worker\n")
  (place
   worker-channel
   ;; block until we receive the context, the url, and worker number from the proxy
   (let* ([from-proxy (place-channel-get worker-channel)]
          [context (car from-proxy)]
          [worker-url (cadr from-proxy)]
          [worker-number (number->string (caddr from-proxy))])
     (call-with-req-socket
      context
      (lambda (socket)
        ;; connect the worker to the url
        (zmq:socket-connect! socket worker-url)
        ;; send requests
        (for ([count 100000])
          (zmq:socket-send! socket (make-request-bytes worker-number count))
          (let ([recv-bytes (zmq:socket-recv! socket)])
            (printf-recvd recv-bytes))))))))

(define (main)
  (printf/f "creating proxy\n")
  ;; create proxy as a place (on a separate thread) and
  ;; capture it with a wait, so execution doesn't stop
  (place-wait
     (place
      proxy-channel
      ;; since the worker-url generation is dynamic, it cannot be shared via
      ;; a provide, but must be passed in a channel
      (define worker-url
        (string-append "inproc://" (string-downcase (symbol->string (make-uuid)))))
      (call-with-context
       (lambda (context)
         (zmq-router-dealer-proxy
          context
          (lambda (router-socket dealer-socket)
            ;; connect (not bind) router to server url
            (zmq:socket-connect! router-socket server-url)
            ;; bind dealer to worker-url
            (zmq:socket-bind! dealer-socket worker-url)
            ;; create workers and send each one the context
            ;; (which must be shared for inproc to work),
            ;; the url they must connect to, and their id
            (for ([count 5])
              (place-channel-put
               (make-worker-place) (list context worker-url count))))))))))
