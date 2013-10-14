#lang racket

(require ffi/unsafe
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

(define socket-uri "tcp://127.0.0.1:9991")

(thread
 (lambda ()
   (let* ([context (zmq:context 1)]
          [socket (zmq:socket context 'REP)]
          [port (open-output-file "receiver-log" #:exists 'replace)])
     (zmq:socket-bind! socket socket-uri)
     (define (zmq-recv-no/block)
       (let ([msg (zmq:make-empty-msg)])
         (write "responder-receiving\n" port)
         (zmq:socket-recv-msg! msg socket 'NOBLOCK)
         (write "responder-receiving\n" port)
         (dynamic-wind
           void
           (lambda () (bytes-copy (zmq:msg-data msg)))
           (lambda ()
             (zmq:msg-close! msg)
             (free msg)))))
     (define (zmq-send-no/block str)
       (write "responder-sending\n" port)
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
     (define (listening)
       (let ([str (bytes->string/utf-8 (zmq-recv-no/block))])
         (write (string-append str "\n") port)
         (zmq-send-no/block (string-append str " - echoed")))
       (listening))
     (listening)
     (zmq:socket-close! socket)
     (zmq:context-close! context)
     (close-output-port port))))

(thread
 (lambda ()
   (let* ([context (zmq:context 1)]
          [socket (zmq:socket context 'REQ)]
          [port (open-output-file "requester-log" #:exists 'replace)])
     (zmq:socket-bind! socket socket-uri)
     (define (zmq-send-no/block count)
       (write "requester-sending\n" port)
       (let* ([data (string->bytes/utf-8
                     (string-append
                      "Hello, "
                      (number->string count)))]
              [msg (zmq:make-msg-with-data data)])
         (zmq:socket-send-msg! msg socket 'NOBLOCK)
         (free msg)))
     (define (zmq-recv-no/block)
       (write "requester-receiving\n" port)
       (let ([msg (zmq:make-empty-msg)])
         (zmq:socket-recv-msg! msg socket 'NOBLOCK)
         (dynamic-wind
           void
           (lambda () (bytes-copy (zmq:msg-data msg)))
           (lambda ()
             (zmq:msg-close! msg)
             (free msg)))))
     (for ([i 5])
       (zmq-send-no/block i)
       (let ([recvd (zmq-recv-no/block)])
         (write
          (string-append
           (bytes->string/utf-8 recvd)
           "\n")
          port)))
     (zmq:socket-close! socket)
     (zmq:context-close! context)
     (close-output-port port))))

(sleep 20)
