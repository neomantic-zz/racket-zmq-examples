#lang racket

(require (planet jaymccarthy/zeromq:2:1))
(require ffi/unsafe)

(define (responder)
  (thread (lambda ()
           (let* ([context (zmq:context 1)]
                  [socket (zmq:socket context 'REP)])
             (zmq:socket-bind! socket "tcp://127.0.0.1:1337")
             (let listen ([listening #t])
               (let* ([port (open-input-bytes (zmq:socket-recv! socket))]
                      [rep-bytes (string->bytes/utf-8 (string-append (bytes->string/utf-8 (port->bytes port)) " - echoed!"))]
                       [a-ptr (malloc zmq:_msg)])
                   (ptr-set! a-ptr zmq:_msg rep-bytes)
                   (zmq:socket-send-msg! socket a-ptr 'NOBLOCK)
                   (close-input-port port))
               (listen #t))))))

(define (requester)
  (thread
   (lambda ()
     (let* ([context (zmq:context 1)]
            [socket (zmq:socket context 'REQ)])
       (zmq:socket-connect! "tcp://127.0.0.1:1337")
       (let send-requests ([times 5])
         (if (< times 0)
             #t
             (begin
               (zmq:socket socket (string->bytes/utf-8 "Hello"))
               (send-requests (- times 1)))))
       (let show-responses ([listening #t])
         (let* ([port (open-input-bytes (zmq:socket-recv! socket))])
           (display (bytes->string/utf-8 (port->bytes port)))
           (close-input-port port))
         (show-responses #t))))))