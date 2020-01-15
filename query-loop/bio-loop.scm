;
; bio-loop.scm
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog exec))

; Needeed for definition of GeneNode and MoleculeNode
; You can skip this by redefining these two, below.
(use-modules (opencog bioscience))

; Performance stats timer
(define (make-timer)
	(let ((start-time (get-internal-real-time)))
		(lambda ()
			(define now (get-internal-real-time))
			(define diff (/ (- now start-time) internal-time-units-per-second))
			(set! start-time now)
			diff)))

; List of genes on which to perform the query.
(load "gene-list.scm")

; Non-human-readable definitions are used to compress the size
; of the data file to something reasonable-ish.
;
; The `(opencog bioscience)` module defines GeneNode and MoleculeNode
; but if that is not avaoiable, just redefine it to be ConceptNode.
; (define Gene Concept)
(define e Evaluation)
(define l List)
(define g Gene)
(define m Molecule)
(define c Concept)
(define s Member)
(define i (Predicate "interacts_with"))
(define x (Predicate "expresses"))
(define b (Predicate "has_biogridID"))
(define d (Predicate "has_pubmed_ID"))
(define z (Predicate "has_entrez_id"))

(format #t "Start loading raw data ...\n")
(define elapsed-secs (make-timer))
; (primitive-load "biogrid.scm")
(primitive-load "biogrid-full.scm")
(format #t "Loaded biogrid data in ~6f seconds\n" (elapsed-secs))
(primitive-load "entrez.scm")
(format #t "Loaded entrez data in ~6f seconds\n" (elapsed-secs))
(primitive-load "uniprot.scm")
(format #t "Loaded uniprot data in ~6f seconds\n" (elapsed-secs))
(primitive-load "reactome-chebi.scm")
(format #t "Loaded chebi reactome in ~6f seconds\n" (elapsed-secs))
(primitive-load "reactome-ncbi.scm")
(format #t "Loaded ncbi reactome in ~6f seconds\n" (elapsed-secs))
(primitive-load "reactome-uniprot.scm")
(format #t "Loaded uniprot reactome in ~6f seconds\n" (elapsed-secs))
(format #t "AtomSpace contents: ~A\n" (cog-report-counts))

; ------------------------------------------------------------------
; Define the main benchmarking routine

;; This defines a triangle-shaped search; one endpoint is fixed,
;; and we are looking for two other genes that interact with the
;; endpoint and form a triangle.
(define (find-output-interactors gene)
	(Get
		(VariableList
			(TypedVariable (Variable "$a") (Type 'GeneNode))
			(TypedVariable (Variable "$b") (Type 'GeneNode))

			; (TypedVariable (Variable "$a") (Type 'ConceptNode))
			; (TypedVariable (Variable "$b") (Type 'ConceptNode))
		)
		(And
			(Evaluation (Predicate "interacts_with")
				(List gene (Variable "$a")))
			(Evaluation (Predicate "interacts_with")
				(List (Variable "$a") (Variable "$b")))
			(Evaluation (Predicate "interacts_with")
				(List gene (Variable "$b")))
		)))

;; -----------
;; This defines a pentagon-shaped search; one endpoint, a reaction
;; pathway, is fixed, and we are looking for two proteins that
;; participate in that pathway. These two are expressed with a pair
;; of genes that interact with one-another, forming a pentagon.
(define (pathway-gene-interactors pathway)
	(Get
		(VariableList
			(TypedVariable (Variable "$g1") (Type 'GeneNode))
			(TypedVariable (Variable "$g2") (Type 'GeneNode))
			(TypedVariable (Variable "$p1") (Type 'MoleculeNode))
			(TypedVariable (Variable "$p2") (Type 'MoleculeNode)))
		(And
			(Member (Variable "$p1") pathway)
			(Member (Variable "$p2") pathway)
			(Evaluation (Predicate "expresses") (List (Variable "$g1") (Variable "$p1")))
			(Evaluation (Predicate "expresses") (List (Variable "$g2") (Variable "$p2")))
			(Evaluation (Predicate "interacts_with") (List (Variable "$g1") (Variable "$g2")))
		)))

;; -----------
;; This defines a single edge search; one endpoint is the given
;; gene, the other is a pathway.
(define (find-pathways gene)
	(Get
		(TypedVariable (Variable "$p") (Type 'ConceptNode))
		(Member gene (Variable "$p"))
	))

;; -----------
;; Run the triangle-benchmark
(define (run-triangle-benchmark)
	(define bench-secs (make-timer))
	(define interaction-counts
		(map
			(lambda (gene-name)
				; Create a search pattern for each gene in the gene list.
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

				;; (format #t "Ran triangle ~A in ~6f seconds; got ~A results\n"
				;; 	gene-name (gene-secs) rlen)
				(display ".")
				(cog-delete result)
				(cons gene-name rlen)
			)
			gene-list))
	(define run-time (bench-secs))
	(format #t "\n")
	(format #t "Triangle relations for ~A genes in ~6f seconds\n"
			(length interaction-counts) run-time)

	; Return the list of counts.
	; interaction-counts
	*unspecified*
)

;; -----------
;; Run the pentagon-benchmark
(define (run-pentagon-benchmark)

	; Create a list of the pathways that the genes are in.
	(define pathways (delete-duplicates
		(append-map
			(lambda (gene-name)
				(define gene (Gene gene-name))
				(define query (find-pathways gene))
				; Perform the search
				(define path-set (cog-execute! query))
				(define pathways (cog-outgoing-set path-set))
				(cog-delete path-set)
				pathways
			)
			gene-list)))

	(define bench-secs (make-timer))
	(define path-counts
		(map
			(lambda (pathway)
				; Create a search pattern for each pathway in the list.
				(define query (pathway-gene-interactors pathway))

				; Perform the search
				(define path-secs (make-timer))
				(define result (cog-execute! query))
				(define rlen (cog-arity result))

				; Collect up some stats
				(cog-inc-count! pathway rlen)
				(for-each
					(lambda (g-g-m-m)
						(define gene-a (cog-outgoing-atom g-g-m-m 0))
						(define gene-b (cog-outgoing-atom g-g-m-m 1))
						(define prot-a (cog-outgoing-atom g-g-m-m 2))
						(define prot-b (cog-outgoing-atom g-g-m-m 3))
						(cog-inc-count! gene-a 1)
						(cog-inc-count! gene-b 1)
						(cog-inc-count! prot-a 1)
						(cog-inc-count! prot-b 1))
					(cog-outgoing-set result))

				(format #t "Ran path ~A in ~6f seconds; got ~A results\n"
					(cog-name pathway) (path-secs) rlen)
				(display ".")
				(cog-delete result)
				(cons (cog-name pathway) rlen)
			)
			pathways))
	(define run-time (bench-secs))
	(format #t "\n")
	(format #t "Analyzed ~A pathways in ~6f seconds\n"
			(length path-counts) run-time)

	; Return the list of counts.
	; path-counts
	*unspecified*
)

; Run the benchmark three times
(display "Will run the triangle benchmark three times ...\n")
(run-triangle-benchmark)
(sleep 1)
(run-triangle-benchmark)
(sleep 1)
(run-triangle-benchmark)
(sleep 1)
(display "Will run the pentagon benchmark once ...\n")
(run-pentagon-benchmark)

(exit)

; =================================================================


#! -----------------------------------------------------------------
; Some stuff to create a ranked graph of the results found above.
; Look in the directory called `dataset-notes`.

; Sort according to descending rank.
(define sorted-counts (sort interaction-counts
	(lambda (a b) (> (cdr a) (cdr b)))))

; Dump to file.
(define f (open-file "gene-paths.csv" "w"))
(define cnt 1)
(for-each
	(lambda (gu) (format f "~A	~A	~A\n" cnt (car gu) (cdr gu))
		(set! cnt (+ 1 cnt)))
	sorted-counts)
(close f)

!# ; ---------------------------------------------------------------

#! -----------------------------------------------------------------
; Some stuff to create a ranked graph of the results found above.
; Look in the directory called `dataset-notes`.

; Genes that appeared in the pathway.
(define path-participants
	(map (lambda (gene) (cons (cog-name gene) (cog-count gene)))
		(filter (lambda (gene) (< 0 (cog-count gene)))
			(cog-get-atoms 'GeneNode)))
)

(define sorted-participants (sort path-participants
	(lambda (a b) (> (cdr a) (cdr b)))))

; Dump to file.
(define f (open-file "path-participants.csv" "w"))
(define cnt 1)
(for-each
	(lambda (gu) (format f "~A	~A	~A\n" cnt (car gu) (cdr gu))
		(set! cnt (+ 1 cnt)))
	sorted-participants)
(close f)

!# ; ---------------------------------------------------------------

; ------------------------------------------------------------------
