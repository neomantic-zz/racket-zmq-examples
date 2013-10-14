#lang racket

(require ffi/unsafe
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

(define socket-uri "tcp://127.0.0.1:9999")

(thread
 (lambda ()
   (let* ([context (zmq:context 1)]
          [socket (zmq:socket context 'REP)])
     (zmq:socket-bind! socket socket-uri)
     (define (zmq-recv-no/block)
       (let ([msg (zmq:make-empty-msg)])
         (zmq:socket-recv-msg! msg socket 'NOBLOCK)
         (dynamic-wind
           void
           (lambda () (bytes-copy (zmq:msg-data msg)))
           (lambda ()
             (zmq:msg-close! msg)
             (free msg)))))
     (define (zmq-send-no/block str)
       (printf "requester-sending")
       (let* ([bs (string->bytes/utf-8 str)]
             [msg (zmq:make-msg-with-data bs)])
         (dynamic-wind
           void
           (lambda ()
             (zmq:socket-send-msg! msg socket 'NOBLOCK)
             (void))
           (lambda ()
             (zmq:msg-close! msg)
             (free msg)))))
     (let listen ([listening #t])
       (printf "responder-listening")
       (let ([str (bytes->string/utf-8 (zmq-recv-no/block))])
         (printf (string-append str "\n"))
         (zmq-send-no/block (string-append str " - echoed")))
       (listen #t))
     (zmq:socket-close! socket)
     (zmq:context-close! context))))

(thread
 (lambda ()
   (let* ([context (zmq:context 1)]
          [socket (zmq:socket context 'REQ)])
     (zmq:socket-bind! socket socket-uri)
     (define (zmq-send-no/block count)
       (printf "requester-sending")
       (let* ([data (string->bytes/utf-8
                     (string-append
                      "Hello, "
                      (number->string count)))]
              [msg (zmq:make-msg-with-data data)])
         (zmq:socket-send-msg! msg socket 'NOBLOCK)
         (free msg)))
     (define (zmq-recv-no/block)
       (let ([msg (zmq:make-empty-msg)])
         (zmq:socket-recv-msg! msg socket 'NOBLOCK)
         (dynamic-wind
           void
           (lambda () (bytes-copy (zmq:msg-data msg)))
           (lambda ()
             (zmq:msg-close! msg)
             (free msg)))))
     (let send-request ([count 5])
       (if (eq? count 0)
           (printf "finishing requesting")
           (begin
             (zmq-send-no/block count)
             (printf
              (string-append
               (bytes->string/utf-8 (zmq-recv-no/block))
               "\n"))
             (send-request (- count 0))))
       (send-request 5))
     (zmq:socket-close! socket)
     (zmq:context-close! context))))

(sleep 10)