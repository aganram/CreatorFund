;; Creator Fund DApp Smart Contract
;; Support your favorite content creators with milestone-based funding

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-deadline-passed (err u103))
(define-constant err-funding-active (err u104))
(define-constant err-funding-failed (err u105))
(define-constant err-funding-successful (err u106))
(define-constant err-no-support (err u107))
(define-constant err-insufficient-funds (err u108))
(define-constant err-deadline-not-passed (err u109))

;; Data Variables
(define-data-var next-project-id uint u1)

;; Project Status
(define-constant status-seeking-support u1)
(define-constant status-funded u2)
(define-constant status-abandoned u3)

;; Data Maps
(define-map creator-projects 
  uint 
  {
    creator: principal,
    project-name: (string-ascii 100),
    content-description: (string-ascii 500),
    funding-target: uint,
    support-deadline: uint,
    total-support: uint,
    status: uint,
    launched-at: uint
  })

(define-map fan-support 
  { project-id: uint, supporter: principal } 
  uint)

(define-map project-supporters
  uint
  (list 200 principal))

;; Private Functions
(define-private (is-project-creator (project-id uint) (user principal))
  (match (map-get? creator-projects project-id)
    project (is-eq (get creator project) user)
    false))

(define-private (get-current-block)
  block-height)

;; Read-only Functions
(define-read-only (get-creator-project (project-id uint))
  (map-get? creator-projects project-id))

(define-read-only (get-supporter-contribution (project-id uint) (supporter principal))
  (default-to u0 (map-get? fan-support { project-id: project-id, supporter: supporter })))

(define-read-only (get-project-supporters (project-id uint))
  (default-to (list) (map-get? project-supporters project-id)))

(define-read-only (get-next-project-id)
  (var-get next-project-id))

;; Public Functions

;; Launch a creator project
(define-public (launch-creator-project (project-name (string-ascii 100)) (content-description (string-ascii 500)) (funding-target uint) (support-period uint))
  (let ((project-id (var-get next-project-id))
        (support-deadline (+ (get-current-block) support-period)))
    (map-set creator-projects project-id {
      creator: tx-sender,
      project-name: project-name,
      content-description: content-description,
      funding-target: funding-target,
      support-deadline: support-deadline,
      total-support: u0,
      status: status-seeking-support,
      launched-at: (get-current-block)
    })
    (var-set next-project-id (+ project-id u1))
    (ok project-id)))

;; Support a creator project
(define-public (support-creator (project-id uint) (amount uint))
  (match (map-get? creator-projects project-id)
    project 
    (if (> (get-current-block) (get support-deadline project))
      err-deadline-passed
      (if (not (is-eq (get status project) status-seeking-support))
        err-funding-active
        (begin
          (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
          
          (let ((current-support (get-supporter-contribution project-id tx-sender)))
            (map-set fan-support 
              { project-id: project-id, supporter: tx-sender }
              (+ current-support amount))
            
            (if (is-eq current-support u0)
              (let ((supporters (get-project-supporters project-id)))
                (map-set project-supporters project-id 
                  (unwrap-panic (as-max-len? (append supporters tx-sender) u200))))
              true)
            
            (map-set creator-projects project-id 
              (merge project { total-support: (+ (get total-support project) amount) }))
            
            (ok true)))))
    err-not-found))

;; Finalize project funding status
(define-public (finalize-project-funding (project-id uint))
  (match (map-get? creator-projects project-id)
    project
    (if (<= (get-current-block) (get support-deadline project))
      err-deadline-not-passed
      (if (not (is-eq (get status project) status-seeking-support))
        err-funding-active
        (let ((new-status (if (>= (get total-support project) (get funding-target project))
                           status-funded
                           status-abandoned)))
          (map-set creator-projects project-id 
            (merge project { status: new-status }))
          (ok new-status))))
    err-not-found))

;; Creator withdraws funding
(define-public (claim-creator-funding (project-id uint))
  (match (map-get? creator-projects project-id)
    project
    (if (not (is-project-creator project-id tx-sender))
      err-owner-only
      (if (not (is-eq (get status project) status-funded))
        err-funding-successful
        (begin
          (try! (as-contract (stx-transfer? (get total-support project) tx-sender (get creator project))))
          (ok true))))
    err-not-found))

;; Supporters get refunds for abandoned projects
(define-public (claim-support-refund (project-id uint))
  (match (map-get? creator-projects project-id)
    project
    (if (not (is-eq (get status project) status-abandoned))
      err-funding-failed
      (let ((support-amount (get-supporter-contribution project-id tx-sender)))
        (if (is-eq support-amount u0)
          err-no-support
          (begin
            (map-delete fan-support { project-id: project-id, supporter: tx-sender })
            (try! (as-contract (stx-transfer? support-amount tx-sender tx-sender)))
            (ok support-amount)))))
    err-not-found))