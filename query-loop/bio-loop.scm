;
; bio-loop.scm
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog exec))

; Performance stats
(define (make-timer)
	(let ((start-time (current-time)))
		(lambda ()
			(define now (current-time))
			(define diff (- now start-time))
			(set! start-time now)
			diff)))

(load "gene-list.scm")

; Non-human-readable definitions to compress the size of the data file.
(define Gene Concept)
(define e Evaluation)
(define l List)
(define g Gene)
(define c Concept)
(define i (Predicate "interacts_with"))
(define d (Predicate "has_pubmed_ID"))
(define z (Predicate "has_entrez_id"))

(format #t "Start loading raw data ...\n")
(define elapsed-secs (make-timer))
; (primitive-load "biogrid.scm")
(primitive-load "biogrid-full.scm")
(format #t "Loaded raw data in ~6f seconds\n" (elapsed-secs))
(format #t "AtomSpace contents: ~A\n" (cog-report-counts))

; ------------------------------------------------------------------
; Define the main benchmarking routine

;; This defines a triangle-shaped search; one endpoint is fixed,
;; and we are looking for two other genes that interact with the
;; endpoint and form a triangle.
(define (find-output-interactors gene)
	(Get
		(VariableList
			; (TypedVariable (Variable "$a") (Type 'GeneNode))
			; (TypedVariable (Variable "$b") (Type 'GeneNode))

			(TypedVariable (Variable "$a") (Type 'ConceptNode))
			(TypedVariable (Variable "$b") (Type 'ConceptNode))
		)
		(And
			(Evaluation (Predicate "interacts_with")
				(List gene (Variable "$a")))
			(Evaluation (Predicate "interacts_with")
				(List (Variable "$a") (Variable "$b")))
			(Evaluation (Predicate "interacts_with")
				(List gene (Variable "$b")))
		)))

; Run the benchmark
(define bench-secs (make-timer))
(define interaction-counts
	(map
		(lambda (gene-name)
			; Create a search patterns for each gene in the gene list.
			(define gene (Gene gene-name))
			(define query (find-output-interactors gene))

			; Perform the search
			(define gene-secs (make-timer))
			(define result (cog-execute! query))
			(define rlen (cog-arity result))

			; Collect up some stats
			; (cog-inc-count! gene rlen)
			(for-each
				(lambda (gene-pair)
					(define gene-a (cog-outgoing-atom gene-pair 0))
					(define gene-b (cog-outgoing-atom gene-pair 1))
					(cog-inc-count! gene-a 1)
					(cog-inc-count! gene-b 1))
				(cog-outgoing-set result))

			(format #t "Ran query ~A in ~6f seconds; got ~A results\n"
				gene-name (gene-secs) rlen)
			(cog-delete result)
			(cons gene-name rlen)
		)
		gene-list))
(define run-time (bench-secs))
(define x (format #t "Analyzed ~A genes in ~6f seconds\n"
		(length interaction-counts) run-time))

(define sorted-counts (sort interaction-counts
	(lambda (a b) (> (cdr a) (cdr b)))))

(define f (open-file "gene-paths.csv" "w"))
(define cnt 1)
(for-each
	(lambda (gu) (format f "~A	~A	~A\n" cnt (car gu) (cdr gu))
		(set! cnt (+ 1 cnt)))
	sorted-counts)
(close f)


; (exit)
; ------------------------------------------------------------------
