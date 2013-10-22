#lang racket

;; run this with racket -tm example.rkt

(provide main)
(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

(define (printf-recvd recv-bytes)
  (printf/f (string-append
             "Received Data: "
             (bytes->string/utf-8 recv-bytes)
             "\n")))

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

(define (make-response-bytes recv-bytes)
  (string->bytes/utf-8
   (string-append (bytes->string/utf-8 recv-bytes) " - echoed!")))

(define (make-request-bytes count)
          (string->bytes/utf-8
           (string-append
            "Hello, "
            (number->string count))))

(define (printf-response recv-bytes)
          (printf/f (string-append (bytes->string/utf-8 recv-bytes) "\n")))


(define (main)
  (call-with-context
   (lambda (context)
     (let ([router-socket (zmq:socket context 'ROUTER)]
           [dealer-socket (zmq:socket context 'DEALER)])
       (zmq:socket-bind! router-socket "tcp://127.0.0.1:1337")
       (zmq:socket-bind! dealer-socket "inproc://responders")
       (dynamic-wind
         void
         (lambda ()
           (printf/f "defining workers\n")
           (for ([workers 5])
             (define worker-place
               (place
                worker-channel
                (printf/f "waiting for context\n")
                (define worker-context (place-channel-get worker-channel))
                (let ([socket (zmq:socket worker-context 'REP)])
                  (zmq:socket-connect! socket "inproc://responders")
                  (let listen ()
                    (printf/f "worker-listening\n")
                    (let ([recv-bytes (zmq:socket-recv! socket)])
                      (printf/f "worker-sending\n")
                      (zmq-send-noblock socket (make-response-bytes recv-bytes)))
                    (listen)))))
             (place-channel-put worker-place context))
           (printf/f "proxying bitches\n")
           (zmq:proxy! router-socket dealer-socket)
           (void))
         (lambda ()
           (zmq:socket-close! router-socket)
           (zmq:socket-close! dealer-socket)))))))
