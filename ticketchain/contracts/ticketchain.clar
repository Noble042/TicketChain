;; TicketChain - Decentralized Event Ticketing System with Refund Insurance
;; Description: Smart contract for minting and managing NFT event tickets with transfer restrictions and refund insurance

;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-EVENT-NOT-FOUND (err u101))
(define-constant ERR-SOLD-OUT (err u102))
(define-constant ERR-TRANSFER-RESTRICTED (err u103))
(define-constant ERR-EVENT-ACTIVE (err u104))
(define-constant ERR-INVALID-REFUND (err u105))
(define-constant ERR-INSURANCE-CLAIMED (err u106))
(define-constant INSURANCE-PREMIUM-PERCENTAGE u5) ;; 5% of ticket price
(define-constant INSURANCE-POOL-ADDRESS 'SP000000000000000000002Q6VF78) ;; Example pool address

;; Data Variables
(define-data-var next-event-id uint u1)
(define-data-var next-ticket-id uint u1)
(define-data-var insurance-pool uint u0)

;; Data Maps
(define-map Events
    uint  ;; event-id
    {
        name: (string-ascii 100),
        organizer: principal,
        total-tickets: uint,
        tickets-sold: uint,
        price: uint,
        date: uint,
        is-canceled: bool,
        metadata-uri: (string-ascii 256)
    }
)

(define-map Tickets
    uint  ;; ticket-id
    {
        event-id: uint,
        owner: principal,
        is-used: bool,
        transferred: bool,
        purchase-price: uint,
        has-insurance: bool,
        insurance-claimed: bool,
        metadata-uri: (string-ascii 256)
    }
)

(define-map EventTickets
    uint  ;; event-id
    (list 500 uint)  ;; list of ticket IDs
)

;; Private Functions
(define-private (is-event-organizer (event-id uint) (caller principal))
    (let ((event (unwrap! (map-get? Events event-id) false)))
        (is-eq (get organizer event) caller)
    )
)

(define-private (calculate-insurance-premium (ticket-price uint))
    (/ (* ticket-price INSURANCE-PREMIUM-PERCENTAGE) u100)
)

(define-private (handle-insurance-purchase (insurance-premium uint) (organizer principal))
    (if (> insurance-premium u0)
        (begin
            (try! (stx-transfer? insurance-premium organizer INSURANCE-POOL-ADDRESS))
            (var-set insurance-pool (+ (var-get insurance-pool) insurance-premium))
            (ok true)
        )
        (ok true)
    )
)

;; Public Functions

;; Create a new event
(define-public (create-event (name (string-ascii 100)) 
                           (total-tickets uint) 
                           (price uint)
                           (date uint)
                           (metadata-uri (string-ascii 256)))
    (let ((event-id (var-get next-event-id)))
        (map-set Events
            event-id
            {
                name: name,
                organizer: tx-sender,
                total-tickets: total-tickets,
                tickets-sold: u0,
                price: price,
                date: date,
                is-canceled: false,
                metadata-uri: metadata-uri
            }
        )
        (var-set next-event-id (+ event-id u1))
        (ok event-id)
    )
)

;; Purchase a ticket with optional insurance
(define-public (purchase-ticket (event-id uint) (with-insurance bool))
    (let (
        (event (unwrap! (map-get? Events event-id) ERR-EVENT-NOT-FOUND))
        (ticket-id (var-get next-ticket-id))
        (insurance-premium (if with-insurance 
                             (calculate-insurance-premium (get price event))
                             u0))
        (total-cost (+ (get price event) insurance-premium))
    )
        (asserts! (< (get tickets-sold event) (get total-tickets event)) ERR-SOLD-OUT)
        (asserts! (not (get is-canceled event)) ERR-EVENT-ACTIVE)
        
        ;; Process payment
        (try! (stx-transfer? total-cost tx-sender (get organizer event)))
        
        ;; Handle insurance purchase
        (try! (handle-insurance-purchase insurance-premium (get organizer event)))
        
        ;; Mint ticket
        (map-set Tickets
            ticket-id
            {
                event-id: event-id,
                owner: tx-sender,
                is-used: false,
                transferred: false,
                purchase-price: (get price event),
                has-insurance: with-insurance,
                insurance-claimed: false,
                metadata-uri: (get metadata-uri event)
            }
        )
        
        ;; Update event records
        (map-set Events
            event-id
            (merge event { tickets-sold: (+ (get tickets-sold event) u1) })
        )
        
        ;; Add ticket to event's ticket list
        (match (map-get? EventTickets event-id)
            tickets (map-set EventTickets 
                        event-id 
                        (unwrap! (as-max-len? (append tickets ticket-id) u500) ERR-SOLD-OUT))
            (map-set EventTickets event-id (list ticket-id))
        )
        
        (var-set next-ticket-id (+ ticket-id u1))
        (ok ticket-id)
    )
)

;; Transfer ticket
(define-public (transfer-ticket (ticket-id uint) (recipient principal))
    (let ((ticket (unwrap! (map-get? Tickets ticket-id) ERR-EVENT-NOT-FOUND)))
        (asserts! (is-eq (get owner ticket) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (get transferred ticket)) ERR-TRANSFER-RESTRICTED)
        
        (map-set Tickets
            ticket-id
            (merge ticket {
                owner: recipient,
                transferred: true
            })
        )
        (ok true)
    )
)

;; Cancel event and enable refunds
(define-public (cancel-event (event-id uint))
    (let ((event (unwrap! (map-get? Events event-id) ERR-EVENT-NOT-FOUND)))
        (asserts! (is-event-organizer event-id tx-sender) ERR-NOT-AUTHORIZED)
        
        (map-set Events
            event-id
            (merge event { is-canceled: true })
        )
        (ok true)
    )
)

;; Claim refund for canceled event
(define-public (claim-refund (ticket-id uint))
    (let (
        (ticket (unwrap! (map-get? Tickets ticket-id) ERR-EVENT-NOT-FOUND))
        (event (unwrap! (map-get? Events (get event-id ticket)) ERR-EVENT-NOT-FOUND))
    )
        (asserts! (is-eq (get owner ticket) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (get is-canceled event) ERR-INVALID-REFUND)
        
        ;; Process refund
        (try! (stx-transfer? (get purchase-price ticket) 
                           (get organizer event) 
                           tx-sender))
        
        ;; Mark ticket as used
        (map-set Tickets
            ticket-id
            (merge ticket { is-used: true })
        )
        (ok true)
    )
)

;; Claim insurance refund (can be used even if event is not canceled)
(define-public (claim-insurance-refund (ticket-id uint))
    (let (
        (ticket (unwrap! (map-get? Tickets ticket-id) ERR-EVENT-NOT-FOUND))
    )
        (asserts! (is-eq (get owner ticket) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (get has-insurance ticket) ERR-INVALID-REFUND)
        (asserts! (not (get insurance-claimed ticket)) ERR-INSURANCE-CLAIMED)
        
        ;; Process insurance refund
        (try! (stx-transfer? (get purchase-price ticket) 
                           INSURANCE-POOL-ADDRESS 
                           tx-sender))
        
        ;; Mark insurance as claimed
        (map-set Tickets
            ticket-id
            (merge ticket { 
                insurance-claimed: true,
                is-used: true 
            })
        )
        (ok true)
    )
)

;; Validate ticket
(define-public (validate-ticket (ticket-id uint))
    (let ((ticket (unwrap! (map-get? Tickets ticket-id) ERR-EVENT-NOT-FOUND)))
        (asserts! (is-event-organizer (get event-id ticket) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-used ticket)) ERR-INVALID-REFUND)
        
        (map-set Tickets
            ticket-id
            (merge ticket { is-used: true })
        )
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-event (event-id uint))
    (map-get? Events event-id)
)

(define-read-only (get-ticket (ticket-id uint))
    (map-get? Tickets ticket-id)
)

(define-read-only (get-event-tickets (event-id uint))
    (map-get? EventTickets event-id)
)

(define-read-only (get-insurance-premium (ticket-price uint))
    (calculate-insurance-premium ticket-price)
)

(define-read-only (get-insurance-pool-balance)
    (var-get insurance-pool)
)