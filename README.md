ULID for R6SA Scheme
====================

This is an implementation of [ULID](https://github.com/ulid/spec) in
portable R6RS Scheme.

The library requires the following SRFIs:

- SRFI-19
- SRFI-27

Or implementation specific libraries for the below helper libraries:

- `(ulid time)`
- `(ulid random)`

This library is inspired by [ULID for R7RS Scheme](https://github.com/shirok/scheme-ulid)

Tested implementations
----------------------

- Sagittarius 0.9.8
- Chez Scheme 9.5.1
- Racket v8.3 (plt-r6rs)

How to use
----------

```scheme
(import (rnrs)
        (ulid))
(define gen-ulid (make-ulid-generator))
```

`make-ulid-generator` creates a new ULID generator. The procedure may take two
optional arguments, `random-generator` and `millisecond-generator`.  
The first one must take an argument which is an integer indicates how many bits
of random integer must be returned.  
The second one must be a thunk returning a current millisecond.

```scheme
(gen-ulid) ;; -> #<ulid>
```

Calling the generator procedure created with `make-ulid-generator` returns
a new ULID object. You can retrieve its timestamp and randomness fields by
`ulid-timestamp` and `ulid-randomness`, both in exact nonnegative integers,
respectively.

NOTE: This library does increment the randomness field if the timestamp
of the previous ULID and creating ULID are the same as the ULID specification
mentioned. Also, it takes a `millisecond-generator` which may return the
constant value. If the randomness reaches to the maximum value, `(expt 2 80)`
then `&ulid` will be raised. It is user's responsibility not to pass constant
value generator.

```scheme
(ulid->integer ulid)    ;; -> an exact integer
(ulid->bytevector ulid) ;; -> a bytevector
(ulid->string ulid)     ;; -> a Base32 encoded string
```
Above procedures convert the given `ulid` to an exact integer, bytevector
or string, respectively.

```scheme
(integer->ulid integer) ;; -> #<ulid>
(bytevector->ulid bv)   ;; -> #<ulid>
(string->ulid str)      ;; -> #<ulid>
```
Above procedures convert the given exect integer, bytevector or string to
ULID object, respectively.

```scheme
(ulid=? ulid0 ulid1 ulid*...)
(ulid<? ulid0 ulid1 ulid*...)
(ulid-hash ulid)
```
Equality predicate, ordering predicate and hash function.

Unlike the R7RS version of ULID library, this library doesn't provide
ULID comparator.

Consideration
-------------

It is *not* recommended to use `default-random-generator` even though
it's passed by default. The default implementation doesn't provide any
randomization method or secure random. It's better to use implementation
specific secure random. For example, if it's Sagittarius, then use
`(crypto)` or `(math random)` to generate secure random. A simple 
implementation of random generator for Sagittarius can be like this

```scheme
(import (rnrs)
        (math))
(define rc4 (secure-random RC4))
(define (rc4-random-generator bits) (random rc4 (expt 2 bits)))
```

Testing
-------

If your R6RS implementation supports SRFI-64, you can run the
[`tests/test.scm`](tests/test.scm) file.
