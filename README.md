# TicketChain

A decentralized event ticketing system built on blockchain technology, featuring NFT-based tickets with transfer restrictions and optional refund insurance.

## Overview

TicketChain revolutionizes event ticketing by leveraging blockchain technology to create a secure, transparent, and user-friendly ticketing platform. The system uses NFTs (Non-Fungible Tokens) to represent event tickets, implementing transfer restrictions to combat scalping while providing flexible refund options through smart contracts.

## Features

### Core Functionality
- **NFT-Based Tickets**: Each ticket is minted as a unique NFT with associated metadata
- **Transfer Restrictions**: One-time transfer limit to prevent ticket scalping
- **Event Management**: Create and manage events with customizable parameters
- **Automated Refunds**: Smart contract-based refund processing for canceled events

### Advanced Features
- **Refund Insurance**
  - Optional insurance coverage for ticket purchases
  - 5% premium of ticket price
  - Guaranteed refund regardless of event status
  - Claims processed through smart contracts

### Security Features
- Organizer verification
- Ticket validation system
- Secure payment processing
- Transfer restrictions enforcement

## Smart Contract Architecture

### Key Components

1. **Event Management**
   - Create new events
   - Set ticket quantities and prices
   - Manage event status
   - Cancel events and process refunds

2. **Ticket Operations**
   - Mint NFT tickets
   - Process purchases
   - Handle transfers
   - Validate tickets

3. **Insurance System**
   - Premium calculations
   - Insurance pool management
   - Claim processing
   - Refund distribution

### Data Structures

- Events Map: Stores event details and status
- Tickets Map: Maintains ticket ownership and status
- EventTickets Map: Links events with their tickets
- Insurance Pool: Manages insurance premiums and payouts

## Technical Details

### Constants
- Minimum ticket price: 1000 microSTX
- Maximum tickets per event: 10,000
- Insurance premium: 5% of ticket price

### Error Codes
- `ERR-NOT-AUTHORIZED (u100)`: Unauthorized access
- `ERR-EVENT-NOT-FOUND (u101)`: Event doesn't exist
- `ERR-SOLD-OUT (u102)`: No tickets available
- `ERR-TRANSFER-RESTRICTED (u103)`: Transfer not allowed
- `ERR-EVENT-ACTIVE (u104)`: Event still active
- `ERR-INVALID-REFUND (u105)`: Invalid refund request
- `ERR-INSURANCE-CLAIMED (u106)`: Insurance already claimed
- `ERR-INVALID-PARAMS (u107)`: Invalid parameters

## Usage

### For Event Organizers

```clarity
;; Create a new event
(contract-call? .ticketchain create-event 
    "Concert Name"     ;; event name
    u1000             ;; total tickets
    u50000            ;; price per ticket
    u100000           ;; event date
    "metadata-uri"    ;; metadata URI
)

;; Cancel an event
(contract-call? .ticketchain cancel-event event-id)
```

### For Ticket Buyers

```clarity
;; Purchase ticket with insurance
(contract-call? .ticketchain purchase-ticket 
    event-id    ;; event ID
    true        ;; with insurance
)

;; Transfer ticket
(contract-call? .ticketchain transfer-ticket 
    ticket-id   ;; ticket ID
    recipient   ;; recipient principal
)

;; Claim refund for canceled event
(contract-call? .ticketchain claim-refund ticket-id)

;; Claim insurance refund
(contract-call? .ticketchain claim-insurance-refund ticket-id)
```

## Installation and Deployment

1. Clone the repository
2. Install Clarinet for local development
3. Deploy the contract to the Stacks blockchain
4. Initialize the contract with required parameters


## Contributing

We welcome contributions! Please read our contributing guidelines and submit pull requests.

## Support

For support, please open an issue in the GitHub repository or contact the development team.