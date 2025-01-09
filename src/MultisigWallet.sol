// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IMultisigWallet.sol";

/// @title MultisigWallet
/// @notice Implementation of a multisignature wallet with configurable signers
/// @dev Requires minimum 3 signers and 2 confirmations for execution
contract MultisigWallet is IMultisigWallet {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum number of signers required
    uint256 private constant MIN_SIGNERS = 3;

    /// @notice Required number of confirmations for execution
    uint256 public immutable requiredConfirmations;

    /// @notice Mapping of addresses to signer status
    mapping(address => bool) private _isSigners;

    /// @notice Array to keep track of all signers
    address[] private _signers;

    /// @notice Array to store all transactions
    Transaction[] private _transactions;

    /// @notice Mapping of transaction ID to signer address to confirmation status
    mapping(uint256 => mapping(address => bool)) private _confirmations;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures the caller is a signer
    modifier onlySigner() {
        if (!_isSigners[msg.sender]) revert NotSigner();
        _;
    }

    /// @notice Ensures a transaction exists
    /// @param _txId The ID of the transaction
    modifier txExists(uint256 _txId) {
        if (_txId >= _transactions.length) revert InvalidConfirmations();
        _;
    }

    /// @notice Ensures a transaction hasn't been executed
    /// @param _txId The ID of the transaction
    modifier notExecuted(uint256 _txId) {
        if (_transactions[_txId].executed) revert AlreadyExecuted();
        _;
    }

    /// @notice Ensures the transaction hasn't been confirmed by the signer
    /// @param _txId The ID of the transaction
    modifier notConfirmed(uint256 _txId) {
        if (_confirmations[_txId][msg.sender]) revert AlreadyConfirmed();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy the multisig wallet with initial signers
    /// @param _initialSigners Array of initial signer addresses
    /// @param _requiredConfirmations Number of required confirmations
    constructor(address[] memory _initialSigners, uint256 _requiredConfirmations) {
        uint256 signersLength = _initialSigners.length;

        // Validate inputs
        if (signersLength < MIN_SIGNERS) revert TooFewSigners();
        if (_requiredConfirmations < 2 || _requiredConfirmations > signersLength) {
            revert InvalidConfirmations();
        }

        // Set required confirmations
        requiredConfirmations = _requiredConfirmations;

        // Add initial signers
        for (uint256 i; i < signersLength;) {
            address signer = _initialSigners[i];

            if (signer == address(0)) revert InvalidAddress();
            if (_isSigners[signer]) revert AlreadySigner();

            _isSigners[signer] = true;
            _signers.push(signer);

            emit SignerAdded(signer);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSACTION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultisigWallet
    function submitTransaction(
        address to,
        uint256 value,
        bytes calldata data
    )
        external
        onlySigner
        returns (uint256 txId)
    {
        if (to == address(0)) revert InvalidAddress();

        // Add new transaction
        txId = _transactions.length;
        _transactions.push(
            Transaction({ to: to, value: value, data: data, executed: false, numConfirmations: 0 })
        );

        emit TransactionSubmitted(txId, to, value, data);
    }

    /// @inheritdoc IMultisigWallet
    function confirmTransaction(uint256 txId)
        external
        onlySigner
        txExists(txId)
        notExecuted(txId)
        notConfirmed(txId)
    {
        Transaction storage transaction = _transactions[txId];
        _confirmations[txId][msg.sender] = true;
        transaction.numConfirmations += 1;

        emit TransactionConfirmed(txId, msg.sender);
    }

    /// @inheritdoc IMultisigWallet
    function revokeConfirmation(uint256 txId)
        external
        onlySigner
        txExists(txId)
        notExecuted(txId)
    {
        if (!_confirmations[txId][msg.sender]) revert NotConfirmed();

        Transaction storage transaction = _transactions[txId];
        _confirmations[txId][msg.sender] = false;
        transaction.numConfirmations -= 1;

        emit TransactionRevoked(txId, msg.sender);
    }

    /// @inheritdoc IMultisigWallet
    function executeTransaction(uint256 txId)
        external
        onlySigner
        txExists(txId)
        notExecuted(txId)
    {
        Transaction storage transaction = _transactions[txId];

        if (transaction.numConfirmations < requiredConfirmations) {
            revert InvalidConfirmations();
        }

        transaction.executed = true;

        (bool success,) = transaction.to.call{ value: transaction.value }(transaction.data);
        if (!success) revert ExecutionFailed();

        emit TransactionExecuted(txId);
    }

    /*//////////////////////////////////////////////////////////////
                         SIGNER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultisigWallet
    function addSigner(address newSigner) external onlySigner {
        if (newSigner == address(0)) revert InvalidAddress();
        if (_isSigners[newSigner]) revert AlreadySigner();

        _isSigners[newSigner] = true;
        _signers.push(newSigner);

        emit SignerAdded(newSigner);
    }

    /// @inheritdoc IMultisigWallet
    function removeSigner(address signer) external onlySigner {
        if (!_isSigners[signer]) revert NotASigner();
        if (_signers.length <= MIN_SIGNERS) revert TooFewSigners();
        if ((_signers.length - 1) < requiredConfirmations) revert InvalidConfirmations();

        _isSigners[signer] = false;

        // Remove signer from array
        for (uint256 i; i < _signers.length;) {
            if (_signers[i] == signer) {
                _signers[i] = _signers[_signers.length - 1];
                _signers.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        emit SignerRemoved(signer);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultisigWallet
    function getSignerCount() external view returns (uint256) {
        return _signers.length;
    }

    /// @inheritdoc IMultisigWallet
    function isSigner(address account) external view returns (bool) {
        return _isSigners[account];
    }

    /// @inheritdoc IMultisigWallet
    function getConfirmationCount(uint256 txId) external view txExists(txId) returns (uint256) {
        return _transactions[txId].numConfirmations;
    }

    /// @inheritdoc IMultisigWallet
    function isConfirmed(
        uint256 txId,
        address signer
    )
        external
        view
        txExists(txId)
        returns (bool)
    {
        return _confirmations[txId][signer];
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the contract to receive ETH
    receive() external payable { }
}
