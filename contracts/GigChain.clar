(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_STATE (err u400))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_EXPIRED (err u410))
(define-constant ERR_INVALID_RATING (err u411))
(define-constant ERR_REVIEW_EXISTS (err u412))
(define-constant ERR_INVALID_REVIEWER (err u413))

(define-data-var next-gig-id uint u1)
(define-data-var next-bid-id uint u1)
(define-data-var next-milestone-id uint u1)
(define-data-var platform-fee-percentage uint u250)

(define-map gigs uint {
    client: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    budget: uint,
    deadline: uint,
    status: (string-ascii 20),
    selected-bid: (optional uint),
    escrow-amount: uint,
    created-at: uint
})

(define-map bids uint {
    gig-id: uint,
    freelancer: principal,
    amount: uint,
    delivery-time: uint,
    proposal: (string-ascii 300),
    status: (string-ascii 20),
    created-at: uint
})

(define-map work-submissions uint {
    gig-id: uint,
    freelancer: principal,
    description: (string-ascii 500),
    submitted-at: uint,
    client-approved: bool,
    dispute-raised: bool
})

(define-map user-profiles principal {
    reputation: uint,
    total-gigs: uint,
    completed-gigs: uint,
    total-earned: uint,
    total-spent: uint
})

(define-map escrow-balances uint uint)
(define-map platform-earnings principal uint)

(define-map milestones uint {
    gig-id: uint,
    freelancer: principal,
    title: (string-ascii 100),
    description: (string-ascii 300),
    amount: uint,
    deadline: uint,
    status: (string-ascii 20),
    submitted-at: (optional uint),
    approved-at: (optional uint)
})

(define-map milestone-submissions uint {
    milestone-id: uint,
    deliverable-description: (string-ascii 500),
    submitted-at: uint
})

(define-map freelancer-skills principal (list 10 (string-ascii 50)))
(define-map gig-categories uint (string-ascii 50))
(define-map skill-reputation {freelancer: principal, skill: (string-ascii 50)} uint)

(define-map gig-reviews uint {
    freelancer: principal,
    client: principal,
    rating: uint,
    comment: (string-ascii 300),
    created-at: uint
})

(define-map freelancer-ratings principal {
    total-reviews: uint,
    total-rating-points: uint,
    avg-rating: uint
})

(define-public (create-gig (title (string-ascii 100)) (description (string-ascii 500)) (budget uint) (deadline uint))
    (let ((gig-id (var-get next-gig-id)))
        (asserts! (> budget u0) ERR_INVALID_STATE)
        (asserts! (> deadline (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND)) ERR_INVALID_STATE)
        (map-set gigs gig-id {
            client: tx-sender,
            title: title,
            description: description,
            budget: budget,
            deadline: deadline,
            status: "open",
            selected-bid: none,
            escrow-amount: u0,
            created-at: (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND)
        })
        (var-set next-gig-id (+ gig-id u1))
        (update-user-profile tx-sender u0 u1 u0 u0 budget)
        (ok gig-id)
    )
)

(define-public (place-bid (gig-id uint) (amount uint) (delivery-time uint) (proposal (string-ascii 300)))
    (let ((gig (unwrap! (map-get? gigs gig-id) ERR_NOT_FOUND))
          (bid-id (var-get next-bid-id)))
        (asserts! (is-eq (get status gig) "open") ERR_INVALID_STATE)
        (asserts! (> amount u0) ERR_INVALID_STATE)
        (asserts! (<= amount (get budget gig)) ERR_INVALID_STATE)
        (asserts! (not (is-eq tx-sender (get client gig))) ERR_UNAUTHORIZED)
        (map-set bids bid-id {
            gig-id: gig-id,
            freelancer: tx-sender,
            amount: amount,
            delivery-time: delivery-time,
            proposal: proposal,
            status: "pending",
            created-at: (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND)
        })
        (var-set next-bid-id (+ bid-id u1))
        (ok bid-id)
    )
)

(define-public (select-bid (gig-id uint) (bid-id uint))
    (let ((gig (unwrap! (map-get? gigs gig-id) ERR_NOT_FOUND))
          (bid (unwrap! (map-get? bids bid-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get client gig)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status gig) "open") ERR_INVALID_STATE)
        (asserts! (is-eq (get gig-id bid) gig-id) ERR_INVALID_STATE)
        (asserts! (is-eq (get status bid) "pending") ERR_INVALID_STATE)
        (try! (stx-transfer? (get amount bid) tx-sender (as-contract tx-sender)))
        (map-set gigs gig-id (merge gig {
            status: "in-progress",
            selected-bid: (some bid-id),
            escrow-amount: (get amount bid)
        }))
        (map-set bids bid-id (merge bid { status: "accepted" }))
        (map-set escrow-balances gig-id (get amount bid))
        (ok true)
    )
)

(define-public (submit-work (gig-id uint) (work-description (string-ascii 500)))
    (let ((gig (unwrap! (map-get? gigs gig-id) ERR_NOT_FOUND))
          (bid-id (unwrap! (get selected-bid gig) ERR_NOT_FOUND))
          (bid (unwrap! (map-get? bids bid-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get freelancer bid)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status gig) "in-progress") ERR_INVALID_STATE)
        (map-set work-submissions gig-id {
            gig-id: gig-id,
            freelancer: tx-sender,
            description: work-description,
            submitted-at: (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND),
            client-approved: false,
            dispute-raised: false
        })
        (ok true)
    )
)

(define-public (approve-work (gig-id uint))
    (let ((gig (unwrap! (map-get? gigs gig-id) ERR_NOT_FOUND))
          (submission (unwrap! (map-get? work-submissions gig-id) ERR_NOT_FOUND))
          (bid-id (unwrap! (get selected-bid gig) ERR_NOT_FOUND))
          (bid (unwrap! (map-get? bids bid-id) ERR_NOT_FOUND))
          (escrow-amount (unwrap! (map-get? escrow-balances gig-id) ERR_NOT_FOUND))
          (platform-fee (/ (* escrow-amount (var-get platform-fee-percentage)) u10000))
          (freelancer-payment (- escrow-amount platform-fee)))
        (asserts! (is-eq tx-sender (get client gig)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status gig) "in-progress") ERR_INVALID_STATE)
        (try! (as-contract (stx-transfer? freelancer-payment tx-sender (get freelancer bid))))
        (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT_OWNER)))
        (map-set gigs gig-id (merge gig { status: "completed" }))
        (map-set work-submissions gig-id (merge submission { client-approved: true }))
        (map-delete escrow-balances gig-id)
        (update-user-profile (get client gig) u0 u0 u1 u0 u0)
        (update-user-profile (get freelancer bid) u5 u0 u1 freelancer-payment u0)
        (ok true)
    )
)

(define-public (raise-dispute (gig-id uint))
    (let ((gig (unwrap! (map-get? gigs gig-id) ERR_NOT_FOUND))
          (submission (unwrap! (map-get? work-submissions gig-id) ERR_NOT_FOUND)))
        (asserts! (or (is-eq tx-sender (get client gig)) 
                     (is-eq tx-sender (get freelancer submission))) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status gig) "in-progress") ERR_INVALID_STATE)
        (map-set work-submissions gig-id (merge submission { dispute-raised: true }))
        (map-set gigs gig-id (merge gig { status: "disputed" }))
        (ok true)
    )
)

(define-public (resolve-dispute (gig-id uint) (award-to-freelancer bool))
    (let ((gig (unwrap! (map-get? gigs gig-id) ERR_NOT_FOUND))
          (bid-id (unwrap! (get selected-bid gig) ERR_NOT_FOUND))
          (bid (unwrap! (map-get? bids bid-id) ERR_NOT_FOUND))
          (escrow-amount (unwrap! (map-get? escrow-balances gig-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status gig) "disputed") ERR_INVALID_STATE)
        (if award-to-freelancer
            (begin
                (try! (as-contract (stx-transfer? escrow-amount tx-sender (get freelancer bid))))
                (update-user-profile (get freelancer bid) u5 u0 u1 escrow-amount u0)
            )
            (try! (as-contract (stx-transfer? escrow-amount tx-sender (get client gig))))
        )
        (map-set gigs gig-id (merge gig { status: "resolved" }))
        (map-delete escrow-balances gig-id)
        (ok true)
    )
)

(define-public (cancel-gig (gig-id uint))
    (let ((gig (unwrap! (map-get? gigs gig-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get client gig)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status gig) "open") ERR_INVALID_STATE)
        (map-set gigs gig-id (merge gig { status: "cancelled" }))
        (ok true)
    )
)

(define-public (update-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-fee u1000) ERR_INVALID_STATE)
        (var-set platform-fee-percentage new-fee)
        (ok true)
    )
)

(define-private (update-user-profile (user principal) (rep-change uint) (total-gigs uint) (completed uint) (earned uint) (spent uint))
    (let ((current-profile (default-to {
            reputation: u100,
            total-gigs: u0,
            completed-gigs: u0,
            total-earned: u0,
            total-spent: u0
        } (map-get? user-profiles user))))
        (map-set user-profiles user {
            reputation: (+ (get reputation current-profile) rep-change),
            total-gigs: (+ (get total-gigs current-profile) total-gigs),
            completed-gigs: (+ (get completed-gigs current-profile) completed),
            total-earned: (+ (get total-earned current-profile) earned),
            total-spent: (+ (get total-spent current-profile) spent)
        })
    )
)

(define-read-only (get-gig (gig-id uint))
    (map-get? gigs gig-id)
)

(define-read-only (get-bid (bid-id uint))
    (map-get? bids bid-id)
)

(define-read-only (get-work-submission (gig-id uint))
    (map-get? work-submissions gig-id)
)

(define-read-only (get-user-profile (user principal))
    (default-to {
        reputation: u100,
        total-gigs: u0,
        completed-gigs: u0,
        total-earned: u0,
        total-spent: u0
    } (map-get? user-profiles user))
)

(define-read-only (get-escrow-balance (gig-id uint))
    (map-get? escrow-balances gig-id)
)

(define-read-only (get-platform-fee)
    (var-get platform-fee-percentage)
)

(define-read-only (get-next-gig-id)
    (var-get next-gig-id)
)

(define-read-only (get-next-bid-id)
    (var-get next-bid-id)
)

(define-public (create-milestone (gig-id uint) (title (string-ascii 100)) (description (string-ascii 300)) (amount uint) (deadline uint))
    (let ((gig (unwrap! (map-get? gigs gig-id) ERR_NOT_FOUND))
          (bid-id (unwrap! (get selected-bid gig) ERR_NOT_FOUND))
          (bid (unwrap! (map-get? bids bid-id) ERR_NOT_FOUND))
          (milestone-id (var-get next-milestone-id)))
        (asserts! (is-eq tx-sender (get freelancer bid)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status gig) "in-progress") ERR_INVALID_STATE)
        (asserts! (> amount u0) ERR_INVALID_STATE)
        (asserts! (> deadline (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND)) ERR_INVALID_STATE)
        (map-set milestones milestone-id {
            gig-id: gig-id,
            freelancer: tx-sender,
            title: title,
            description: description,
            amount: amount,
            deadline: deadline,
            status: "pending",
            submitted-at: none,
            approved-at: none
        })
        (var-set next-milestone-id (+ milestone-id u1))
        (ok milestone-id)
    )
)

(define-public (submit-milestone (milestone-id uint) (deliverable-description (string-ascii 500)))
    (let ((milestone (unwrap! (map-get? milestones milestone-id) ERR_NOT_FOUND))
          (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get freelancer milestone)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status milestone) "pending") ERR_INVALID_STATE)
        (map-set milestones milestone-id (merge milestone {
            status: "submitted",
            submitted-at: (some current-time)
        }))
        (map-set milestone-submissions milestone-id {
            milestone-id: milestone-id,
            deliverable-description: deliverable-description,
            submitted-at: current-time
        })
        (ok true)
    )
)

(define-public (approve-milestone (milestone-id uint))
    (let ((milestone (unwrap! (map-get? milestones milestone-id) ERR_NOT_FOUND))
          (gig (unwrap! (map-get? gigs (get gig-id milestone)) ERR_NOT_FOUND))
          (escrow-amount (unwrap! (map-get? escrow-balances (get gig-id milestone)) ERR_NOT_FOUND))
          (platform-fee (/ (* (get amount milestone) (var-get platform-fee-percentage)) u10000))
          (freelancer-payment (- (get amount milestone) platform-fee))
          (remaining-escrow (- escrow-amount (get amount milestone)))
          (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get client gig)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status milestone) "submitted") ERR_INVALID_STATE)
        (asserts! (>= escrow-amount (get amount milestone)) ERR_INSUFFICIENT_FUNDS)
        (try! (as-contract (stx-transfer? freelancer-payment tx-sender (get freelancer milestone))))
        (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT_OWNER)))
        (map-set milestones milestone-id (merge milestone {
            status: "completed",
            approved-at: (some current-time)
        }))
        (map-set escrow-balances (get gig-id milestone) remaining-escrow)
        (update-user-profile (get freelancer milestone) u2 u0 u0 freelancer-payment u0)
        (ok true)
    )
)

(define-public (reject-milestone (milestone-id uint) (feedback (string-ascii 300)))
    (let ((milestone (unwrap! (map-get? milestones milestone-id) ERR_NOT_FOUND))
          (gig (unwrap! (map-get? gigs (get gig-id milestone)) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get client gig)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status milestone) "submitted") ERR_INVALID_STATE)
        (map-set milestones milestone-id (merge milestone {
            status: "revision-needed",
            submitted-at: none
        }))
        (map-delete milestone-submissions milestone-id)
        (ok feedback)
    )
)

(define-public (resubmit-milestone (milestone-id uint) (deliverable-description (string-ascii 500)))
    (let ((milestone (unwrap! (map-get? milestones milestone-id) ERR_NOT_FOUND))
          (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get freelancer milestone)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status milestone) "revision-needed") ERR_INVALID_STATE)
        (map-set milestones milestone-id (merge milestone {
            status: "submitted",
            submitted-at: (some current-time)
        }))
        (map-set milestone-submissions milestone-id {
            milestone-id: milestone-id,
            deliverable-description: deliverable-description,
            submitted-at: current-time
        })
        (ok true)
    )
)

(define-read-only (get-milestone (milestone-id uint))
    (map-get? milestones milestone-id)
)

(define-read-only (get-milestone-submission (milestone-id uint))
    (map-get? milestone-submissions milestone-id)
)

(define-read-only (get-next-milestone-id)
    (var-get next-milestone-id)
)

(define-public (add-freelancer-skill (skill (string-ascii 50)))
    (let ((current-skills (default-to (list) (map-get? freelancer-skills tx-sender))))
        (asserts! (< (len current-skills) u10) ERR_INVALID_STATE)
        (map-set freelancer-skills tx-sender (unwrap-panic (as-max-len? (append current-skills skill) u10)))
        (ok true)
    )
)

(define-public (remove-freelancer-skill (skill (string-ascii 50)))
    (let ((current-skills (default-to (list) (map-get? freelancer-skills tx-sender))))
        (map-set freelancer-skills tx-sender (unwrap-panic (as-max-len? (filter (lambda (s) (not (is-eq s skill))) current-skills) u10)))
        (ok true)
    )
)

(define-public (set-gig-category (gig-id uint) (category (string-ascii 50)))
    (let ((gig (unwrap! (map-get? gigs gig-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get client gig)) ERR_UNAUTHORIZED)
        (map-set gig-categories gig-id category)
        (ok true)
    )
)

(define-public (update-skill-reputation (freelancer principal) (skill (string-ascii 50)) (points uint))
    (let ((current-rep (default-to u0 (map-get? skill-reputation {freelancer: freelancer, skill: skill}))))
        (map-set skill-reputation {freelancer: freelancer, skill: skill} (+ current-rep points))
        (ok true)
    )
)

(define-read-only (get-freelancer-skills (freelancer principal))
    (default-to (list) (map-get? freelancer-skills freelancer))
)

(define-read-only (get-gig-category (gig-id uint))
    (map-get? gig-categories gig-id)
)

(define-read-only (get-skill-reputation (freelancer principal) (skill (string-ascii 50)))
    (default-to u0 (map-get? skill-reputation {freelancer: freelancer, skill: skill}))
)

(define-public (submit-gig-review (gig-id uint) (rating uint) (comment (string-ascii 300)))
    (let ((gig (unwrap! (map-get? gigs gig-id) ERR_NOT_FOUND))
          (submission (unwrap! (map-get? work-submissions gig-id) ERR_NOT_FOUND))
          (bid-id (unwrap! (get selected-bid gig) ERR_NOT_FOUND))
          (bid (unwrap! (map-get? bids bid-id) ERR_NOT_FOUND))
          (existing-review (map-get? gig-reviews gig-id))
          (freelancer (get freelancer submission))
          (current-ratings (default-to {
              total-reviews: u0,
              total-rating-points: u0,
              avg-rating: u0
          } (map-get? freelancer-ratings freelancer)))
          (new-total-reviews (+ (get total-reviews current-ratings) u1))
          (new-total-points (+ (get total-rating-points current-ratings) rating))
          (new-avg-rating (/ new-total-points new-total-reviews)))
        (asserts! (is-eq tx-sender (get client gig)) ERR_INVALID_REVIEWER)
        (asserts! (is-eq (get status gig) "completed") ERR_INVALID_STATE)
        (asserts! (is-none existing-review) ERR_REVIEW_EXISTS)
        (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
        (map-set gig-reviews gig-id {
            freelancer: freelancer,
            client: tx-sender,
            rating: rating,
            comment: comment,
            created-at: (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR_NOT_FOUND)
        })
        (map-set freelancer-ratings freelancer {
            total-reviews: new-total-reviews,
            total-rating-points: new-total-points,
            avg-rating: new-avg-rating
        })
        (ok true)
    )
)

(define-read-only (get-gig-review (gig-id uint))
    (map-get? gig-reviews gig-id)
)

(define-read-only (get-freelancer-ratings (freelancer principal))
    (default-to {
        total-reviews: u0,
        total-rating-points: u0,
        avg-rating: u0
    } (map-get? freelancer-ratings freelancer))
)
