#lang racket

(require ffi/unsafe
;; local path, but use the 'msg-creation-defs' branch
;; from git@github.com:neomantic/zeromq.git
;; it supports creating messages
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

;; this half works with my hacked version of zmq
;; butt hits an error

(define uri "tcp://127.0.0.1:1337")

;; this is a literally a copy-paste from zmq.rks
;; sock-recv! procedure, with only the 'NOBLOCK
;; added
(define (zmq-recv-noblock socket)
  (let ([msg (zmq:make-empty-msg)])
    (zmq:socket-recv-msg! msg socket 'NOBLOCK)
    (dynamic-wind
      void
      (lambda ()
        (bytes-copy (zmq:msg-data msg)))
      (lambda ()
        (zmq:msg-close! msg)
        (free msg)))))

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

;; just a wrapper around zmq.rkt's socket-recv!
(define (zmq-recv-empty socket)
  (zmq:socket-recv! socket))

;; responder
(thread
 (lambda ()
   (let* ([context (zmq:context 1)]
          [socket (zmq:socket context 'REP)])
     (zmq:socket-bind! socket uri)
     (define (make-response-bytes recv-bytes)
       (string->bytes/utf-8
        (string-append (bytes->string/utf-8 recv-bytes) " - echoed!")))
     (define (printf-recvd recv-bytes)
       (printf (string-append
                "Received Data: "
                (bytes->string/utf-8 recv-bytes)
                "\n")))
     (let listen ()
       (printf "responder-listening\n")
       ;; this let works, in the sense that that the data is received
       ;; and printed
       (let ([recv-bytes (zmq-recv-empty socket)])
         (printf-recvd recv-bytes)
         (zmq-send-noblock socket (make-response-bytes recv-bytes))
         (printf "responder-responded\n"))

       ;; this let fails, no message is received and printed
       ;; (let ([recv-bytes (zmq-recv-noblock socket)])
       ;;   (printf-recvd recv-bytes)
       ;;   (zmq-send-noblock socket (make-response-bytes recv-bytes))
       ;;   (printf "responder-responded\n"))

       (listen))
     (zmq:socket-close! socket)
     (zmq:context-close! context))))

;; requester
(thread
 (lambda ()
   (let* ([context (zmq:context 1)]
          [socket (zmq:socket context 'REQ)])
	 (zmq:socket-connect! socket uri)
	 (define (make-request-bytes count)
	   (string->bytes/utf-8
		(string-append
		 "Hello, "
		 (number->string count))))
	 (define (printf-response recv-bytes)
	   (printf (string-append (bytes->string/utf-8 recv-bytes) "\n")))
     (for ([count 5])
	   (printf "requester-sending\n")
	   (zmq-send-noblock socket (make-request-bytes count))
	   (printf "requester-receiving\n")
	   (let ([rcvd (zmq-recv-noblock socket)])
		 (printf-response rcvd)))
	 (zmq:socket-close! socket)
	 (zmq:context-close! context))))

(sleep 10)

;;; output
;; #<thread:...6f81/example.rkt:42:1>
;; #<thread:...6f81/example.rkt:75:1>
;; requester-sending
;; requester-receiving
;; socket-recv-msg!: Bad address
;;   context...:
;;    /home/neomantic/src/mine/7e687d75d9227ef16f81/example.rkt:75:1
;; responder-listening
;; Received Data: Hello, 0
;; responder-responded
;; responder-listening
