;; allowance-controller
;; 
;; This contract manages fine-grained authorization and access control for digital asset allowances.
;; It provides a secure mechanism for principals to grant, modify, and revoke specific permissions
;; for interacting with their assets, supporting flexible and granular access management.
;;
;; The contract enables precise control over asset interactions, supporting time-bound and 
;; conditional allowances across different use cases.

;; Error codes
(define-constant err-unauthorized u1)
(define-constant err-insufficient-allowance u2)
(define-constant err-allowance-expired u3)
(define-constant err-invalid-amount u4)
(define-constant err-allowance-not-found u5)

;; Allowance types for different interaction modes
(define-constant allowance-type-transfer "transfer")
(define-constant allowance-type-mint "mint")
(define-constant allowance-type-burn "burn")
(define-constant allowance-type-approve "approve")

;; Stores allowance details
(define-map allowances 
  { 
    owner: principal, 
    spender: principal, 
    allowance-type: (string-ascii 64)
  } 
  { 
    amount: uint, 
    expiry: (optional uint),
    granted-time: uint
  }
)

;; Tracks total allowance usage
(define-map allowance-usage
  { 
    owner: principal, 
    spender: principal, 
    allowance-type: (string-ascii 64)
  }
  { used-amount: uint }
)

;; Private helper functions

;; Validates allowance type
(define-private (is-valid-allowance-type (allowance-type (string-ascii 64)))
  (or
    (is-eq allowance-type allowance-type-transfer)
    (is-eq allowance-type allowance-type-mint)
    (is-eq allowance-type allowance-type-burn)
    (is-eq allowance-type allowance-type-approve)
  )
)

;; Checks if an allowance exists and is valid
(define-private (is-allowance-valid (owner principal) (spender principal) (allowance-type (string-ascii 64)))
  (match (map-get? allowances { owner: owner, spender: spender, allowance-type: allowance-type })
    allowance-details 
      (let ((current-amount (get amount allowance-details))
            (expiry (get expiry allowance-details)))
        (and 
          (> current-amount u0)
          (match expiry
            expiry-time (< block-height expiry-time)
            true  ;; No expiry means permanent allowance
          )
        )
      )
    false
  )
)

;; Checks remaining allowance
(define-private (get-remaining-allowance (owner principal) (spender principal) (allowance-type (string-ascii 64)))
  (match (map-get? allowances { owner: owner, spender: spender, allowance-type: allowance-type })
    allowance-details (get amount allowance-details)
    u0
  )
)

;; Tracks and updates allowance usage
(define-private (use-allowance (owner principal) (spender principal) (allowance-type (string-ascii 64)) (amount uint))
  (let ((current-allowance (get-remaining-allowance owner spender allowance-type))
        (current-usage (default-to { used-amount: u0 } 
                        (map-get? allowance-usage { owner: owner, spender: spender, allowance-type: allowance-type }))))
    (asserts! (>= current-allowance amount) (err err-insufficient-allowance))
    
    (map-set allowances 
      { owner: owner, spender: spender, allowance-type: allowance-type }
      { 
        amount: (- current-allowance amount), 
        expiry: (get expiry (unwrap-panic (map-get? allowances { owner: owner, spender: spender, allowance-type: allowance-type }))),
        granted-time: (get granted-time (unwrap-panic (map-get? allowances { owner: owner, spender: spender, allowance-type: allowance-type })))
      }
    )
    
    (map-set allowance-usage
      { owner: owner, spender: spender, allowance-type: allowance-type }
      { used-amount: (+ (get used-amount current-usage) amount) }
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get remaining allowance for a specific type
(define-read-only (get-allowance (owner principal) (spender principal) (allowance-type (string-ascii 64)))
  (ok (get-remaining-allowance owner spender allowance-type))
)

;; Public functions

;; Grant allowance with optional expiry
(define-public (grant-allowance 
  (spender principal) 
  (allowance-type (string-ascii 64)) 
  (amount uint)
  (expiry (optional uint)))
  (let ((sender tx-sender))
    (asserts! (is-valid-allowance-type allowance-type) (err err-unauthorized))
    (asserts! (> amount u0) (err err-invalid-amount))
    
    ;; Optional expiry validation
    (match expiry
      expiry-time (asserts! (> expiry-time block-height) (err err-allowance-expired))
      true
    )
    
    (map-set allowances
      { owner: sender, spender: spender, allowance-type: allowance-type }
      { 
        amount: amount, 
        expiry: expiry, 
        granted-time: block-height 
      }
    )
    
    (ok true)
  )
)

;; Modify existing allowance
(define-public (modify-allowance 
  (spender principal) 
  (allowance-type (string-ascii 64)) 
  (new-amount uint)
  (expiry (optional uint)))
  (let ((sender tx-sender))
    (asserts! (is-allowance-valid sender spender allowance-type) (err err-allowance-not-found))
    (asserts! (> new-amount u0) (err err-invalid-amount))
    
    ;; Optional expiry validation
    (match expiry
      expiry-time (asserts! (> expiry-time block-height) (err err-allowance-expired))
      true
    )
    
    (map-set allowances
      { owner: sender, spender: spender, allowance-type: allowance-type }
      { 
        amount: new-amount, 
        expiry: expiry, 
        granted-time: block-height 
      }
    )
    
    (ok true)
  )
)

;; Revoke allowance completely
(define-public (revoke-allowance (spender principal) (allowance-type (string-ascii 64)))
  (let ((sender tx-sender))
    (asserts! (is-allowance-valid sender spender allowance-type) (err err-allowance-not-found))
    
    (map-set allowances
      { owner: sender, spender: spender, allowance-type: allowance-type }
      { 
        amount: u0, 
        expiry: (some block-height), 
        granted-time: block-height 
      }
    )
    
    (ok true)
  )
)

;; Consume allowance (demonstrative method)
(define-public (consume-allowance 
  (owner principal) 
  (allowance-type (string-ascii 64)) 
  (amount uint))
  (let ((sender tx-sender))
    (asserts! (is-allowance-valid owner sender allowance-type) (err err-unauthorized))
    (use-allowance owner sender allowance-type amount)
  )
)