(define (factorial n)
    (if (zero? n)
        1
        (* n (factorial (- n 1)))))

(factorial 1000)
