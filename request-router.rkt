#lang racket

(provide main)

(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         (planet zitterbewegung/uuid-v4:2:0/uuid-v4)
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

(define (proxy-p)
  (printf/f "defining proxy-place\n")
  (place
   proxy-channel
   (define worker-url (string-append "inproc://" (string-downcase (symbol->string (make-uuid)))))
   ;; send each worker the context and the url
   (define (workers-channels-put-context-and-url worker-channels context url)
     (for-each (lambda (channel)
                 (place-channel-put channel (list context url)))
               worker-channels))
   (define server-url "tcp://127.0.0.1:1337")
   (call-with-context
    (lambda (context)
      (let ([client-socket (zmq:socket context 'DEALER)]
            [worker-socket (zmq:socket context 'ROUTER)])
        (printf/f "connecting dealer of proxy: ~a\n" server-url)
        (zmq:socket-connect! client-socket server-url)
        (printf/f "binding router of proxy: ~a\n" worker-url)
        (zmq:socket-bind! worker-socket worker-url)
        ;; block until it gets the list of workers
        (workers-channels-put-context-and-url
         (place-channel-get proxy-channel)
         context
         worker-url)
        (dynamic-wind
          void
          (lambda ()
            (printf/f "we are proxying\n")
            (zmq:proxy! client-socket worker-socket)
            (void))
          (lambda ()
            (zmq:socket-close! client-socket)
            (zmq:socket-close! worker-socket))))))))

(define (worker-p)
  (printf/f "defining worker\n")
  (place
   worker-channel
   (let* ([context-and-url (place-channel-get worker-channel)]
          [context (car context-and-url)]
          [url (cadr context-and-url)])
     (call-with-socket context
      'REQ
      (lambda (socket)
        (printf/f "connecting worker to ~a\n" url )
        (zmq:socket-connect! socket url)
        (printf/f "requester-sending\n")
        (zmq:socket-send! socket (make-request-bytes 1))
        (printf "requester-receiving\n")
        (let ([rcvd (zmq:socket-recv! socket)])
          (printf-response rcvd)))))))

(define (workers-list count)
  (for/fold ([workers '()])
      ([i count])
    (append workers (list (worker-p)))))

(define (main)
  (let ([proxy (proxy-p)])
    (place-channel-put proxy (workers-list 5))
    (place-channel-get proxy)))
