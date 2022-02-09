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

