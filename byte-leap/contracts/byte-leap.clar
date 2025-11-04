;; ByteLeap - Zero-Knowledge Identity Verification System
;; A decentralized identity platform with verifiable attestations and reputation

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-threshold (err u104))
(define-constant err-insufficient-attestations (err u105))
(define-constant err-invalid-proof (err u106))

;; Data Variables
(define-data-var min-validators uint u3)
(define-data-var attestation-validity-period uint u52560) ;; ~1 year in blocks

;; Data Maps

;; Identity Registry - stores merkle root of user's verified attributes
(define-map identities
    principal
    {
        merkle-root: (buff 32),
        created-at: uint,
        last-updated: uint,
        reputation-score: uint,
        active: bool
    }
)

;; Validators - trusted entities that can attest to identity claims
(define-map validators
    principal
    {
        active: bool,
        attestation-count: uint,
        registered-at: uint
    }
)

;; Attestations - validator signatures on identity claims
(define-map attestations
    {user: principal, claim-id: (buff 32)}
    {
        validator-signatures: (list 10 principal),
        signature-count: uint,
        claim-type: (string-ascii 64),
        created-at: uint,
        verified: bool
    }
)

;; Relationships - encrypted relationship mappings
(define-map relationships
    {from: principal, to: principal}
    {
        relationship-hash: (buff 32),
        attestation-count: uint,
        created-at: uint
    }
)

;; Attribute Proofs - selective disclosure proofs for specific attributes
(define-map attribute-proofs
    {user: principal, attribute-type: (string-ascii 64)}
    {
        proof-hash: (buff 32),
        revealed: bool,
        verified: bool,
        expiry: uint
    }
)

;; Cross-chain Identity Links
(define-map cross-chain-links
    principal
    {
        external-chain: (string-ascii 32),
        external-address: (string-ascii 128),
        proof-hash: (buff 32),
        verified: bool
    }
)

;; Recovery Guardians - social recovery mechanism
(define-map recovery-guardians
    {owner: principal, guardian: principal}
    {
        active: bool,
        appointed-at: uint
    }
)

;; Recovery Requests
(define-map recovery-requests
    principal
    {
        new-merkle-root: (buff 32),
        approvals: (list 10 principal),
        approval-count: uint,
        threshold: uint,
        expires-at: uint,
        executed: bool
    }
)

;; Read-only functions

(define-read-only (get-identity (user principal))
    (map-get? identities user)
)

(define-read-only (get-attestation (user principal) (claim-id (buff 32)))
    (map-get? attestations {user: user, claim-id: claim-id})
)

(define-read-only (get-relationship (from principal) (to principal))
    (map-get? relationships {from: from, to: to})
)

(define-read-only (get-attribute-proof (user principal) (attribute-type (string-ascii 64)))
    (map-get? attribute-proofs {user: user, attribute-type: attribute-type})
)

(define-read-only (is-validator (validator principal))
    (match (map-get? validators validator)
        validator-data (get active validator-data)
        false
    )
)

(define-read-only (get-cross-chain-link (user principal))
    (map-get? cross-chain-links user)
)

(define-read-only (get-recovery-request (user principal))
    (map-get? recovery-requests user)
)

(define-read-only (get-min-validators)
    (ok (var-get min-validators))
)

;; Public functions

;; Register new identity with initial merkle root
(define-public (register-identity (merkle-root (buff 32)))
    (let
        (
            (caller tx-sender)
        )
        (asserts! (is-none (map-get? identities caller)) err-already-exists)
        (ok (map-set identities caller {
            merkle-root: merkle-root,
            created-at: block-height,
            last-updated: block-height,
            reputation-score: u0,
            active: true
        }))
    )
)

;; Update identity merkle root (for adding new verified attributes)
(define-public (update-identity (new-merkle-root (buff 32)))
    (let
        (
            (caller tx-sender)
            (identity (unwrap! (map-get? identities caller) err-not-found))
        )
        (asserts! (get active identity) err-unauthorized)
        (ok (map-set identities caller
            (merge identity {
                merkle-root: new-merkle-root,
                last-updated: block-height
            })
        ))
    )
)

;; Register as a validator (owner only for initial setup)
(define-public (register-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none (map-get? validators validator)) err-already-exists)
        (ok (map-set validators validator {
            active: true,
            attestation-count: u0,
            registered-at: block-height
        }))
    )
)

;; Create attestation for a user's claim
(define-public (create-attestation 
    (user principal) 
    (claim-id (buff 32)) 
    (claim-type (string-ascii 64))
)
    (let
        (
            (caller tx-sender)
            (validator-data (unwrap! (map-get? validators caller) err-unauthorized))
        )
        (asserts! (get active validator-data) err-unauthorized)
        (asserts! (is-some (map-get? identities user)) err-not-found)
        
        ;; Check if attestation exists
        (match (map-get? attestations {user: user, claim-id: claim-id})
            existing-attestation
            ;; Add signature to existing attestation
            (let
                (
                    (current-sigs (get validator-signatures existing-attestation))
                    (new-sig-count (+ (get signature-count existing-attestation) u1))
                )
                (ok (map-set attestations {user: user, claim-id: claim-id}
                    (merge existing-attestation {
                        validator-signatures: (unwrap-panic (as-max-len? (append current-sigs caller) u10)),
                        signature-count: new-sig-count,
                        verified: (>= new-sig-count (var-get min-validators))
                    })
                ))
            )
            ;; Create new attestation
            (ok (map-set attestations {user: user, claim-id: claim-id} {
                validator-signatures: (list caller),
                signature-count: u1,
                claim-type: claim-type,
                created-at: block-height,
                verified: false
            }))
        )
    )
)

;; Create relationship attestation
(define-public (attest-relationship 
    (from principal) 
    (to principal) 
    (relationship-hash (buff 32))
)
    (let
        (
            (caller tx-sender)
        )
        (asserts! (is-some (map-get? identities from)) err-not-found)
        (asserts! (is-some (map-get? identities to)) err-not-found)
        (asserts! (or (is-eq caller from) (is-validator caller)) err-unauthorized)
        
        (match (map-get? relationships {from: from, to: to})
            existing-rel
            (ok (map-set relationships {from: from, to: to}
                (merge existing-rel {
                    attestation-count: (+ (get attestation-count existing-rel) u1)
                })
            ))
            (ok (map-set relationships {from: from, to: to} {
                relationship-hash: relationship-hash,
                attestation-count: u1,
                created-at: block-height
            }))
        )
    )
)

;; Submit attribute proof with selective disclosure
(define-public (submit-attribute-proof
    (attribute-type (string-ascii 64))
    (proof-hash (buff 32))
    (expiry uint)
)
    (let
        (
            (caller tx-sender)
        )
        (asserts! (is-some (map-get? identities caller)) err-not-found)
        (ok (map-set attribute-proofs {user: caller, attribute-type: attribute-type} {
            proof-hash: proof-hash,
            revealed: false,
            verified: false,
            expiry: expiry
        }))
    )
)

;; Verify attribute proof (validator only)
(define-public (verify-attribute-proof
    (user principal)
    (attribute-type (string-ascii 64))
)
    (let
        (
            (caller tx-sender)
            (proof (unwrap! (map-get? attribute-proofs {user: user, attribute-type: attribute-type}) err-not-found))
        )
        (asserts! (is-validator caller) err-unauthorized)
        (ok (map-set attribute-proofs {user: user, attribute-type: attribute-type}
            (merge proof {verified: true})
        ))
    )
)

;; Link cross-chain identity
(define-public (link-cross-chain-identity
    (external-chain (string-ascii 32))
    (external-address (string-ascii 128))
    (proof-hash (buff 32))
)
    (let
        (
            (caller tx-sender)
        )
        (asserts! (is-some (map-get? identities caller)) err-not-found)
        (ok (map-set cross-chain-links caller {
            external-chain: external-chain,
            external-address: external-address,
            proof-hash: proof-hash,
            verified: false
        }))
    )
)

;; Verify cross-chain link (validator only)
(define-public (verify-cross-chain-link (user principal))
    (let
        (
            (caller tx-sender)
            (link (unwrap! (map-get? cross-chain-links user) err-not-found))
        )
        (asserts! (is-validator caller) err-unauthorized)
        (ok (map-set cross-chain-links user
            (merge link {verified: true})
        ))
    )
)

;; Appoint recovery guardian
(define-public (appoint-guardian (guardian principal))
    (let
        (
            (caller tx-sender)
        )
        (asserts! (is-some (map-get? identities caller)) err-not-found)
        (ok (map-set recovery-guardians {owner: caller, guardian: guardian} {
            active: true,
            appointed-at: block-height
        }))
    )
)

;; Initiate identity recovery
(define-public (initiate-recovery
    (owner principal)
    (new-merkle-root (buff 32))
    (threshold uint)
)
    (let
        (
            (caller tx-sender)
            (guardian-data (unwrap! (map-get? recovery-guardians {owner: owner, guardian: caller}) err-unauthorized))
        )
        (asserts! (get active guardian-data) err-unauthorized)
        (asserts! (is-none (map-get? recovery-requests owner)) err-already-exists)
        
        (ok (map-set recovery-requests owner {
            new-merkle-root: new-merkle-root,
            approvals: (list caller),
            approval-count: u1,
            threshold: threshold,
            expires-at: (+ block-height u1440), ;; ~10 days
            executed: false
        }))
    )
)

;; Approve recovery request
(define-public (approve-recovery (owner principal))
    (let
        (
            (caller tx-sender)
            (guardian-data (unwrap! (map-get? recovery-guardians {owner: owner, guardian: caller}) err-unauthorized))
            (request (unwrap! (map-get? recovery-requests owner) err-not-found))
        )
        (asserts! (get active guardian-data) err-unauthorized)
        (asserts! (not (get executed request)) err-unauthorized)
        (asserts! (< block-height (get expires-at request)) err-unauthorized)
        
        (let
            (
                (new-approvals (unwrap-panic (as-max-len? (append (get approvals request) caller) u10)))
                (new-count (+ (get approval-count request) u1))
            )
            (ok (map-set recovery-requests owner
                (merge request {
                    approvals: new-approvals,
                    approval-count: new-count
                })
            ))
        )
    )
)

;; Execute recovery (once threshold met)
(define-public (execute-recovery (owner principal))
    (let
        (
            (request (unwrap! (map-get? recovery-requests owner) err-not-found))
            (identity (unwrap! (map-get? identities owner) err-not-found))
        )
        (asserts! (>= (get approval-count request) (get threshold request)) err-insufficient-attestations)
        (asserts! (not (get executed request)) err-unauthorized)
        (asserts! (< block-height (get expires-at request)) err-unauthorized)
        
        ;; Update identity with new merkle root
        (map-set identities owner
            (merge identity {
                merkle-root: (get new-merkle-root request),
                last-updated: block-height
            })
        )
        
        ;; Mark recovery as executed
        (ok (map-set recovery-requests owner
            (merge request {executed: true})
        ))
    )
)

;; Update reputation score (validator only)
(define-public (update-reputation (user principal) (score-delta int))
    (let
        (
            (caller tx-sender)
            (identity (unwrap! (map-get? identities user) err-not-found))
            (current-score (get reputation-score identity))
            (new-score (if (>= score-delta 0)
                (+ current-score (to-uint score-delta))
                (if (>= current-score (to-uint (* score-delta -1)))
                    (- current-score (to-uint (* score-delta -1)))
                    u0
                )
            ))
        )
        (asserts! (is-validator caller) err-unauthorized)
        (ok (map-set identities user
            (merge identity {reputation-score: new-score})
        ))
    )
)

;; Admin functions

(define-public (set-min-validators (new-min uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> new-min u0) err-invalid-threshold)
        (ok (var-set min-validators new-min))
    )
)

(define-public (deactivate-validator (validator principal))
    (let
        (
            (validator-data (unwrap! (map-get? validators validator) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set validators validator
            (merge validator-data {active: false})
        ))
    )
)

;; Initialize contract
(begin
    (map-set validators contract-owner {
        active: true,
        attestation-count: u0,
        registered-at: block-height
    })
)
