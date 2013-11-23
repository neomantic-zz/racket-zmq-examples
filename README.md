racket-zmq-examples
===================

This repository contains examples of using Jay McCarthy's
[zeromq Racket FFI bindings](https://github.com/jeapostrophe/zeromq).
They replicate Clojure examples from [this blog post](http://augustl.com/blog/2013/zeromq_instead_of_http/).

Requirements
------------
The native zeromq library must be installed for the examples to work.  They
use the Racket binding to zeromq's [zmq_proxy](http://api.zeromq.org/3-2:zmq-proxy) call. As such, zeromq version 3.2.x must be installed.

Examples Descriptions
---------------------
1.
2. `request-router.rkt` and `response-router.rkt`.  These two scripts
operate in tandem.  The first script sends 100000 requests to the
a set of responders which reply to the original requests

Running the examples
--------------------

Implementation Details
----------------------

All examples use Racket's [places API](http://docs.racket-lang.org/reference/places.html)
This was required because Racket's thread API implements a thread as green threads
(implemented most likely as Scheme co-routines). In other words, a Racket
VM runs on a single native thread.

This causes problems, though, when attempting to use zeromq's reply and request
sockets in the same process; these sockes they block the currently running thread until the reply
and request messages are received on either socket. Using these sockets
with Racket's green thread simply blocks the whole Racket process.

As a workaround, the examples use Racket 'places' API. Each place actually runs
on a native thread, so spawning off the sockets in a Racket place means that
Racket VM that spawns them is not blocked.

Using Racket 'places' also provides an additional bonus. The places
are distributed across multiple CPUs.

This disadvantage of a Racket place is that each place is actually a separate Racket
environment managed by the Racket environment that spawned the place. Each place therefore
consumes as much memory as the process that spawns them.  For example, on my
machine, a single Racket VM costs around 100MB of memory. But while the `request-router.rkt`
runs, the Racket process balloons to 700MB's of memory.  It shrinks back down
after the number of requests take place.

Zeromq Examples vs Racket's Distributed Places
------------------------------
The code in `request-router.rkt` and `response-router.rkt` operate in a way
which is very similar o Racket's `distributed-places`.  Distributes-place are
places that can operate on remote endpoints across a network. The zeromq examples,
with a few tweaks, could operate similarly, since the sockets operate across
an tcp channel.

There is, though, an important different. The messages between zeromq sockets are
composed of bytes (Racket byte-strings).  In constrast, the data between Racket's
distributed places are high-level abstractions such as vectors.

License
-------

All examples are MIT licensed
