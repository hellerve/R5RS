(load "scm-tests/unit.scm")


(assert-equal (lambda () (exact? 1)) #t)
(assert-equal (lambda () (exact? 1.0)) #f)
(assert-equal (lambda () (inexact? 1)) #f)
(assert-equal (lambda () (inexact? 1.0)) #t)
(assert-equal (lambda () (even? 1)) #f)
(assert-equal (lambda () (even? 1.0)) #f)
(assert-equal (lambda () (even? 2)) #t)
(assert-equal (lambda () (odd? 1)) #t)
(assert-equal (lambda () (odd? 1.0)) #t)
(assert-equal (lambda () (odd? 2)) #f)
(assert-equal (lambda () (zero? 0)) #t)
(assert-equal (lambda () (zero? 1)) #f)
(assert-equal (lambda () (positive? 1)) #t)
(assert-equal (lambda () (positive? -1)) #f)
(assert-equal (lambda () (negative? 1)) #f)
(assert-equal (lambda () (negative? -1)) #t)
(assert-equal (lambda () (complex? 1)) #t)
(assert-equal (lambda () (complex? -1.0)) #t)
(assert-equal (lambda () (complex? -1+1i)) #t)
(assert-equal (lambda () (abs -1.0)) 1.0)
(assert-equal (lambda () (abs 1.0)) 1.0)
(assert-equal (lambda () (exact->inexact 1.0)) 1.0)
(assert-equal (lambda () (exact->inexact 1)) 1.0)
(assert-equal (lambda () (<> -1.0 -1.0)) #f)
(assert-equal (lambda () (<> 1 2)) #t)
(assert-equal (lambda () (succ 1)) 2)
(assert-equal (lambda () (pred 1)) 0)
(assert-equal (lambda () (gcd 20 44)) 4)
(assert-equal (lambda () (gcd -10 34)) 2)
(assert-equal (lambda () (gcd 20 44)) 4)
(assert-equal (lambda () (gcd -10 34)) 2)
(assert-equal (lambda () (lcm 20 44)) 220)
(assert-equal (lambda () (lcm -10 34)) 170)

(unit-test-handler-results)
(unit-test-all-passed)