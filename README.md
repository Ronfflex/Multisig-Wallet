# Multisig Wallet

A secure and gas-optimized implementation of a multisignature wallet smart contract built with Solidity and Foundry.

## Features

- Multiple signers (minimum 3)
- Configurable confirmation threshold (minimum 2)
- Transaction submission and execution
- Signer management (add/remove)
- No external dependencies
- 100% test coverage
- Gas optimized

## Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)
- Solidity 0.8.28
- Git

## Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd multisig-wallet
```

2. Install dependencies:

```bash
forge install
```

3. Build the project:

```bash
forge build
```

## Testing

Run the test suite:

```bash
forge test
```

Run tests with coverage report:

```bash
forge coverage
```

Run tests with gas report:

```bash
forge test --gas-report
```

## Deployment

1. Set up your environment variables:

```bash
cp .env.example .env
# Edit .env with your configuration
```

2. Deploy using Foundry script:

```bash
# Local deployment
forge script script/Deploy.s.sol:DeployLocal --broadcast --verify

# Mainnet deployment
forge script script/Deploy.s.sol:DeployMainnet --rpc-url $MAINNET_RPC_URL --broadcast --verify

# Testnet deployment
forge script script/Deploy.s.sol:DeployGoerli --rpc-url $GOERLI_RPC_URL --broadcast --verify
```

## Contract Usage

### Initialization

```solidity
constructor(address[] memory _initialSigners, uint256 _requiredConfirmations)
```

- `_initialSigners`: Array of initial signer addresses (minimum 3)
- `_requiredConfirmations`: Number of required confirmations (minimum 2)

### Key Functions

1. Transaction Management:

```solidity
function submitTransaction(address to, uint256 value, bytes calldata data) external returns (uint256 txId)
function confirmTransaction(uint256 txId) external
function revokeConfirmation(uint256 txId) external
function executeTransaction(uint256 txId) external
```

2. Signer Management:

```solidity
function addSigner(address newSigner) external
function removeSigner(address signer) external
```

3. View Functions:

```solidity
function getSignerCount() external view returns (uint256)
function isSigner(address account) external view returns (bool)
function getConfirmationCount(uint256 txId) external view returns (uint256)
function isConfirmed(uint256 txId, address signer) external view returns (bool)
```

## Security Considerations

1. Input Validation:

   - Zero address checks
   - Signer count validations
   - Confirmation threshold checks

2. Access Control:

   - Only signers can submit/confirm transactions
   - Only signers can manage other signers
   - Minimum signer requirement enforced

3. Security Features:
   - Reentrancy protection
   - Check-Effects-Interactions pattern
   - Events for transparency
   - Custom errors for gas efficiency

## Gas Optimization

The contract implements several gas optimization techniques:

- Custom errors instead of revert strings
- Minimal storage operations
- Efficient data structures
- Unchecked math where safe
- Proper validation order

## Project Structure

```
├── src/
│   ├── MultisigWallet.sol       # Main contract
│   └── interfaces/
│       └── IMultisigWallet.sol  # Interface
├── test/
│   ├── MultisigWallet.t.sol     # Tests
│   └── helpers/
│       └── RevertingContract.sol # Test helper
├── script/
│   └── Deploy.s.sol             # Deployment scripts
└── foundry.toml                 # Foundry configuration
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
