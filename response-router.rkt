#lang racket

;; run this with racket -tm response-router.rkt

(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         "example-support.rkt"
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

;; providing everything makes these bindings available to the places
(provide (all-defined-out))

(define worker-url "inproc://responders")
(define server-url "tcp://127.0.0.1:1337")

  ;; create a worker place
(define (make-worker-place)
  (printf/f "creating worker\n")
  (place
   worker-channel
   (call-with-rep-socket
      ;; block until we receive the context and the url from the proxy
      ;; on the worker channel
      (place-channel-get worker-channel)
      (lambda (socket)
        ;; connect worker
        (zmq:socket-connect! socket worker-url)
        ;; listen to request, print what's received and
        ;; return a response
        (let listen ()
          (let ([recv-bytes (zmq:socket-recv! socket)])
            (printf-recvd recv-bytes)
            (zmq:socket-send! socket (make-response-bytes recv-bytes)))
          (listen))))))

(define (main)
  (printf/f "creating proxy\n")
  ;; create proxy as a place (on a separate thread) and
  ;; capture it with a wait, so execution doesn't stop
  (place-wait
   (place
    place-channel
    (call-with-context (lambda (context)
      (call-with-shared-queue
       context
       (lambda (router-socket dealer-socket)
         ;; bind to server url
         (zmq:socket-bind! router-socket server-url)
         ;; bind (not connect) to server worker-url
         (zmq:socket-bind! dealer-socket worker-url)
         ;; make each worker, and pass each a context, which must be
         ;; shared between the proxy and the worker in inproc transfers
         (for ([count 5])
           (place-channel-put (make-worker-place) context)))))))))
