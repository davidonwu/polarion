# Tokenized Governance Contract

## Overview
The **Tokenized Governance Contract** is a smart contract designed to facilitate decentralized decision-making using governance tokens. Token holders can propose and vote on changes to key parameters such as the interest rate and loan term. Proposals that receive majority support are executed automatically.

## Features
- **Governance Token:** A fungible token is used for voting and decision-making.
- **Proposal System:** Allows users to create, vote on, and execute governance proposals.
- **Voting Mechanism:** Token-based voting system where each token represents voting power.
- **Automatic Execution:** Approved proposals are executed to update governance parameters.

## Contract Components

### Traits
Defines the required traits for token functionality and governance operations.

### Token Definitions
- **`governance-token`**: A fungible token used for governance purposes.

### Constants
- **`contract-owner`**: The contract owner (set to the transaction sender).
- **`proposal-duration`**: The number of blocks a proposal remains active (`10,000` blocks).
- **Error Codes:**
  - `ERR-NOT-AUTHORIZED` (100)
  - `ERR-PROPOSAL-NOT-FOUND` (101)
  - `ERR-PROPOSAL-EXPIRED` (102)
  - `ERR-ALREADY-VOTED` (103)
  - `ERR-PROPOSAL-NOT-ENDED` (104)

### Data Variables
- **`next-proposal-id`**: Stores the ID of the next proposal.
- **`interest-rate`**: The current interest rate (default: `5.00%`).
- **`loan-term`**: The duration of loans in days (default: `30` days).

### Data Maps
- **`proposals`**: Stores governance proposals and their metadata.
- **`votes`**: Tracks votes cast by users for each proposal.

## Public Functions
### `create-proposal`
Creates a new governance proposal.
#### Parameters:
- `title`: Short description of the proposal (max 50 characters).
- `description`: Detailed proposal description (max 500 characters).
- `action`: Action type (`set-interest-rate`, `set-loan-term`).
- `value`: The proposed new value.
#### Returns:
- The new proposal ID.

### `vote`
Allows token holders to vote on an active proposal.
#### Parameters:
- `proposal-id`: The ID of the proposal.
- `vote-for`: Boolean (`true` to vote in favor, `false` to vote against).
#### Conditions:
- The proposal must be active.
- The user must not have already voted.
- Voting power is determined by the user's token balance.

### `execute-proposal`
Executes a proposal if it has passed.
#### Parameters:
- `proposal-id`: The ID of the proposal.
#### Conditions:
- The proposal must have ended.
- The proposal must not have already been executed.
- The majority must have voted in favor.
- If the proposal is to change `interest-rate` or `loan-term`, it updates the respective parameter.

### `transfer`
Transfers governance tokens between users.
#### Parameters:
- `amount`: The number of tokens to transfer.
- `sender`: The address of the sender.
- `recipient`: The address of the recipient.

## Read-Only Functions
### `get-proposal`
Retrieves proposal details by ID.
#### Parameters:
- `proposal-id`: The ID of the proposal.

### `get-current-interest-rate`
Returns the current interest rate.

### `get-current-loan-term`
Returns the current loan term.

## Security Considerations
- **Authorization Checks:** Ensures that only eligible participants can vote and execute proposals.
- **Immutable Records:** Proposal history and votes are stored on-chain.
- **Protection Against Double Voting:** Each user can vote only once per proposal.

## Conclusion
The **Tokenized Governance Contract** empowers token holders to participate in decentralized governance. By leveraging blockchain technology, it ensures transparency, fairness, and efficiency in decision-making.