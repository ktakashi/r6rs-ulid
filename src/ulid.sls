;;; -*- mode:scheme; coding:utf-8 -*-
;;;
;;; ulid.sls - R6RS ULID library
;;;  
;;;   Copyright (c) 2022  Takashi Kato  <ktakashi@ymail.com>
;;;   
;;;   Redistribution and use in source and binary forms, with or without
;;;   modification, are permitted provided that the following conditions
;;;   are met:
;;;   
;;;   1. Redistributions of source code must retain the above copyright
;;;      notice, this list of conditions and the following disclaimer.
;;;  
;;;   2. Redistributions in binary form must reproduce the above copyright
;;;      notice, this list of conditions and the following disclaimer in the
;;;      documentation and/or other materials provided with the distribution.
;;;  
;;;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;;;   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;;;   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;;;   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;;;   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;;;   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
;;;   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;;   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;;   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;;   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;;   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;  

#!r6rs
(library (ulid)
    (export make-ulid-generator
	    ulid? ulid-timestamp ulid-randomness
	    ulid->integer integer->ulid
	    ulid->bytevector bytevector->ulid
	    ulid->string string->ulid
	    ulid=? ulid<? ulid-hash

	    ulid-condition?
	    
	    default-random-generator
	    default-millisecond-retriever
	    )
    (import (rnrs)
	    (ulid time)
	    (ulid random))

(define *random-length* 80)
(define *timestamp-length* 48)

(define-condition-type &ulid &condition
  make-ulid-condition ulid-condition?)

(define (ulid-violation who msg . irr)
  (raise (condition (make-ulid-condition)
		    (make-assertion-violation)
		    (make-who-condition who)
		    (make-message-condition msg)
		    (make-irritants-condition irr))))

(define-record-type ulid
  (fields timestamp
	  randomness))

(define make-ulid-generator
  (case-lambda
   (() (make-ulid-generator default-random-generator))
   ((random-generator)
    (make-ulid-generator random-generator default-millisecond-retriever))
   ((random-generator millisecond-retriever)
    (let ((millis #f)
	  (random #f))
      (lambda ()
	(define (get-random! current)
	  (cond ((eqv? millis current)
		 (set! random (+ random 1))
		 random)
		(else
		 (set! millis current)
		 (set! random (random-generator *random-length*))
		 random)))
	(define timestamp-mask (- (expt 2 *timestamp-length*) 1))
	(define (check-timestamp timestamp)
	  (let ((r (bitwise-and timestamp timestamp-mask)))
	    (unless (= r timestamp)
	      (ulid-violation 'make-ulid-generator "Timestamp is too large"
			      timestamp))
	    timestamp))
	(let* ((current (check-timestamp (millisecond-retriever)))
	       (random (get-random! current)))
	  (when (> (bitwise-length random) *random-length*)
	    (ulid-violation 'make-ulid-generator "Random overflow" random))
	  (make-ulid millis random)))))))

(define (ulid->integer ulid)
  (+ (bitwise-arithmetic-shift-left (ulid-timestamp ulid) *random-length*)
     (ulid-randomness ulid)))

(define (integer->ulid i)
  ;; TODO should we check the size?
  (let ((timestamp (bitwise-arithmetic-shift-right i *random-length*))
	(random (bitwise-and i (- (expt 2 *random-length*) 1))))
    (make-ulid timestamp random)))

(define (ulid->bytevector ulid)
  (let ((n (ulid->integer ulid))
	(bv (make-bytevector (div (+ *random-length* *timestamp-length*) 8))))
    (do ((i (- (bytevector-length bv) 1) (- i 1))
	 (n n (bitwise-arithmetic-shift-right n 8)))
	((negative? i) bv)
      (let ((b (bitwise-and n #xFF)))
	(bytevector-u8-set! bv i b)))))

(define (bytevector->ulid bv)
  (unless (= (bytevector-length bv)
	     (div (+ *random-length* *timestamp-length*) 8))
    (ulid-violation 'bytevector->ulid "Wrong size of ULID bytevector" bv))
  (make-ulid (bytevector-uint-ref bv 0 (endianness big) 6)
	     (bytevector-uint-ref bv 6 (endianness big) 10)))

(define (ulid->string ulid)
  (let ((n (ulid->integer ulid)))
    (do ((n n (bitwise-arithmetic-shift-right n 5)) (i 0 (+ i 1))
	 (r '() (cons (vector-ref *encode-table* (bitwise-and n #x1F)) r)))
	((= i 26) (list->string r)))))

(define (string->ulid s)
  (define (adjust c)
    (case c
      ((#\O) #\0)
      ((#\I #\L) #\1)
      (else c)))
  (unless (= (string-length s) 26)
    (ulid-violation 'string->ulid "Invalid ULID string size" s))
  
  (integer->ulid
   (fold-left
    (lambda (acc c)
      (let ((n (cond ((assv c *decode-table*) => cdr)
		     (else (ulid-violation 'string->ulid
					   "Invalid character" c)))))
	(+ (bitwise-arithmetic-shift-left acc 5) n)))
    0 (map adjust (string->list (string-upcase s))))))

(define (ulid=? ulid1 ulid2 . ulid*)
  (if (null? ulid*)
      (and (= (ulid-timestamp ulid1) (ulid-timestamp ulid2))
	   (= (ulid-randomness ulid1) (ulid-randomness ulid2)))
      (and (ulid=? ulid1 ulid2)
	   (fold-left (lambda (ulid0 ulid)
			(and ulid0 (ulid=? ulid0 ulid) ulid))
		      ulid1 ulid*)
	   #t)))

(define (ulid<? ulid1 ulid2 . ulid*)
  (if (null? ulid*)
      (or (< (ulid-timestamp ulid1) (ulid-timestamp ulid2))
	  (and (= (ulid-timestamp ulid1) (ulid-timestamp ulid2))
	       (< (ulid-randomness ulid1) (ulid-randomness ulid2))))
      (and (ulid<? ulid1 ulid2)
	   (fold-left (lambda (ulid0 ulid)
			(and ulid0 (ulid<? ulid0 ulid) ulid))
		      ulid2 ulid*)
	   #t)))

(define (ulid-hash ulid)
  (bitwise-xor (equal-hash (ulid-timestamp ulid))
	       (equal-hash (ulid-randomness ulid))))

(define *encode-table*
  (list->vector
   (string->list "0123456789ABCDEFGHJKMNPQRSTVWXYZ")))
(define *decode-table*
  (do ((i 0 (+ i 1)) (len (vector-length *encode-table*))
       (r '() (cons (cons (vector-ref *encode-table* i) i) r)))
      ((= i len) r)))

)
