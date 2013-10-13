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
              (printf (string-append (zmq:strerro (zmq:errno)) "\n"))
              (listen #t))
            (zmq:socket-close! socket)
            (zmq:context-close! context))))

;; requester
(thread
    (lambda ()
      (let* ([context (zmq:context 1)]
             [socket (zmq:socket context 'REQ)])
        (zmq:socket-connect! socket "tcp://127.0.0.1:1337")
        (define (send-message number)
          (let* ([msg-string (string-append "Hello " (number->string number))]
                 [msg-bytes (string->bytes/utf-8 msg-string)])
            (printf "requester-sending\n")
            (socket-send-msg! (zmq:make-msg-with-data msg-bytes) socket 'DONTWAIT)
            (printf (string-append (zmq:strerro (zmq:errno)) "\n"))
            (printf "requester-sent\n")))
        (define (send-requests count)
          (if (eq? count 0)
              (printf "finished\n")
              (begin
                (send-message count)
                ;;(sleep 3)
                (let ([msg (zmq:make-empty-msg)])
                  (printf "requester-receiving\n")
                  ;;(printf (string-append (zmq:strerro (zmq:errno)) "\n"))
                  (zmq:socket-recv-msg! msg socket 'NOBLOCK)
                  (dynamic-wind
                    void
                    (λ ()
                       (printf "received some crap")
                       (bytes-copy (zmq:msg-data msg)))
                    (λ ()
                       (zmq:msg-close! msg)
                       (free msg))))
                (send-requests (- count 1)))))
        (send-requests 1)
        (zmq:socket-close! socket)
        (zmq:context-close! context))))

(sleep 10)

