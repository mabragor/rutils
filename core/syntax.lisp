;; For license see LICENSE

(in-package #:reasonable-utilities.syntax)
(named-readtables:in-readtable rutils-readtable)

(declaim (optimize (speed 3) (space 1) (debug 0)))


(define-condition case-failure (type-error
                                #+sbcl sb-kernel:case-failure)
  ((name :reader case-failure-name :initarg :name)
   (possibilities :reader case-failure-possibilities :initarg :possibilities))
  (:report
    (lambda (condition stream)
      (format stream "~@<~S fell through ~S expression. ~
                      ~:_Wanted one of ~:S.~:>"
              (type-error-datum condition)
              (case-failure-name condition)
              (case-failure-possibilities condition)))))

;; predicate case

(defun expand-predicate-case (pred keyform clauses case)
  `(once-only (,keyform)
     `(cond
        ,@(loop :for (key actions) :in ,clauses
             :collect (cons (if (and (eq case 'case) (eq key 'otherwise))
                                t
                                `(funcall ,pred ,keyform ,key))
                            actions))
        ,@(ecase case
            (case nil)
            (ccase '((t (cerror 'case-failure))))
            (ecase '((t error  'case-failure)))))))

(defmacro pcase (pred keyform &rest clauses)
  "Like CASE, but uses given PRED instead of EQL to select appropriate CLAUSE.
Example usage:
CL-USER> (pcase '< 1
           (0  (print \"Below zero\"))
           (2  (print \"OK\"))
           (otherwise (error \"Oops\")))
"
  (expand-predicate-case pred keyform clauses 'case))

(defmacro pcase (pred keyform &rest clauses)
  "Like CCASE, but uses given PRED instead of EQL to select appropriate CLAUSE.
Example usage:
CL-USER> (pccase '< 1
           (0  (print \"Below zero\"))
           (2  (print \"OK\")))
"
  (expand-predicate-case pred keyform clauses 'ccase))

(defmacro pecase (pred keyform &rest clauses)
  "Like ECASE, but uses given PRED instead of EQL to select appropriate CLAUSE.
Example usage:
CL-USER> (pecase '< 1
           (0  (print \"Below zero\"))
           (2  (print \"OK\")))
"
  (expand-predicate-case pred keyform clauses 'ecase))


;; desctructuring case

(defun expand-destructuring-case (key clauses case)
  (once-only (key)
    `(if (typep ,key 'cons)
         (,case (car ,key)
           ,@(mapcar (lambda (clause)
                       (destructuring-bind ((keys . lambda-list) &body body) clause
                         `(,keys
                           (destructuring-bind ,lambda-list (cdr ,key)
                             ,@body))))
                     clauses))
         (error "Invalid key to D~S: ~S" ',case ,key))))

(defmacro dcase (keyform &body clauses)
  "DCASE is a combination of CASE and DESTRUCTURING-BIND.
KEYFORM must evaluate to a CONS.

Clauses are of the form:

  ((CASE-KEYS . DESTRUCTURING-LAMBDA-LIST) FORM*)

The clause whose CASE-KEYS matches CAR of KEY, as if by CASE, CCASE, or ECASE,
is selected, and FORMs are then executed with CDR of KEY is destructured and
bound by the DESTRUCTURING-LAMBDA-LIST.

Example:

 (defun dcase-test (x)
   (dcase x
     ((:foo a b)
      (format nil \"foo: ~S, ~S\" a b))
     ((:bar &key a b)
      (format nil \"bar, ~S, ~S\" a b))
     (((:alt1 :alt2) a)
      (format nil \"alt: ~S\" a))
     ((t &rest rest)
      (format nil \"unknown: ~S\" rest))))

  (dcase-test (list :foo 1 2))        ; => \"foo: 1, 2\"
  (dcase-test (list :bar :a 1 :b 2))  ; => \"bar: 1, 2\"
  (dcase-test (list :alt1 1))         ; => \"alt: 1\"
  (dcase-test (list :alt2 2))         ; => \"alt: 2\"
  (dcase-test (list :quux 1 2 3))     ; => \"unknown: 1, 2, 3\"

 (defun decase-test (x)
   (dcase x
     ((:foo a b)
      (format nil \"foo: ~S, ~S\" a b))
     ((:bar &key a b)
      (format nil \"bar, ~S, ~S\" a b))
     (((:alt1 :alt2) a)
      (format nil \"alt: ~S\" a))))

  (decase-test (list :foo 1 2))        ; => \"foo: 1, 2\"
  (decase-test (list :bar :a 1 :b 2))  ; => \"bar: 1, 2\"
  (decase-test (list :alt1 1))         ; => \"alt: 1\"
  (decase-test (list :alt2 2))         ; => \"alt: 2\"
  (decase-test (list :quux 1 2 3))     ; =| error
"
  (expand-destructuring-case keyform clauses 'case))

(defmacro dccase (keyform &body clauses)
  "DCCASE is a combination of CCASE and DESTRUCTURING-BIND.
KEYFORM must evaluate to a CONS.

Clauses are of the form:

  ((CASE-KEYS . DESTRUCTURING-LAMBDA-LIST) FORM*)

The clause whose CASE-KEYS matches CAR of KEY, as if by CASE, CCASE, or ECASE,
is selected, and FORMs are then executed with CDR of KEY is destructured and
bound by the DESTRUCTURING-LAMBDA-LIST.

Example:


 (defun dccase-test (x)
   (dcase x
     ((:foo a b)
      (format nil \"foo: ~S, ~S\" a b))
     ((:bar &key a b)
      (format nil \"bar, ~S, ~S\" a b))
     (((:alt1 :alt2) a)
      (format nil \"alt: ~S\" a))))

  (decase-test (list :foo 1 2))        ; => \"foo: 1, 2\"
  (decase-test (list :bar :a 1 :b 2))  ; => \"bar: 1, 2\"
  (decase-test (list :alt1 1))         ; => \"alt: 1\"
  (decase-test (list :alt2 2))         ; => \"alt: 2\"
  (decase-test (list :quux 1 2 3))     ; =| continueable error
"
  (expand-destructuring-case keyform clauses 'ccase))

(defmacro decase (keyform &body clauses)
  "DECASE is a combination of ECASE and DESTRUCTURING-BIND.
KEYFORM must evaluate to a CONS.

Clauses are of the form:

  ((CASE-KEYS . DESTRUCTURING-LAMBDA-LIST) FORM*)

The clause whose CASE-KEYS matches CAR of KEY, as if by CASE, CCASE, or ECASE,
is selected, and FORMs are then executed with CDR of KEY is destructured and
bound by the DESTRUCTURING-LAMBDA-LIST.

Example:

 (defun decase-test (x)
   (dcase x
     ((:foo a b)
      (format nil \"foo: ~S, ~S\" a b))
     ((:bar &key a b)
      (format nil \"bar, ~S, ~S\" a b))
     (((:alt1 :alt2) a)
      (format nil \"alt: ~S\" a))))

  (decase-test (list :foo 1 2))        ; => \"foo: 1, 2\"
  (decase-test (list :bar :a 1 :b 2))  ; => \"bar: 1, 2\"
  (decase-test (list :alt1 1))         ; => \"alt: 1\"
  (decase-test (list :alt2 2))         ; => \"alt: 2\"
  (decase-test (list :quux 1 2 3))     ; =| error
"
  (expand-destructuring-case keyform clauses 'ecase))


;; switch

(defun generate-switch-body (whole object clauses test key &optional default)
  (with-gensyms (value)
    (setf test (extract-function-name test))
    (setf key (extract-function-name key))
    (when (and (consp default)
               (member (first default) '(error cerror)))
      (setf default `(,@default "No keys match in SWITCH. Testing against ~S with ~S."
                      ,value ',test)))
    `(let ((,value (,key ,object)))
      (cond ,@(mapcar (lambda (clause)
                        (if (member (first clause) '(t otherwise))
                            (progn
                              (when default
                                (error "Multiple default clauses or illegal use of a default clause in ~S."
                                       whole))
                              (setf default `(progn ,@(rest clause)))
                              '(()))
                            (destructuring-bind (key-form &body forms) clause
                              `((,test ,value ,key-form)
                                ,@forms))))
                      clauses)
            (t ,default)))))

(defmacro switch (&whole whole (object &key (test 'eql) (key 'identity))
                         &body clauses)
  "Evaluates first matching clause, returning its values, or evaluates and
returns the values of DEFAULT if no keys match."
  (generate-switch-body whole object clauses test key))

(defmacro eswitch (&whole whole (object &key (test 'eql) (key 'identity))
                          &body clauses)
  "Like SWITCH, but signals an error if no key matches."
  (generate-switch-body whole object clauses test key '(error)))

(defmacro cswitch (&whole whole (object &key (test 'eql) (key 'identity))
                          &body clauses)
  "Like SWITCH, but signals a continuable error if no key matches."
  (generate-switch-body whole object clauses test key '(cerror "Return NIL from CSWITCH.")))

(defmacro dotable (k v table &optional rez)
  (with-gensyms (pair slot)
    `(block nil
       (etypecase table
         (list (if (alistp ,table)
                   (dolist (,pair ,table)
                     (ds-bind (,k . ,v) ,pair
                              ,@body))
                   (error 'simple-type-error
                          :format-control "Can't iterate over proper list in DOTABLE: need an alist")))
         (hash-table (maphash (lambda (,k ,v)
                                ,@body)
                              ,table))
         #+:closer-mop
         (object (dolist (,k (mapcar #'c2mop:slot-definition-name
                                     (c2mop:class-slots (class-of ,table))))
                   (let ((,v (slot-value ,table ',k)))
                     ,@body))))
       ,rez)))


(defmacro multiple-value-prog2 (first-form second-form &body forms)
  "Evaluates FIRST-FORM, then SECOND-FORM, and then FORMS. Yields as its value
all the value returned by SECOND-FORM."
  `(progn ,first-form (multiple-value-prog1 ,second-form ,@forms)))