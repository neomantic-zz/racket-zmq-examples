#lang racket

;; run this with racket -tm example.rkt

(provide main)
(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         "example-support.rkt"
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

;; since this is a zmq inproc transfer, the context must be
;; shared

(define (make-proxy-place)
  (printf/f "defining proxy\n")
  (place
   place-channel
   (define worker-url "inproc://responders")
   (define server-url "tcp://127.0.0.1:1337")
   (call-with-context (lambda (context)
     (call-with-router-dealer-sockets context
        (lambda (router-socket dealer-socket)
          (printf/f "binding router of proxy to ~a\n" server-url)
          (zmq:socket-bind! router-socket server-url)
          (printf/f "binding dealter of proxy to ~a\n" worker-url)
          (zmq:socket-bind! dealer-socket worker-url)
          (for-each (lambda (channel)
                      (place-channel-put channel (list context worker-url)))
                    (place-channel-get place-channel))))))))

(define (make-worker-place)
  (printf/f "defining worker\n")
  (place
   worker-channel
   ;; block until we receive the context and the url from the proxy
   (let* ([context-and-url (place-channel-get worker-channel)]
          [context (car context-and-url)]
          [url (cadr context-and-url)])
     (call-with-rep-socket
      context
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

(define (make-workers count)
  (for/fold ([workers '()])
      ([i count])
    (append workers (list (make-worker-place)))))

(define (main)
  (let ([proxy-place (make-proxy-place)])
    ;; send the proxy the workers, so the proxy can send the worker the context
    (place-channel-put proxy-place (make-workers 5))
    (place-channel-get proxy-place)))
