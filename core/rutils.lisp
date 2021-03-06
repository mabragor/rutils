(cl:in-package #:rutils)
(named-readtables:in-readtable rutils-readtable)

(rutils.symbol:eval-always
  (dolist (p '(#:rutils.symbol #:rutils.readtable #:rutils.misc
               #:rutils.iter #:rutils.ana/it #:rutils.ana/let
               #:rutils.list #:rutils.string #:rutils.sequence #:rutils.tree
               #:rutils.hash-table #:rutils.syntax))
    (rutils.symbol:re-export-symbols p '#:reasonable-utilities)))


(cl:in-package #:rutil)
(named-readtables:in-readtable rutils-readtable)

(rutils.symbol:eval-always
  (dolist (p '(#:rutils.short #:rutils))
    (rutils.symbol:re-export-symbols p '#:rutil)))
