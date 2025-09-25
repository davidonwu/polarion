;; Multi-Send with Variable Amounts Smart Contract
;; Allows sending different amounts to different addresses in a single transaction

;; Error constants
(define-constant ERR-LENGTH-MISMATCH (err u100))
(define-constant ERR-EMPTY-ARRAYS (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-TRANSFER-FAILED (err u103))
(define-constant ERR-MAX-RECIPIENTS-EXCEEDED (err u104))

;; Constants
(define-constant MAX-RECIPIENTS u50) ;; Maximum number of recipients per transaction

;; Data variables
(define-data-var total-transactions uint u0)

;; Maps to track transaction history (optional)
(define-map transaction-history 
  uint 
  {
    sender: principal,
    recipients-count: uint,
    total-amount: uint,
    block-height: uint
  }
)

;; Private function to validate arrays
(define-private (validate-arrays (recipients (list 50 principal)) (amounts (list 50 uint)))
  (let 
    (
      (recipients-len (len recipients))
      (amounts-len (len amounts))
    )
    (and
      ;; Check if arrays are not empty
      (> recipients-len u0)
      (> amounts-len u0)
      ;; Check if array lengths match
      (is-eq recipients-len amounts-len)
      ;; Check if within max recipients limit
      (<= recipients-len MAX-RECIPIENTS)
    )
  )
)

;; Private function to calculate total amount needed
(define-private (sum-amounts (amounts (list 50 uint)))
  (fold + amounts u0)
)

;; Private function to process a single transfer by index
(define-private (process-transfer-by-index 
  (index uint) 
  (acc {recipients: (list 50 principal), amounts: (list 50 uint), success: bool})
)
  (if (get success acc)
    (if (< index (len (get recipients acc)))
      (let 
        (
          (recipient (unwrap! (element-at (get recipients acc) index) acc))
          (amount (unwrap! (element-at (get amounts acc) index) acc))
        )
        (if (> amount u0)
          (match (stx-transfer? amount tx-sender recipient)
            success acc
            error {recipients: (get recipients acc), amounts: (get amounts acc), success: false}
          )
          acc
        )
      )
      acc
    )
    acc
  )
)

;; Main multi-send function
(define-public (multi-send (recipients (list 50 principal)) (amounts (list 50 uint)))
  (let 
    (
      (total-amount (sum-amounts amounts))
      (sender-balance (stx-get-balance tx-sender))
      (transaction-id (+ (var-get total-transactions) u1))
      (recipients-count (len recipients))
    )
    ;; Validate input arrays
    (asserts! (validate-arrays recipients amounts) ERR-LENGTH-MISMATCH)
    
    ;; Check if arrays are not empty
    (asserts! (> recipients-count u0) ERR-EMPTY-ARRAYS)
    
    ;; Check if sender has sufficient balance
    (asserts! (>= sender-balance total-amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Process transfers sequentially
    (let 
      (
        (transfer-result 
          (fold process-transfer-by-index 
                (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49)
                {recipients: recipients, amounts: amounts, success: true}
          )
        )
      )
      (if (get success transfer-result)
        (begin
          ;; Record transaction history
          (map-set transaction-history transaction-id
            {
              sender: tx-sender,
              recipients-count: recipients-count,
              total-amount: total-amount,
              block-height: block-height
            }
          )
          ;; Update transaction counter
          (var-set total-transactions transaction-id)
          (ok {
            transaction-id: transaction-id,
            recipients-count: recipients-count,
            total-amount-sent: total-amount
          })
        )
        ERR-TRANSFER-FAILED
      )
    )
  )
)

;; Read-only function to get transaction history
(define-read-only (get-transaction-history (transaction-id uint))
  (map-get? transaction-history transaction-id)
)

;; Read-only function to get total transactions count
(define-read-only (get-total-transactions)
  (var-get total-transactions)
)

;; Read-only function to validate arrays without executing
(define-read-only (validate-multi-send-params (recipients (list 50 principal)) (amounts (list 50 uint)))
  (let 
    (
      (total-amount (sum-amounts amounts))
      (sender-balance (stx-get-balance tx-sender))
    )
    {
      arrays-valid: (validate-arrays recipients amounts),
      sufficient-balance: (>= sender-balance total-amount),
      total-amount: total-amount,
      recipients-count: (len recipients)
    }
  )
)

;; Read-only function to calculate total amount needed
(define-read-only (calculate-total-amount (amounts (list 50 uint)))
  (sum-amounts amounts)
)

;; Read-only function to check maximum recipients limit
(define-read-only (get-max-recipients)
  MAX-RECIPIENTS
)