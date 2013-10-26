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


(define (make-request-bytes count)
  (string->bytes/utf-8
   (string-append
    "Hello, "
    (number->string count))))

(define (make-response-bytes recv-bytes)
  (string->bytes/utf-8
   (string-append (bytes->string/utf-8 recv-bytes) " - echoed!")))

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

(define (printf-recvd recv-bytes)
  (printf/f "Received: ~a\n" (bytes->string/utf-8 recv-bytes)))

(define (printf-response recv-bytes)
  (printf/f "~a\n" (bytes->string/utf-8 recv-bytes)))

;; just a wrapper around zmq.rkt's socket-recv!
(define (zmq-recv-empty socket)
  (zmq:socket-recv! socket))
