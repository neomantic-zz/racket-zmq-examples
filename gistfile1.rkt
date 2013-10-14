#lang racket

(require ffi/unsafe
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

;; this half works with my hacked version of zmq
;; butt hits an error

(define (socket-send-msg! msg socket flag)
  (dynamic-wind
    void
    (lambda ()
      (zmq:socket-send-msg! msg socket flag))
    (lambda ()
      (zmq:msg-close! msg)
      (free msg))))


;; responder
(thread (lambda ()
          (let* ([context (zmq:context 1)]
                 [socket (zmq:socket context 'REP)])
            (zmq:socket-bind! socket "tcp://127.0.0.1:1337")
            (define (send-response request-bytes)
              (let* ([response-string (string-append (bytes->string/utf-8 request-bytes) " - echoed!")]
                     [response-bytes (string->bytes/utf-8 response-string)]
                     [message (zmq:make-msg-with-data response-bytes)])
                (socket-send-msg! message socket 'DONTWAIT)
                (printf "responder-responded!\n")))
            (let listen ([listening #t])
              (let* ([port (open-input-bytes (zmq:socket-recv! socket))]
                     [received (port->bytes port)])
                (printf "responder-listening2\n")
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
        (zmq:socket-connect! socket "tcp://127.0.0.1:1337")
        (define (zmq-send-no/block count)
          (printf "requester-sending\n")
          (let* ([data (string->bytes/utf-8
                        (string-append
                         "Hello, "
                         (number->string count)))]
                 [msg (zmq:make-msg-with-data data)])
            (zmq:socket-send-msg! msg socket 'NOBLOCK)
            (free msg)))
        (define (zmq-recv-no/block)
          (printf "requester-receiving\n")
          (let ([msg (zmq:make-empty-msg)])
            (sleep 2)
            (zmq:socket-recv-msg! msg socket 'NOBLOCK)
            (dynamic-wind
              void
              (lambda ()
                (printf
                 (bytes->string/utf-8 (bytes-copy (zmq:msg-data msg))))
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

