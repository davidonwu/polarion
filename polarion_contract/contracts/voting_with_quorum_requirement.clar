;; Advanced Voting with Quorum Requirement Smart Contract
;; Enhanced with multiple voting types, delegation, and governance features

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ELECTION-NOT-FOUND (err u101))
(define-constant ERR-ELECTION-ENDED (err u102))
(define-constant ERR-ELECTION-ACTIVE (err u103))
(define-constant ERR-ALREADY-VOTED (err u104))
(define-constant ERR-INVALID-CANDIDATE (err u105))
(define-constant ERR-QUORUM-NOT-MET (err u106))
(define-constant ERR-INVALID-QUORUM (err u107))
(define-constant ERR-INVALID-VOTING-TYPE (err u108))
(define-constant ERR-INSUFFICIENT-STAKE (err u109))
(define-constant ERR-DELEGATION-NOT-ALLOWED (err u110))
(define-constant ERR-SELF-DELEGATION (err u111))
(define-constant ERR-INVALID-PROPOSAL (err u112))
(define-constant ERR-PROPOSAL-EXPIRED (err u113))
(define-constant ERR-MINIMUM-DURATION (err u114))
(define-constant ERR-INVALID-WEIGHT (err u115))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Voting types
(define-constant SIMPLE-MAJORITY u1)
(define-constant SUPERMAJORITY u2)
(define-constant RANKED-CHOICE u3)
(define-constant WEIGHTED-VOTING u4)

;; Minimum voting duration (blocks)
(define-constant MIN-VOTING-DURATION u144) ;; ~24 hours

;; Data structures
(define-map elections
  { election-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    candidates: (list 10 (string-ascii 50)),
    voting-type: uint,
    quorum-required: uint,
    supermajority-threshold: uint, ;; For supermajority votes (e.g., 67 for 67%)
    total-votes: uint,
    total-voting-power: uint,
    start-block: uint,
    end-block: uint,
    is-finalized: bool,
    allow-delegation: bool,
    min-stake-required: uint,
    creator: principal,
    category: (string-ascii 50)
  }
)

(define-map votes
  { election-id: uint, voter: principal }
  { 
    candidate-index: uint, 
    voting-power: uint,
    block-height: uint,
    ranked-choices: (list 5 uint) ;; For ranked choice voting
  }
)

(define-map candidate-votes
  { election-id: uint, candidate-index: uint }
  { 
    vote-count: uint,
    voting-power: uint 
  }
)

(define-map eligible-voters
  { election-id: uint, voter: principal }
  { 
    is-eligible: bool,
    voting-weight: uint,
    stake-amount: uint
  }
)

;; Vote delegation system
(define-map delegations
  { election-id: uint, delegator: principal }
  { 
    delegate: principal,
    is-active: bool,
    delegation-power: uint
  }
)

(define-map delegate-power
  { election-id: uint, delegate: principal }
  { total-delegated-power: uint }
)

;; Proposals and governance
(define-map proposals
  { proposal-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 1000),
    proposer: principal,
    execution-delay: uint,
    min-approval-percentage: uint,
    creation-block: uint,
    voting-end-block: uint,
    execution-block: uint,
    is-executed: bool,
    proposal-type: (string-ascii 50)
  }
)

;; Vote history and analytics
(define-map voter-history
  { voter: principal }
  {
    total-elections-participated: uint,
    total-voting-power-used: uint,
    last-vote-block: uint
  }
)

;; Election categories and tags
(define-map election-categories
  { category: (string-ascii 50) }
  { 
    total-elections: uint,
    description: (string-ascii 200)
  }
)

;; Emergency controls
(define-map emergency-pause
  { election-id: uint }
  { 
    is-paused: bool,
    pause-reason: (string-ascii 200),
    paused-by: principal,
    pause-block: uint
  }
)

;; Data variables
(define-data-var next-election-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var governance-token principal tx-sender)
(define-data-var min-proposal-stake uint u1000)

;; Public functions

;; Create a new election with enhanced features
(define-public (create-election 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (candidates (list 10 (string-ascii 50)))
  (voting-type uint)
  (quorum-required uint)
  (supermajority-threshold uint)
  (duration-blocks uint)
  (allow-delegation bool)
  (min-stake-required uint)
  (category (string-ascii 50)))
  (let
    (
      (election-id (var-get next-election-id))
      (start-block (+ block-height u10)) ;; Small delay before voting starts
      (end-block (+ start-block duration-blocks))
    )
    ;; Validate inputs
    (asserts! (> quorum-required u0) ERR-INVALID-QUORUM)
    (asserts! (>= duration-blocks MIN-VOTING-DURATION) ERR-MINIMUM-DURATION)
    (asserts! (<= voting-type u4) ERR-INVALID-VOTING-TYPE)
    (asserts! (and (>= supermajority-threshold u51) (<= supermajority-threshold u100)) ERR-INVALID-QUORUM)
    
    ;; Store election data
    (map-set elections
      { election-id: election-id }
      {
        title: title,
        description: description,
        candidates: candidates,
        voting-type: voting-type,
        quorum-required: quorum-required,
        supermajority-threshold: supermajority-threshold,
        total-votes: u0,
        total-voting-power: u0,
        start-block: start-block,
        end-block: end-block,
        is-finalized: false,
        allow-delegation: allow-delegation,
        min-stake-required: min-stake-required,
        creator: tx-sender,
        category: category
      }
    )
    
    ;; Initialize candidate vote counts
    (map initialize-candidate-votes
      (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)
      (list election-id election-id election-id election-id election-id
            election-id election-id election-id election-id election-id)
    )
    
    ;; Update category stats
    (update-category-stats category)
    
    ;; Increment election counter
    (var-set next-election-id (+ election-id u1))
    
    (ok election-id)
  )
)

;; Helper function to initialize candidate vote counts
(define-private (initialize-candidate-votes (candidate-index uint) (election-id uint))
  (map-set candidate-votes
    { election-id: election-id, candidate-index: candidate-index }
    { vote-count: u0, voting-power: u0 }
  )
)

;; Update category statistics
(define-private (update-category-stats (category (string-ascii 50)))
  (let
    (
      (current-stats (default-to { total-elections: u0, description: "" }
        (map-get? election-categories { category: category })))
    )
    (map-set election-categories
      { category: category }
      { 
        total-elections: (+ (get total-elections current-stats) u1),
        description: (get description current-stats)
      }
    )
  )
)

;; Add eligible voter with voting weight and stake
(define-public (add-eligible-voter (election-id uint) (voter principal) (voting-weight uint) (stake-amount uint))
  (let
    (
      (election (unwrap! (map-get? elections { election-id: election-id }) ERR-ELECTION-NOT-FOUND))
    )
    ;; Only election creator can add eligible voters
    (asserts! (is-eq tx-sender (get creator election)) ERR-NOT-AUTHORIZED)
    
    ;; Election must not be finalized
    (asserts! (not (get is-finalized election)) ERR-ELECTION-ENDED)
    
    ;; Validate voting weight
    (asserts! (> voting-weight u0) ERR-INVALID-WEIGHT)
    
    (map-set eligible-voters
      { election-id: election-id, voter: voter }
      { 
        is-eligible: true,
        voting-weight: voting-weight,
        stake-amount: stake-amount
      }
    )
    
    (ok true)
  )
)

;; Delegate voting power
(define-public (delegate-vote (election-id uint) (delegate principal))
  (let
    (
      (election (unwrap! (map-get? elections { election-id: election-id }) ERR-ELECTION-NOT-FOUND))
      (voter-info (unwrap! (map-get? eligible-voters { election-id: election-id, voter: tx-sender }) ERR-NOT-AUTHORIZED))
      (current-delegate-power (default-to { total-delegated-power: u0 }
        (map-get? delegate-power { election-id: election-id, delegate: delegate })))
    )
    ;; Check if delegation is allowed
    (asserts! (get allow-delegation election) ERR-DELEGATION-NOT-ALLOWED)
    
    ;; Cannot delegate to self
    (asserts! (not (is-eq tx-sender delegate)) ERR-SELF-DELEGATION)
    
    ;; Delegate must be eligible voter
    (asserts! (is-some (map-get? eligible-voters { election-id: election-id, voter: delegate })) ERR-NOT-AUTHORIZED)
    
    ;; Election must be active
    (asserts! (and (>= block-height (get start-block election)) (< block-height (get end-block election))) ERR-ELECTION-ENDED)
    
    ;; Record delegation
    (map-set delegations
      { election-id: election-id, delegator: tx-sender }
      {
        delegate: delegate,
        is-active: true,
        delegation-power: (get voting-weight voter-info)
      }
    )
    
    ;; Update delegate's total power
    (map-set delegate-power
      { election-id: election-id, delegate: delegate }
      { total-delegated-power: (+ (get total-delegated-power current-delegate-power) (get voting-weight voter-info)) }
    )
    
    (ok true)
  )
)

;; Cast a vote with enhanced features
(define-public (cast-vote (election-id uint) (candidate-index uint) (ranked-choices (list 5 uint)))
  (let
    (
      (election (unwrap! (map-get? elections { election-id: election-id }) ERR-ELECTION-NOT-FOUND))
      (voter-info (unwrap! (map-get? eligible-voters { election-id: election-id, voter: tx-sender }) ERR-NOT-AUTHORIZED))
      (delegated-power (default-to { total-delegated-power: u0 }
        (map-get? delegate-power { election-id: election-id, delegate: tx-sender })))
      (total-power (+ (get voting-weight voter-info) (get total-delegated-power delegated-power)))
      (current-votes (default-to { vote-count: u0, voting-power: u0 } 
        (map-get? candidate-votes { election-id: election-id, candidate-index: candidate-index })))
    )
    ;; Check if election is active
    (asserts! (and (>= block-height (get start-block election)) (< block-height (get end-block election))) ERR-ELECTION-ENDED)
    (asserts! (not (get is-finalized election)) ERR-ELECTION-ENDED)
    (asserts! (not (is-election-paused election-id)) ERR-ELECTION-ENDED)
    
    ;; Check if voter is eligible
    (asserts! (get is-eligible voter-info) ERR-NOT-AUTHORIZED)
    
    ;; Check minimum stake requirement
    (asserts! (>= (get stake-amount voter-info) (get min-stake-required election)) ERR-INSUFFICIENT-STAKE)
    
    ;; Check if voter has already voted
    (asserts! (is-none (map-get? votes { election-id: election-id, voter: tx-sender })) ERR-ALREADY-VOTED)
    
    ;; Check if voter has delegated their vote
    (asserts! (not (is-delegation-active election-id tx-sender)) ERR-DELEGATION-NOT-ALLOWED)
    
    ;; Validate candidate index
    (asserts! (< candidate-index (len (get candidates election))) ERR-INVALID-CANDIDATE)
    
    ;; Record the vote
    (map-set votes
      { election-id: election-id, voter: tx-sender }
      { 
        candidate-index: candidate-index,
        voting-power: total-power,
        block-height: block-height,
        ranked-choices: ranked-choices
      }
    )
    
    ;; Update candidate vote count
    (map-set candidate-votes
      { election-id: election-id, candidate-index: candidate-index }
      { 
        vote-count: (+ (get vote-count current-votes) u1),
        voting-power: (+ (get voting-power current-votes) total-power)
      }
    )
    
    ;; Update total votes and voting power
    (map-set elections
      { election-id: election-id }
      (merge election { 
        total-votes: (+ (get total-votes election) u1),
        total-voting-power: (+ (get total-voting-power election) total-power)
      })
    )
    
    ;; Update voter history
    (update-voter-history tx-sender total-power)
    
    (ok true)
  )
)

;; Update voter participation history
(define-private (update-voter-history (voter principal) (voting-power uint))
  (let
    (
      (current-history (default-to 
        { total-elections-participated: u0, total-voting-power-used: u0, last-vote-block: u0 }
        (map-get? voter-history { voter: voter })))
    )
    (map-set voter-history
      { voter: voter }
      {
        total-elections-participated: (+ (get total-elections-participated current-history) u1),
        total-voting-power-used: (+ (get total-voting-power-used current-history) voting-power),
        last-vote-block: block-height
      }
    )
  )
)

;; Emergency pause election
(define-public (emergency-pause-election (election-id uint) (reason (string-ascii 200)))
  (let
    (
      (election (unwrap! (map-get? elections { election-id: election-id }) ERR-ELECTION-NOT-FOUND))
    )
    ;; Only election creator or contract owner can pause
    (asserts! (or (is-eq tx-sender (get creator election)) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    
    (map-set emergency-pause
      { election-id: election-id }
      {
        is-paused: true,
        pause-reason: reason,
        paused-by: tx-sender,
        pause-block: block-height
      }
    )
    
    (ok true)
  )
)

;; Resume paused election
(define-public (resume-election (election-id uint))
  (let
    (
      (election (unwrap! (map-get? elections { election-id: election-id }) ERR-ELECTION-NOT-FOUND))
    )
    ;; Only election creator or contract owner can resume
    (asserts! (or (is-eq tx-sender (get creator election)) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    
    (map-delete emergency-pause { election-id: election-id })
    
    (ok true)
  )
)

;; Finalize election with enhanced validation
(define-public (finalize-election (election-id uint))
  (let
    (
      (election (unwrap! (map-get? elections { election-id: election-id }) ERR-ELECTION-NOT-FOUND))
      (voting-type (get voting-type election))
    )
    ;; Only election creator can finalize
    (asserts! (is-eq tx-sender (get creator election)) ERR-NOT-AUTHORIZED)
    
    ;; Election must be ended
    (asserts! (>= block-height (get end-block election)) ERR-ELECTION-ACTIVE)
    
    ;; Election must not be already finalized
    (asserts! (not (get is-finalized election)) ERR-ELECTION-ENDED)
    
    ;; Election must not be paused
    (asserts! (not (is-election-paused election-id)) ERR-ELECTION-ENDED)
    
    ;; Check quorum based on voting type
    (asserts! (check-quorum-met election) ERR-QUORUM-NOT-MET)
    
    ;; Mark election as finalized
    (map-set elections
      { election-id: election-id }
      (merge election { is-finalized: true })
    )
    
    (ok true)
  )
)

;; Create governance proposal
(define-public (create-proposal 
  (title (string-ascii 100))
  (description (string-ascii 1000))
  (execution-delay uint)
  (min-approval-percentage uint)
  (voting-duration uint)
  (proposal-type (string-ascii 50)))
  (let
    (
      (proposal-id (var-get next-proposal-id))
      (voting-end-block (+ block-height voting-duration))
      (execution-block (+ voting-end-block execution-delay))
    )
    ;; Validate minimum approval percentage
    (asserts! (and (>= min-approval-percentage u1) (<= min-approval-percentage u100)) ERR-INVALID-QUORUM)
    
    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        proposer: tx-sender,
        execution-delay: execution-delay,
        min-approval-percentage: min-approval-percentage,
        creation-block: block-height,
        voting-end-block: voting-end-block,
        execution-block: execution-block,
        is-executed: false,
        proposal-type: proposal-type
      }
    )
    
    (var-set next-proposal-id (+ proposal-id u1))
    
    (ok proposal-id)
  )
)

;; Read-only functions

;; Check if quorum is met based on voting type
(define-read-only (check-quorum-met (election (tuple (title (string-ascii 100)) (description (string-ascii 500)) (candidates (list 10 (string-ascii 50))) (voting-type uint) (quorum-required uint) (supermajority-threshold uint) (total-votes uint) (total-voting-power uint) (start-block uint) (end-block uint) (is-finalized bool) (allow-delegation bool) (min-stake-required uint) (creator principal) (category (string-ascii 50)))))
  (let
    (
      (voting-type (get voting-type election))
      (total-votes (get total-votes election))
      (quorum-required (get quorum-required election))
    )
    (if (is-eq voting-type WEIGHTED-VOTING)
      (>= (get total-voting-power election) quorum-required)
      (>= total-votes quorum-required)
    )
  )
)

;; Check if election is paused
(define-read-only (is-election-paused (election-id uint))
  (default-to false 
    (get is-paused (map-get? emergency-pause { election-id: election-id })))
)

;; Check if delegation is active
(define-read-only (is-delegation-active (election-id uint) (voter principal))
  (default-to false 
    (get is-active (map-get? delegations { election-id: election-id, delegator: voter })))
)

;; Get comprehensive election details
(define-read-only (get-election-details (election-id uint))
  (map-get? elections { election-id: election-id })
)

;; Get vote with full details
(define-read-only (get-detailed-vote (election-id uint) (voter principal))
  (map-get? votes { election-id: election-id, voter: voter })
)

;; Get candidate votes with power
(define-read-only (get-candidate-vote-details (election-id uint) (candidate-index uint))
  (map-get? candidate-votes { election-id: election-id, candidate-index: candidate-index })
)

;; Get voter eligibility and stake info
(define-read-only (get-voter-info (election-id uint) (voter principal))
  (map-get? eligible-voters { election-id: election-id, voter: voter })
)

;; Get delegation info
(define-read-only (get-delegation-info (election-id uint) (delegator principal))
  (map-get? delegations { election-id: election-id, delegator: delegator })
)

;; Get delegate's total power
(define-read-only (get-delegate-power (election-id uint) (delegate principal))
  (map-get? delegate-power { election-id: election-id, delegate: delegate })
)

;; Get voter participation history
(define-read-only (get-voter-history (voter principal))
  (map-get? voter-history { voter: voter })
)

;; Get category statistics
(define-read-only (get-category-stats (category (string-ascii 50)))
  (map-get? election-categories { category: category })
)

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

;; Get emergency pause info
(define-read-only (get-pause-info (election-id uint))
  (map-get? emergency-pause { election-id: election-id })
)

;; Calculate election winner based on voting type
(define-read-only (calculate-winner (election-id uint))
  (let
    (
      (election (unwrap! (map-get? elections { election-id: election-id }) (err "Election not found")))
    )
    (if (and (get is-finalized election) (check-quorum-met election))
      (ok (find-leading-candidate election-id (get voting-type election)))
      (err "Election not finalized or quorum not met")
    )
  )
)

;; Find leading candidate based on voting type
(define-read-only (find-leading-candidate (election-id uint) (voting-type uint))
  (if (is-eq voting-type WEIGHTED-VOTING)
    (find-candidate-with-most-power election-id)
    (find-candidate-with-most-votes election-id)
  )
)

;; Helper functions for winner calculation
(define-read-only (find-candidate-with-most-votes (election-id uint))
  ;; Returns candidate index with most votes
  ;; Implementation would iterate through candidates
  u0 ;; Placeholder - would need actual implementation
)

(define-read-only (find-candidate-with-most-power (election-id uint))
  ;; Returns candidate index with most voting power
  ;; Implementation would iterate through candidates
  u0 ;; Placeholder - would need actual implementation
)

;; Get comprehensive election results
(define-read-only (get-comprehensive-results (election-id uint))
  (match (map-get? elections { election-id: election-id })
    election
      (if (and (get is-finalized election) (check-quorum-met election))
        (some {
          election-id: election-id,
          title: (get title election),
          description: (get description election),
          candidates: (get candidates election),
          voting-type: (get voting-type election),
          total-votes: (get total-votes election),
          total-voting-power: (get total-voting-power election),
          quorum-required: (get quorum-required election),
          quorum-met: true,
          is-valid: true,
          category: (get category election),
          winner: (unwrap-panic (calculate-winner election-id))
        })
        (some {
          election-id: election-id,
          title: (get title election),
          description: (get description election),
          candidates: (get candidates election),
          voting-type: (get voting-type election),
          total-votes: (get total-votes election),
          total-voting-power: (get total-voting-power election),
          quorum-required: (get quorum-required election),
          quorum-met: false,
          is-valid: false,
          category: (get category election),
          winner: u999 ;; Invalid winner indicator
        })
      )
    none
  )
)

;; Get current counters
(define-read-only (get-next-election-id)
  (var-get next-election-id)
)

(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id)
)