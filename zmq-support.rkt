#lang racket

(provide (all-defined-out))

(require (prefix-in zmq: "../zeromq/net/zmq.rkt"))

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


