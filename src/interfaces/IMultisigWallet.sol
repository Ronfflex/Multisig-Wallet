// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IMultisigWallet Interface
/// @notice Interface for the MultisigWallet contract
/// @dev Defines the core functionality for a multisig wallet with multiple signers
interface IMultisigWallet {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Structure to store transaction information
    /// @param to Destination address for the transaction
    /// @param value Amount of ETH to be sent
    /// @param data Calldata to be executed
    /// @param executed Whether the transaction has been executed
    /// @param numConfirmations Number of confirmations received
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new transaction is submitted
    /// @param txId The ID of the submitted transaction
    /// @param to The destination address of the transaction
    /// @param value The amount of ETH to be sent
    /// @param data The calldata to be executed
    event TransactionSubmitted(uint256 indexed txId, address indexed to, uint256 value, bytes data);

    /// @notice Emitted when a transaction is confirmed by a signer
    /// @param txId The ID of the confirmed transaction
    /// @param signer The address of the confirming signer
    event TransactionConfirmed(uint256 indexed txId, address indexed signer);

    /// @notice Emitted when a transaction confirmation is revoked
    /// @param txId The ID of the transaction
    /// @param signer The address of the signer revoking confirmation
    event TransactionRevoked(uint256 indexed txId, address indexed signer);

    /// @notice Emitted when a transaction is executed
    /// @param txId The ID of the executed transaction
    event TransactionExecuted(uint256 indexed txId);

    /// @notice Emitted when a new signer is added
    /// @param signer The address of the new signer
    event SignerAdded(address indexed signer);

    /// @notice Emitted when a signer is removed
    /// @param signer The address of the removed signer
    event SignerRemoved(address indexed signer);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a transaction fails to execute
    error ExecutionFailed();

    /// @notice Thrown when trying to confirm an already executed transaction
    error AlreadyExecuted();

    /// @notice Thrown when an invalid number of confirmations is provided
    error InvalidConfirmations();

    /// @notice Thrown when an invalid number of signers is provided
    error InvalidSignersCount();

    /// @notice Thrown when the caller is not a signer
    error NotSigner();

    /// @notice Thrown when the signer is already confirmed
    error AlreadyConfirmed();

    /// @notice Thrown when the signer has not confirmed
    error NotConfirmed();

    /// @notice Thrown when the provided address is already a signer
    error AlreadySigner();

    /// @notice Thrown when the provided address is not a signer
    error NotASigner();

    /// @notice Thrown when an operation would result in too few signers
    error TooFewSigners();

    /// @notice Thrown when an invalid address is provided
    error InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Submit a new transaction for confirmation
    /// @param to The destination address
    /// @param value The amount of ETH to send
    /// @param data The calldata to execute
    /// @return txId The ID of the newly created transaction
    function submitTransaction(
        address to,
        uint256 value,
        bytes calldata data
    )
        external
        returns (uint256 txId);

    /// @notice Confirm a pending transaction
    /// @param txId The ID of the transaction to confirm
    function confirmTransaction(uint256 txId) external;

    /// @notice Revoke a confirmation for a transaction
    /// @param txId The ID of the transaction
    function revokeConfirmation(uint256 txId) external;

    /// @notice Execute a confirmed transaction
    /// @param txId The ID of the transaction to execute
    function executeTransaction(uint256 txId) external;

    /// @notice Add a new signer to the wallet
    /// @param newSigner The address of the new signer
    function addSigner(address newSigner) external;

    /// @notice Remove an existing signer from the wallet
    /// @param signer The address of the signer to remove
    function removeSigner(address signer) external;

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the number of confirmations required for execution
    /// @return The required number of confirmations
    function requiredConfirmations() external view returns (uint256);

    /// @notice Get the current number of signers
    /// @return The number of signers
    function getSignerCount() external view returns (uint256);

    /// @notice Check if an address is a signer
    /// @param account The address to check
    /// @return True if the address is a signer
    function isSigner(address account) external view returns (bool);

    /// @notice Get the number of confirmations for a transaction
    /// @param txId The ID of the transaction
    /// @return The number of confirmations
    function getConfirmationCount(uint256 txId) external view returns (uint256);

    /// @notice Check if a transaction has been confirmed by a specific signer
    /// @param txId The ID of the transaction
    /// @param signer The address of the signer
    /// @return True if the transaction is confirmed by the signer
    function isConfirmed(uint256 txId, address signer) external view returns (bool);
}
