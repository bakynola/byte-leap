# ByteLeap

ByteLeap is a revolutionary zero-knowledge identity verification system that enables users to build verifiable social graphs and reputation networks without exposing personal data. The platform leverages selective disclosure proofs and relationship attestations to create trustless verification mechanisms where users can prove specific attributes about themselves or their connections while keeping underlying information completely private.

## Overview

ByteLeap is a Stacks Clarity smart contract implementing a decentralized zero-knowledge identity verification system with verifiable attestations, relationship mapping, and cross-chain portability.

## Features

### 1. Identity Management
- **Merkle Root Storage**: Each identity stores a merkle root representing verified attributes
- **Selective Disclosure**: Users can prove specific attributes without revealing all data
- **Reputation System**: Integrated reputation scoring mechanism
- **Active Status**: Identities can be activated/deactivated

### 2. Validator Network
- **Trusted Validators**: Registered entities authorized to attest to identity claims
- **Multi-Signature Attestations**: Require multiple validators for verification
- **Threshold Signatures**: Configurable minimum number of validators needed
- **Validator Management**: Admin controls for activating/deactivating validators

### 3. Attestation System
- **Claim Attestations**: Validators can attest to specific identity claims
- **Multi-Validator Support**: Up to 10 validator signatures per claim
- **Claim Types**: Flexible claim categorization (age, credentials, etc.)
- **Auto-Verification**: Claims automatically verified when threshold is met

### 4. Relationship Mapping
- **Encrypted Relationships**: Store relationship hashes without exposing details
- **Attestation Tracking**: Count attestations for each relationship
- **Bidirectional Support**: Map relationships between any two identities

### 5. Attribute Proofs
- **Selective Disclosure Proofs**: Submit proofs for specific attributes
- **Validator Verification**: Validators can verify submitted proofs
- **Expiry Management**: Proofs include expiration timestamps
- **Proof Types**: Support for various attribute types (age-range, credentials, etc.)

### 6. Cross-Chain Identity
- **Multi-Chain Linking**: Link identities across different blockchains
- **Proof Verification**: Validators verify cross-chain proof authenticity
- **Portable Identity**: Unified identity across blockchain networks

### 7. Social Recovery
- **Guardian Appointments**: Users appoint trusted guardians
- **Recovery Requests**: Guardians can initiate identity recovery
- **Multi-Guardian Approval**: Threshold-based approval mechanism
- **Time-Limited Requests**: Recovery requests expire after ~10 days

## Core Functions

### Identity Functions

#### `register-identity`
```clarity
(register-identity (merkle-root (buff 32)))
```
Register a new identity with an initial merkle root.

#### `update-identity`
```clarity
(update-identity (new-merkle-root (buff 32)))
```
Update the merkle root when adding new verified attributes.

#### `get-identity`
```clarity
(get-identity (user principal))
```
Retrieve identity information for a user.

### Validator Functions

#### `register-validator`
```clarity
(register-validator (validator principal))
```
Register a new validator (owner only).

#### `is-validator`
```clarity
(is-validator (validator principal))
```
Check if a principal is an active validator.

### Attestation Functions

#### `create-attestation`
```clarity
(create-attestation (user principal) (claim-id (buff 32)) (claim-type (string-ascii 64)))
```
Create or add to an attestation for a user's claim.

#### `get-attestation`
```clarity
(get-attestation (user principal) (claim-id (buff 32)))
```
Retrieve attestation details.

### Attribute Proof Functions

#### `submit-attribute-proof`
```clarity
(submit-attribute-proof (attribute-type (string-ascii 64)) (proof-hash (buff 32)) (expiry uint))
```
Submit a selective disclosure proof for an attribute.

#### `verify-attribute-proof`
```clarity
(verify-attribute-proof (user principal) (attribute-type (string-ascii 64)))
```
Verify an attribute proof (validator only).

### Relationship Functions

#### `attest-relationship`
```clarity
(attest-relationship (from principal) (to principal) (relationship-hash (buff 32)))
```
Create an attestation for a relationship between two users.

### Cross-Chain Functions

#### `link-cross-chain-identity`
```clarity
(link-cross-chain-identity (external-chain (string-ascii 32)) (external-address (string-ascii 128)) (proof-hash (buff 32)))
```
Link this identity to an identity on another blockchain.

#### `verify-cross-chain-link`
```clarity
(verify-cross-chain-link (user principal))
```
Verify a cross-chain identity link (validator only).

### Recovery Functions

#### `appoint-guardian`
```clarity
(appoint-guardian (guardian principal))
```
Appoint a recovery guardian.

#### `initiate-recovery`
```clarity
(initiate-recovery (owner principal) (new-merkle-root (buff 32)) (threshold uint))
```
Initiate an identity recovery request (guardian only).

#### `approve-recovery`
```clarity
(approve-recovery (owner principal))
```
Approve a recovery request as a guardian.

#### `execute-recovery`
```clarity
(execute-recovery (owner principal))
```
Execute recovery once threshold is met.

### Reputation Functions

#### `update-reputation`
```clarity
(update-reputation (user principal) (score-delta int))
```
Update a user's reputation score (validator only).

## Data Structures

### Identity
```clarity
{
    merkle-root: (buff 32),          // Merkle root of verified attributes
    created-at: uint,                 // Block height of creation
    last-updated: uint,               // Last update block height
    reputation-score: uint,           // Current reputation score
    active: bool                      // Identity active status
}
```

### Attestation
```clarity
{
    validator-signatures: (list 10 principal),  // List of validator signatures
    signature-count: uint,                       // Number of signatures
    claim-type: (string-ascii 64),              // Type of claim
    created-at: uint,                            // Creation block height
    verified: bool                               // Verification status
}
```

### Attribute Proof
```clarity
{
    proof-hash: (buff 32),           // Hash of the proof
    revealed: bool,                   // Whether attribute is revealed
    verified: bool,                   // Validator verification status
    expiry: uint                      // Expiration block height
}
```

## Error Codes

- `u100`: `err-owner-only` - Action restricted to contract owner
- `u101`: `err-not-found` - Requested entity not found
- `u102`: `err-unauthorized` - Caller not authorized
- `u103`: `err-already-exists` - Entity already exists
- `u104`: `err-invalid-threshold` - Invalid threshold value
- `u105`: `err-insufficient-attestations` - Not enough attestations
- `u106`: `err-invalid-proof` - Invalid proof provided

## Usage Examples

### 1. Register a New Identity
```clarity
(contract-call? .byteleap register-identity 0x1234...)
```

### 2. Validator Creates an Attestation
```clarity
(contract-call? .byteleap create-attestation 
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
    0xabcd...
    "age-over-18")
```

### 3. Submit an Age Range Proof
```clarity
(contract-call? .byteleap submit-attribute-proof
    "age-range"
    0xbeef...
    u1000000)
```

### 4. Link Cross-Chain Identity
```clarity
(contract-call? .byteleap link-cross-chain-identity
    "ethereum"
    "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
    0xcafe...)
```

### 5. Social Recovery Flow
```clarity
;; 1. Appoint guardians
(contract-call? .byteleap appoint-guardian 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)

;; 2. Guardian initiates recovery
(contract-call? .byteleap initiate-recovery
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
    0xnewroot...
    u3)

;; 3. Other guardians approve
(contract-call? .byteleap approve-recovery 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; 4. Execute recovery once threshold is met
(contract-call? .byteleap execute-recovery 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## Security Considerations

1. **Validator Trust**: The system's security relies on trusted validators. Ensure validators are carefully vetted.

2. **Merkle Root Updates**: Only identity owners can update their merkle roots, preventing unauthorized modifications.

3. **Recovery Mechanism**: Recovery requests have time limits (144 blocks) and require multiple guardian approvals.

4. **Threshold Signatures**: Minimum validator requirement prevents single-validator manipulation.

5. **Cross-Chain Verification**: Cross-chain links require validator verification before being trusted.

## Deployment

1. Deploy the contract to Stacks blockchain
2. Contract owner is automatically registered as first validator
3. Register additional validators using `register-validator`
4. Configure minimum validator threshold using `set-min-validators`

## Testing Recommendations

1. Test identity registration and updates
2. Verify multi-validator attestation flow
3. Test relationship attestations
4. Validate attribute proof submission and verification
5. Test cross-chain linking process
6. Verify social recovery mechanism with various guardian configurations
7. Test reputation score updates with positive and negative deltas
