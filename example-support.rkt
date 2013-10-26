#lang racket

(provide (all-defined-out))

(require  racket/place/distributed) ;;this gives printf/f

(define (make-request-bytes uuid count)
  (string->bytes/utf-8
   (string-append
    "Hello, "
    uuid
    " "
    (number->string count))))

(define (make-response-bytes recv-bytes)
  (string->bytes/utf-8
   (string-append (bytes->string/utf-8 recv-bytes) " - echoed!")))

(define (printf-recvd recv-bytes)
  (printf/f "Received: ~a\n" (bytes->string/utf-8 recv-bytes)))

(define (printf-response recv-bytes)
  (printf/f "~a\n" (bytes->string/utf-8 recv-bytes)))

