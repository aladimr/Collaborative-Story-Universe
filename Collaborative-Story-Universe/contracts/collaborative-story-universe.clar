;; Collaborative Story Universe - Shared fictional worlds where creators earn from contributions
;; A decentralized platform for collaborative storytelling with creator rewards

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-STORY-NOT-FOUND (err u101))
(define-constant ERR-CHAPTER-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-INVALID-PARAMS (err u105))
(define-constant ERR-VOTING-ENDED (err u106))
(define-constant ERR-ALREADY-VOTED (err u107))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Platform fee (2%)
(define-constant PLATFORM-FEE u200) ;; basis points (200 = 2%)
(define-constant BASIS-POINTS u10000)

;; Voting duration (1440 blocks = ~24 hours)
(define-constant VOTING-DURATION u1440)

;; Data structures
(define-map stories
    { story-id: uint }
    {
        title: (string-ascii 100),
        description: (string-ascii 500),
        creator: principal,
        created-at: uint,
        total-earnings: uint,
        chapter-count: uint,
        is-active: bool
    }
)

(define-map chapters
    { story-id: uint, chapter-id: uint }
    {
        title: (string-ascii 100),
        content-hash: (string-ascii 64), ;; IPFS hash
        author: principal,
        created-at: uint,
        earnings: uint,
        votes-for: uint,
        votes-against: uint,
        voting-ends-at: uint,
        is-approved: bool
    }
)

(define-map contributors
    { story-id: uint, contributor: principal }
    {
        contributions: uint,
        earnings: uint,
        reputation: uint
    }
)

(define-map votes
    { story-id: uint, chapter-id: uint, voter: principal }
    { vote: bool, voted-at: uint }
)

(define-map user-profiles
    { user: principal }
    {
        username: (string-ascii 50),
        bio: (string-ascii 200),
        total-earnings: uint,
        reputation-score: uint,
        stories-created: uint,
        chapters-written: uint
    }
)

;; Data variables
(define-data-var next-story-id uint u1)
(define-data-var platform-treasury uint u0)

;; Public functions

;; Create a new story universe
(define-public (create-story (title (string-ascii 100)) (description (string-ascii 500)))
    (let
        (
            (story-id (var-get next-story-id))
            (caller tx-sender)
        )
        (asserts! (> (len title) u0) ERR-INVALID-PARAMS)
        (asserts! (> (len description) u0) ERR-INVALID-PARAMS)
        
        ;; Create the story
        (map-set stories
            { story-id: story-id }
            {
                title: title,
                description: description,
                creator: caller,
                created-at: block-height,
                total-earnings: u0,
                chapter-count: u0,
                is-active: true
            }
        )
        
        ;; Initialize creator as contributor
        (map-set contributors
            { story-id: story-id, contributor: caller }
            {
                contributions: u1,
                earnings: u0,
                reputation: u10
            }
        )
        
        ;; Update user profile
        (update-user-profile-on-story-creation caller)
        
        ;; Increment story counter
        (var-set next-story-id (+ story-id u1))
        
        (ok story-id)
    )
)

;; Submit a new chapter for voting
(define-public (submit-chapter 
    (story-id uint) 
    (title (string-ascii 100)) 
    (content-hash (string-ascii 64)))
    (let
        (
            (story (unwrap! (map-get? stories { story-id: story-id }) ERR-STORY-NOT-FOUND))
            (chapter-id (+ (get chapter-count story) u1))
            (caller tx-sender)
        )
        (asserts! (get is-active story) ERR-NOT-AUTHORIZED)
        (asserts! (> (len title) u0) ERR-INVALID-PARAMS)
        (asserts! (> (len content-hash) u0) ERR-INVALID-PARAMS)
        
        ;; Create chapter for voting
        (map-set chapters
            { story-id: story-id, chapter-id: chapter-id }
            {
                title: title,
                content-hash: content-hash,
                author: caller,
                created-at: block-height,
                earnings: u0,
                votes-for: u0,
                votes-against: u0,
                voting-ends-at: (+ block-height VOTING-DURATION),
                is-approved: false
            }
        )
        
        ;; Update story chapter count
        (map-set stories
            { story-id: story-id }
            (merge story { chapter-count: chapter-id })
        )
        
        (ok chapter-id)
    )
)

;; Vote on a chapter
(define-public (vote-chapter (story-id uint) (chapter-id uint) (vote-for bool))
    (let
        (
            (chapter (unwrap! (map-get? chapters { story-id: story-id, chapter-id: chapter-id }) ERR-CHAPTER-NOT-FOUND))
            (caller tx-sender)
        )
        (asserts! (< block-height (get voting-ends-at chapter)) ERR-VOTING-ENDED)
        (asserts! (is-none (map-get? votes { story-id: story-id, chapter-id: chapter-id, voter: caller })) ERR-ALREADY-VOTED)
        
        ;; Record vote
        (map-set votes
            { story-id: story-id, chapter-id: chapter-id, voter: caller }
            { vote: vote-for, voted-at: block-height }
        )
        
        ;; Update vote counts
        (if vote-for
            (map-set chapters
                { story-id: story-id, chapter-id: chapter-id }
                (merge chapter { votes-for: (+ (get votes-for chapter) u1) })
            )
            (map-set chapters
                { story-id: story-id, chapter-id: chapter-id }
                (merge chapter { votes-against: (+ (get votes-against chapter) u1) })
            )
        )
        
        (ok true)
    )
)

;; Finalize chapter voting and approve if successful
(define-public (finalize-chapter-voting (story-id uint) (chapter-id uint))
    (let
        (
            (chapter (unwrap! (map-get? chapters { story-id: story-id, chapter-id: chapter-id }) ERR-CHAPTER-NOT-FOUND))
        )
        (asserts! (>= block-height (get voting-ends-at chapter)) ERR-VOTING-ENDED)
        (asserts! (not (get is-approved chapter)) ERR-ALREADY-EXISTS)
        
        ;; Check if chapter is approved (more votes for than against)
        (if (> (get votes-for chapter) (get votes-against chapter))
            (begin
                ;; Approve chapter
                (map-set chapters
                    { story-id: story-id, chapter-id: chapter-id }
                    (merge chapter { is-approved: true })
                )
                
                ;; Update contributor stats
                (update-contributor-stats story-id (get author chapter))
                
                ;; Update user profile
                (update-user-profile-on-chapter-approval (get author chapter))
                
                (ok true)
            )
            (ok false)
        )
    )
)

;; Contribute STX to a story (earnings distribution)
(define-public (contribute-to-story (story-id uint) (amount uint))
    (let
        (
            (story (unwrap! (map-get? stories { story-id: story-id }) ERR-STORY-NOT-FOUND))
            (caller tx-sender)
            (platform-fee-amount (/ (* amount PLATFORM-FEE) BASIS-POINTS))
            (creator-amount (/ (* amount u5000) BASIS-POINTS)) ;; 50% to creator
            (contributors-amount (- amount (+ platform-fee-amount creator-amount)))
        )
        (asserts! (> amount u0) ERR-INVALID-PARAMS)
        
        ;; Transfer STX from caller
        (try! (stx-transfer? amount caller (as-contract tx-sender)))
        
        ;; Distribute earnings
        (try! (as-contract (stx-transfer? creator-amount tx-sender (get creator story))))
        
        ;; Update platform treasury
        (var-set platform-treasury (+ (var-get platform-treasury) platform-fee-amount))
        
        ;; Update story earnings
        (map-set stories
            { story-id: story-id }
            (merge story { total-earnings: (+ (get total-earnings story) amount) })
        )
        
        ;; Distribute remaining amount to contributors based on their contributions
        (try! (distribute-to-contributors story-id contributors-amount))
        
        (ok true)
    )
)

;; Create or update user profile
(define-public (update-profile (username (string-ascii 50)) (bio (string-ascii 200)))
    (let
        (
            (caller tx-sender)
            (existing-profile (map-get? user-profiles { user: caller }))
        )
        (asserts! (> (len username) u0) ERR-INVALID-PARAMS)
        
        (match existing-profile
            profile
            (map-set user-profiles
                { user: caller }
                (merge profile { username: username, bio: bio })
            )
            (map-set user-profiles
                { user: caller }
                {
                    username: username,
                    bio: bio,
                    total-earnings: u0,
                    reputation-score: u0,
                    stories-created: u0,
                    chapters-written: u0
                }
            )
        )
        
        (ok true)
    )
)

;; Read-only functions

;; Get story details
(define-read-only (get-story (story-id uint))
    (map-get? stories { story-id: story-id })
)

;; Get chapter details
(define-read-only (get-chapter (story-id uint) (chapter-id uint))
    (map-get? chapters { story-id: story-id, chapter-id: chapter-id })
)

;; Get contributor stats
(define-read-only (get-contributor-stats (story-id uint) (contributor principal))
    (map-get? contributors { story-id: story-id, contributor: contributor })
)

;; Get user profile
(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles { user: user })
)

;; Get platform treasury balance
(define-read-only (get-platform-treasury)
    (var-get platform-treasury)
)

;; Get next story ID
(define-read-only (get-next-story-id)
    (var-get next-story-id)
)

;; Private functions

;; Update contributor statistics
(define-private (update-contributor-stats (story-id uint) (contributor principal))
    (let
        (
            (existing-stats (map-get? contributors { story-id: story-id, contributor: contributor }))
        )
        (match existing-stats
            stats
            (map-set contributors
                { story-id: story-id, contributor: contributor }
                (merge stats 
                    { 
                        contributions: (+ (get contributions stats) u1),
                        reputation: (+ (get reputation stats) u5)
                    }
                )
            )
            (map-set contributors
                { story-id: story-id, contributor: contributor }
                {
                    contributions: u1,
                    earnings: u0,
                    reputation: u5
                }
            )
        )
    )
)

;; Update user profile on story creation
(define-private (update-user-profile-on-story-creation (user principal))
    (let
        (
            (existing-profile (map-get? user-profiles { user: user }))
        )
        (match existing-profile
            profile
            (map-set user-profiles
                { user: user }
                (merge profile 
                    { 
                        stories-created: (+ (get stories-created profile) u1),
                        reputation-score: (+ (get reputation-score profile) u10)
                    }
                )
            )
            ;; Profile doesn't exist, will be created when user updates profile
            true
        )
    )
)

;; Update user profile on chapter approval
(define-private (update-user-profile-on-chapter-approval (user principal))
    (let
        (
            (existing-profile (map-get? user-profiles { user: user }))
        )
        (match existing-profile
            profile
            (map-set user-profiles
                { user: user }
                (merge profile 
                    { 
                        chapters-written: (+ (get chapters-written profile) u1),
                        reputation-score: (+ (get reputation-score profile) u5)
                    }
                )
            )
            ;; Profile doesn't exist, will be created when user updates profile
            true
        )
    )
)

;; Distribute earnings to contributors (simplified version)
(define-private (distribute-to-contributors (story-id uint) (amount uint))
    ;; In a full implementation, this would iterate through all contributors
    ;; and distribute based on their contribution percentage
    ;; For now, we'll just add to platform treasury
    (begin
        (var-set platform-treasury (+ (var-get platform-treasury) amount))
        (ok true)
    )
)