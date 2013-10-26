#lang racket

(provide main)

(require racket/place
         racket/place/distributed
         ffi/unsafe
         "zmq-support.rkt"
         "example-support.rkt"
         (planet zitterbewegung/uuid-v4:2:0/uuid-v4)
         (prefix-in zmq: "../zeromq/net/zmq.rkt"))

(define (make-proxy-place)
  (printf/f "defining proxy\n")
  (place
   proxy-channel
   (define worker-url (string-append "inproc://" (string-downcase (symbol->string (make-uuid)))))
   ;; send each worker the context and the url
   (define server-url "tcp://127.0.0.1:1337")
   (call-with-context (lambda (context)
     (call-with-router-dealer-sockets context
      (lambda (router-socket dealer-socket)
        (printf/f "connecting dealer of proxy: ~a\n" server-url)
        (zmq:socket-connect! router-socket server-url)
        (printf/f "binding router of proxy: ~a\n" worker-url)
        (zmq:socket-bind! dealer-socket worker-url)
        (let notify-workers ([workers (place-channel-get proxy-channel)]
                   [count 0])
          (if (empty? workers)
            #f
            (begin
              ;; send each worker their id,
              ;; their context and their url
              (place-channel-put
               (car workers)
               (list (+ count 1) context worker-url))
              (notify-workers (cdr workers) (+ count 1)))))))))))

(define (make-worker-place)
  (printf/f "defining worker\n")
  (place
   worker-channel
   ;; block until we receive the context, the url, and worker number from the proxy
   (let* ([context-and-url (place-channel-get worker-channel)]
          [context (cadr context-and-url)]
          [url (caddr context-and-url)]
          [worker-number (number->string (car context-and-url))])
     (call-with-req-socket
      context
      (lambda (socket)
        (printf/f "connecting worker to ~a\n" url)
        (zmq:socket-connect! socket url)
        (for ([count 100000])
          (printf "requester-sending\n")
          (zmq:socket-send! socket (make-request-bytes worker-number count))
          (printf "requester-receiving\n")
          (let ([recv-bytes (zmq:socket-recv! socket)])
            (printf-recvd recv-bytes))))))))

(define (make-workers count)
  (for/fold ([workers '()])
      ([i count])
    (append workers (list (make-worker-place)))))

(define (main)
  (let ([proxy-place (make-proxy-place)])
    (place-channel-put proxy-place (make-workers 5))
    (place-channel-get proxy-place)))
