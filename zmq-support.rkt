#lang racket

(provide (all-defined-out))

(require ffi/unsafe
         racket/place
         racket/place/distributed
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

;; Creates a context and passes it to the func
;; when the function returns, it closes the context
(define (call-with-context func)
  (let ([context (zmq:context 1)])
    (dynamic-wind
      void
      (lambda ()
        (func context) (void))
      (lambda ()
        (zmq:context-close! context)))))

;; Creates a context and passes it to the func
;; when the function returns, it closes the context
(define (call-with-socket context type func )
  (let ([socket (zmq:socket context type)])
    (dynamic-wind
      void
      (lambda ()
        (func socket) (void))
      (lambda ()
        (zmq:socket-close! socket)))))

(define (call-with-req-socket context func)
  (call-with-socket
   context 'REQ
   (lambda (socket)
     (func socket))))

(define (call-with-rep-socket context func)
  (call-with-socket
   context 'REP
   (lambda (socket)
     (func socket))))

;; just a wrapper around zmq.rkt's socket-recv!
(define (zmq-recv-empty socket)
  (zmq:socket-recv! socket))

(define (zmq-send-noblock socket bytes)
  (let ([zmq-msg (zmq:make-msg-with-data bytes)])
    (dynamic-wind
      void
      (lambda ()
        (zmq:socket-send-msg! zmq-msg socket 'NOBLOCK)
        (void))
      (lambda ()
        (zmq:msg-close! zmq-msg)
        (free zmq-msg)))))

(define (call-with-router-dealer-sockets context func)
  (let ([router-socket (zmq:socket context 'DEALER)]
        [dealer-socket (zmq:socket context 'ROUTER)])
    (dynamic-wind
      void
      (lambda ()
        (func router-socket dealer-socket)
        (printf/f "connecting router to dealer\n")
        (zmq:proxy! router-socket dealer-socket #f)
        (void))
      (lambda ()
        (zmq:socket-close! router-socket)
        (zmq:socket-close! dealer-socket)))))