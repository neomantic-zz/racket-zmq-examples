#lang racket

(require (planet jaymccarthy/zeromq:2:1))
(require ffi/unsafe)

;; responder
(thread (lambda ()
          (define (send-response socket request-bytes)
            (let* ([message (malloc _msg 'raw)]
                   [response-string (string-append (bytes->string/utf-8 request-bytes) " - echoed!")]
                   [response-bytes (string->bytes/utf-8 response-string)]
                   [length (bytes-length response-bytes)])
              (set-cpointer-tag! message msg-tag)
              (msg-init-size! message length)
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
                (send-response socket (port->bytes port))
                (close-input-port port))
              (listen #t))
            (socket-close! socket))))

;; requester
(thread
    (lambda ()
      (printf "threading\n")
      (let* ([context (context 1)]
             [socket (socket context 'REQ)])
        (socket-connect! socket "tcp://127.0.0.1:1337")
        (define (send-requests times)
          (if (eq? times 0)
              (printf "done sending\n")
              (socket-send! socket (string->bytes/utf-8 "Hello")))
          (send-requests (- times 1)))
        (send-requests 5)
        (let show-responses ([listening #t])
          (let* ([port (open-input-bytes (socket-recv! socket))])
            (printf (string-append (bytes->string/utf-8 (port->bytes port)) "\n"))
            (close-input-port port))
          (show-responses #t))
        (socket-close! socket))))

(sleep 20)