#lang racket

(require (prefix-in zmq (planet jaymccarthy/zeromq:2:1)))
(require (planet jaymccarthy/zeromq:2:1))
(require ffi/unsafe)

(define responder
  (thread (lambda ()
            (define (send-response socket request-bytes)
              (define message (malloc _msg 'raw))
              (set-cpointer-tag! message 'msg-tag)
              (let* ([response-string (string-append (bytes->string/utf-8 ) " - echoed!")]
                     [response-bytes (string->bytes/utf-8 response-string)]
                     [length (bytes-length response-bytes)])
                (memcpy (msg-data-pointer message) response-bytes length)
                (dynamic-wind
                  void
                  (lambda () (socket-send-msg! socket 'NOBLOCK))
                  (lambda ()
                    (msg-close! message)
                    (free message)))))
            (let* ([context (context 1)]
                   [socket (socket context 'REP)])
              (socket-bind! socket "tcp://127.0.0.1:1337")
              (let listen ([listening #t])
                (let* ([port (open-input-bytes (socket-recv! socket))])
                  (send-response (port->bytes port))
                  (close-input-port port))
                (listen #t))))))

(define requester
  (thread
    (lambda ()
      (let* ([context (context 1)]
             [socket (socket context 'REQ)])
        (socket-connect! "tcp://127.0.0.1:1337")
        (define (send-requests times)
          (if (eq? times 0)
              (begin
                (display "done sending"))
              (socket socket (string->bytes/utf-8 "Hello")))
          (send-requests (- times 1)))
        (let show-responses ([listening #t])
          (let* ([port (open-input-bytes (socket-recv! socket))])
            (display (bytes->string/utf-8 (port->bytes port)))
            (close-input-port port)
            (socket-close! socket))
          (show-responses #t))
        (send-requests 5)))))