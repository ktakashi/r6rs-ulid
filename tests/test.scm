#!r6rs
(import (rnrs)
	(ulid)
	(srfi :64))

(test-begin "ULID")

(test-assert (ulid? ((make-ulid-generator))))
(test-assert (ulid? (string->ulid "01AN4Z07BY79KA1307SR9X4MV3")))
(test-assert (ulid? (integer->ulid 1772072868548111945193852199469470563)))
(test-assert (ulid? (bytevector->ulid #vu8(1 85 73 240 29 126 58 102 160 140 7 206 19 210 83 99))))

(test-error ulid-condition? (ulid? (string->ulid "*01AN4Z07BY79KA1307SR9X4MV")))

(let ((g (make-ulid-generator (lambda (bits) (- (expt 2 bits) 1))
			      (lambda () 1644434908979))))
  (test-assert (ulid? (g)))
  (test-error "Randomness overflow" ulid-condition? (g)))

(let ((g (make-ulid-generator (lambda (bits) 1)
			      (lambda () (expt 2 48)))))
  (test-error "Timestamp is bigger than 48 bits" ulid-condition? (g)))

(let ((g (make-ulid-generator)))
  (define (round ulid)
    (define (<-> ulid -> <-) (<- (-> ulid)))
    (test-assert (ulid=? ulid (<-> ulid ulid->string string->ulid)))
    (test-assert (ulid=? ulid (<-> ulid ulid->bytevector bytevector->ulid)))
    (test-assert (ulid=? ulid (<-> ulid ulid->integer integer->ulid))))
  (let ((ulid (g)))
    (round ulid)
    (test-assert (ulid=? ulid ulid ulid))
    (test-assert (not (ulid=? ulid (g))))
    (test-assert (ulid<? ulid (g) (g)))))

(let ((ht (make-hashtable ulid-hash ulid=?))
      (g (make-ulid-generator)))
  (define ulid0 (g))
  ;; make different object
  (let ((ulid1 (string->ulid (ulid->string ulid0))))
    (hashtable-set! ht ulid0 "ok")
    (test-equal "ok" (hashtable-ref ht ulid1 #f))))

(test-end)
