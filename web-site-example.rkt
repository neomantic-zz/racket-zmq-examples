#lang racket

(require ffi/unsafe
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

(define socket-uri "tcp://127.0.0.1:9999")

(thread
 (lambda ()
   (let* ([socket (zmq:socket (zmq:context 1) 'REP)])
     (zmq:socket-bind! socket socket-uri)
     (let listen ([listening #t])
       (printf "responder-listening")
       (let* ([received (zmq:socket-recv! socket)]
	      [received-str (bytes->string/utf-8 received)])
	 (printf (string-append received-str "\n"))
         (zmq:socket-send!
          socket
          (string->bytes/utf-8 (string-append received-str " - echoed"))))
       (listen #t)))))

(thread
 (lambda ()
   (let* ([socket (zmq:socket (zmq:context 1) 'REQ)])
     (zmq:socket-bind! socket socket-uri)
     (let send-request ([count 5])
       (if (eq? count 0)
           (printf "finishing requesting")
           (begin
             (printf "requester-sending")
             (zmq:socket-send!
              socket
              (string->bytes/utf-8
               (string-append
                "Hello, "
                (number->string count))))
             (send-request (- count 0))))
       (send-request 5)))))

(sleep 10)