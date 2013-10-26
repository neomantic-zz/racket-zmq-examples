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
  (printf/f "defining worker\n")
  (place
   worker-channel
   ;; block until we receive the context, the url, and worker number from the proxy
   (let ([context-and-url (place-channel-get worker-channel)])
     (call-with-req-socket
      (car context-and-url)
     (lambda (socket)
       (printf/f "connecting worker to ~a\n" (cadr context-and-url))
       (zmq:socket-connect! socket (cadr context-and-url))
       (for ([count 100000])
         (printf "requester-sending\n")
         (zmq:socket-send! socket (make-request-bytes "number" count))
         (printf "requester-receiving\n")
         (let ([recv-bytes (zmq:socket-recv! socket)])
           (printf-recvd recv-bytes))))))))

(define (main)
  (printf/f "defining proxy\n")
  (place-wait
     (place
      proxy-channel
      (define worker-url (string-append "inproc://" (string-downcase (symbol->string (make-uuid)))))
      (call-with-context
       (lambda (context)
         (call-with-router-dealer-sockets
          context
          (lambda (router-socket dealer-socket)
            (printf/f "connecting dealer of proxy: ~a\n" server-url)
            (zmq:socket-connect! router-socket server-url)
            (printf/f "binding router of proxy: ~a\n" worker-url)
            (zmq:socket-bind! dealer-socket worker-url)
            (for ([count 5])
              (place-channel-put (make-worker-place) (list context worker-url))))))))))
