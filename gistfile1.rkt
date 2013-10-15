#lang racket

(require ffi/unsafe
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

;; this half works with my hacked version of zmq
;; butt hits an error

(define uri "tcp://127.0.0.1:1337")

;; responder
(thread (lambda ()
          (let* ([context (zmq:context 1)]
                 [socket (zmq:socket context 'REP)])
            (zmq:socket-bind! socket uri)
            (define (send-response request-bytes)
              (let* ([response-string (string-append (bytes->string/utf-8 request-bytes) " - echoed!")]
                     [response-bytes (string->bytes/utf-8 response-string)]
                     [message (zmq:make-msg-with-data response-bytes)])
                (printf (string-append
                         response-string "\n"))
                (dynamic-wind
                  void
                  (lambda ()
                    (zmq:socket-send-msg! message socket 'NOBLOCK)
                    (void))
                  (lambda ()
                    (zmq:msg-close! message)
                    (free message)))
                (printf "responder-responded\n")))
            (let listen ([listening #t])
              (let* ([port (open-input-bytes (zmq:socket-recv! socket))]
                     [received (port->bytes port)])
                (printf "responder-listening\n")
                (send-response received)
                (close-input-port port))
              (listen #t))
            (zmq:socket-close! socket)
            (zmq:context-close! context))))

;; requester
(thread
    (lambda ()
      (let* ([context (zmq:context 1)]
             [socket (zmq:socket context 'REQ)])
        (zmq:socket-connect! socket uri)
        (define (make-request-message count)
          (string->bytes/utf-8
                        (string-append
                         "Hello, "
                         (number->string count))))
        (define (zmq-send-no/block count)
          (printf "requester-sending\n")
          (let* ([msg (zmq:make-msg-with-data (make-request-message count))])
            (dynamic-wind
              void
              (lambda ()
                (zmq:socket-send-msg! msg socket 'NOBLOCK)
                (void))
              (lambda ()
                (zmq:msg-close! msg)
                (free msg)))))
        (define (zmq-recv-no/block)
          (printf "requester-receiving\n")
          (let ([msg (zmq:make-empty-msg)])
            (zmq:socket-recv-msg! msg socket 'NOBLOCK)
            (dynamic-wind
              void
              (lambda ()
                (let* ([recv-bytes (bytes-copy (zmq:msg-data msg))]
                       [recv-string (bytes->string/utf-8 recv-bytes)])
                  (printf (string-append recv-string "\n")))
                (void))
              (lambda ()
                (zmq:msg-close! msg)
                (free msg)))))
        (for ([count 5])
          (zmq-send-no/block count)
          (let ([msg (zmq:make-empty-msg)])
            (printf "requester-receiving\n")
            (zmq:socket-recv-msg! msg socket 'NOBLOCK)
            (zmq-recv-no/block)))
        (zmq:socket-close! socket)
        (zmq:context-close! context))))

(sleep 10)

