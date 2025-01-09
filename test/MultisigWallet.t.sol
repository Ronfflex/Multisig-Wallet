//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { MultisigWallet } from "../src/MultisigWallet.sol";
import { IMultisigWallet } from "../src/interfaces/IMultisigWallet.sol";
import { RevertingContract } from "./helpers/RevertingContract.sol";

contract MultisigWalletTest is Test {
    // Events from the contract for testing
    event TransactionSubmitted(uint256 indexed txId, address indexed to, uint256 value, bytes data);
    event TransactionConfirmed(uint256 indexed txId, address indexed signer);
    event TransactionRevoked(uint256 indexed txId, address indexed signer);
    event TransactionExecuted(uint256 indexed txId);
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);

    // Custom errors from the interface
    error ExecutionFailed();
    error AlreadyExecuted();
    error InvalidConfirmations();
    error InvalidSignersCount();
    error NotSigner();
    error AlreadyConfirmed();
    error NotConfirmed();
    error AlreadySigner();
    error NotASigner();
    error TooFewSigners();
    error InvalidAddress();

    // Test addresses
    address[] internal signers;
    address internal constant RECEIVER = address(0x123);
    uint256 internal constant REQUIRED_CONFIRMATIONS = 2;

    // Contract instance
    MultisigWallet internal wallet;

    function setUp() public {
        // Create signers
        signers = new address[](3);
        signers[0] = makeAddr("signer1");
        signers[1] = makeAddr("signer2");
        signers[2] = makeAddr("signer3");

        // Deploy wallet
        wallet = new MultisigWallet(signers, REQUIRED_CONFIRMATIONS);

        // Fund wallet
        vm.deal(address(wallet), 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ModifierOnlySigner() public {
        vm.prank(address(0x999));
        vm.expectRevert(NotSigner.selector);
        wallet.submitTransaction(RECEIVER, 1 ether, "");
    }

    function test_ModifierTxExists() public {
        vm.prank(signers[0]);
        vm.expectRevert(InvalidConfirmations.selector);
        wallet.confirmTransaction(999); // Non-existent transaction ID
    }

    function test_ModifierNotExecuted() public {
        // Submit and execute a transaction first
        vm.startPrank(signers[0]);
        uint256 txId = wallet.submitTransaction(RECEIVER, 1 ether, "");
        wallet.confirmTransaction(txId);
        vm.stopPrank();

        vm.prank(signers[1]);
        wallet.confirmTransaction(txId);

        vm.prank(signers[0]);
        wallet.executeTransaction(txId);

        // Try to confirm an executed transaction
        vm.prank(signers[2]);
        vm.expectRevert(AlreadyExecuted.selector);
        wallet.confirmTransaction(txId);
    }

    function test_ModifierNotConfirmed() public {
        vm.prank(signers[0]);
        uint256 txId = wallet.submitTransaction(RECEIVER, 1 ether, "");

        vm.startPrank(signers[1]);
        wallet.confirmTransaction(txId);
        vm.expectRevert(AlreadyConfirmed.selector);
        wallet.confirmTransaction(txId);
        vm.stopPrank();
    }

    function test_AddSignerZeroAddress() public {
        vm.prank(signers[0]);
        vm.expectRevert(InvalidAddress.selector);
        wallet.addSigner(address(0));
    }

    function test_AddExistingSigner() public {
        vm.prank(signers[0]);
        vm.expectRevert(AlreadySigner.selector);
        wallet.addSigner(signers[1]);
    }

    function test_RemoveNonExistentSigner() public {
        vm.prank(signers[0]);
        vm.expectRevert(NotASigner.selector);
        wallet.removeSigner(address(0x999));
    }

    // function test_RemoveSignerInvalidConfirmations() public {
    //     // Add a new signer first
    //     address newSigner = makeAddr("newSigner");
    //     vm.prank(signers[0]);
    //     wallet.addSigner(newSigner);

    //     // Try to remove too many signers
    //     vm.startPrank(signers[0]);
    //     wallet.removeSigner(newSigner); // This should work
    //     vm.expectRevert(InvalidConfirmations.selector);
    //     wallet.removeSigner(signers[1]); // This should fail
    //     vm.stopPrank();
    // }

    function test_AddSigner() public {
        address newSigner = makeAddr("newSigner");

        vm.prank(signers[0]);
        vm.expectEmit(true, false, false, true);
        emit SignerAdded(newSigner);

        wallet.addSigner(newSigner);

        assertTrue(wallet.isSigner(newSigner));
        assertEq(wallet.getSignerCount(), 4);
    }

    function test_RemoveSigner() public {
        // First add a new signer to allow safe removal
        address newSigner = makeAddr("newSigner");
        vm.prank(signers[0]);
        wallet.addSigner(newSigner);
        assertEq(wallet.getSignerCount(), 4);

        // Now we can safely remove a signer
        vm.prank(signers[0]);
        vm.expectEmit(true, false, false, true);
        emit SignerRemoved(signers[2]);

        wallet.removeSigner(signers[2]);

        assertFalse(wallet.isSigner(signers[2]));
        assertEq(wallet.getSignerCount(), 3);
    }

    function testFail_RemoveSignerBelowMinimum() public {
        // Remove until minimum
        vm.startPrank(signers[0]);
        wallet.removeSigner(signers[1]);
        wallet.removeSigner(signers[2]); // Should fail - would be below minimum
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public {
        assertEq(wallet.getSignerCount(), 3);
        assertEq(wallet.requiredConfirmations(), REQUIRED_CONFIRMATIONS);

        for (uint256 i = 0; i < signers.length; i++) {
            assertTrue(wallet.isSigner(signers[i]));
        }
    }

    function testFail_ConstructorTooFewSigners() public {
        address[] memory twoSigners = new address[](2);
        twoSigners[0] = signers[0];
        twoSigners[1] = signers[1];

        new MultisigWallet(twoSigners, REQUIRED_CONFIRMATIONS);
    }

    function testFail_ConstructorInvalidConfirmations() public {
        new MultisigWallet(signers, 4);
    }

    function testFail_ConstructorDuplicateSigner() public {
        address[] memory duplicateSigners = new address[](3);
        duplicateSigners[0] = signers[0];
        duplicateSigners[1] = signers[0]; // Duplicate
        duplicateSigners[2] = signers[2];

        new MultisigWallet(duplicateSigners, REQUIRED_CONFIRMATIONS);
    }

    /*//////////////////////////////////////////////////////////////
                      TRANSACTION SUBMISSION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SubmitTransaction() public {
        vm.prank(signers[0]);

        bytes memory data = "";
        vm.expectEmit(true, true, false, true);
        emit TransactionSubmitted(0, RECEIVER, 1 ether, data);

        uint256 txId = wallet.submitTransaction(RECEIVER, 1 ether, data);
        assertEq(txId, 0);
    }

    function testFail_SubmitTransactionNonSigner() public {
        vm.prank(makeAddr("non-signer"));
        wallet.submitTransaction(RECEIVER, 1 ether, "");
    }

    function testFail_SubmitTransactionZeroAddress() public {
        vm.prank(signers[0]);
        wallet.submitTransaction(address(0), 1 ether, "");
    }

    /*//////////////////////////////////////////////////////////////
                      TRANSACTION CONFIRMATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ConfirmTransaction() public {
        // Submit transaction
        vm.prank(signers[0]);
        uint256 txId = wallet.submitTransaction(RECEIVER, 1 ether, "");

        // Confirm transaction
        vm.prank(signers[1]);
        vm.expectEmit(true, true, false, true);
        emit TransactionConfirmed(txId, signers[1]);

        wallet.confirmTransaction(txId);
        assertEq(wallet.getConfirmationCount(txId), 1);
        assertTrue(wallet.isConfirmed(txId, signers[1]));
    }

    function testFail_ConfirmTransactionTwice() public {
        vm.startPrank(signers[0]);
        uint256 txId = wallet.submitTransaction(RECEIVER, 1 ether, "");
        wallet.confirmTransaction(txId);
        wallet.confirmTransaction(txId); // Should fail
        vm.stopPrank();
    }

    function testFail_ConfirmExecutedTransaction() public {
        // Submit and confirm transaction
        vm.prank(signers[0]);
        uint256 txId = wallet.submitTransaction(RECEIVER, 1 ether, "");

        vm.prank(signers[0]);
        wallet.confirmTransaction(txId);

        vm.prank(signers[1]);
        wallet.confirmTransaction(txId);

        // Execute transaction
        vm.prank(signers[0]);
        wallet.executeTransaction(txId);

        // Try to confirm executed transaction
        vm.prank(signers[2]);
        wallet.confirmTransaction(txId);
    }

    /*//////////////////////////////////////////////////////////////
                       TRANSACTION EXECUTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ExecuteTransactionFailure() public {
        // Deploy a contract that reverts on receive
        RevertingContract reverter = new RevertingContract();

        // Submit transaction to the reverting contract
        vm.prank(signers[0]);
        uint256 txId = wallet.submitTransaction(address(reverter), 1 ether, "");

        vm.prank(signers[0]);
        wallet.confirmTransaction(txId);

        vm.prank(signers[1]);
        wallet.confirmTransaction(txId);

        // Try to execute - should fail
        vm.prank(signers[0]);
        vm.expectRevert(abi.encodeWithSelector(IMultisigWallet.ExecutionFailed.selector));
        wallet.executeTransaction(txId);
    }

    function test_ExecuteTransaction() public {
        // Submit transaction
        vm.prank(signers[0]);
        uint256 txId = wallet.submitTransaction(RECEIVER, 1 ether, "");

        // Confirm by two signers
        vm.prank(signers[0]);
        wallet.confirmTransaction(txId);

        vm.prank(signers[1]);
        wallet.confirmTransaction(txId);

        // Execute transaction
        uint256 initialBalance = address(RECEIVER).balance;

        vm.prank(signers[0]);
        vm.expectEmit(true, false, false, true);
        emit TransactionExecuted(txId);

        wallet.executeTransaction(txId);

        assertEq(address(RECEIVER).balance - initialBalance, 1 ether);
    }

    function testFail_ExecuteTransactionInsufficientConfirmations() public {
        vm.startPrank(signers[0]);
        uint256 txId = wallet.submitTransaction(RECEIVER, 1 ether, "");
        wallet.confirmTransaction(txId);
        wallet.executeTransaction(txId); // Should fail - only 1 confirmation
        vm.stopPrank();
    }

    function testFail_ExecuteTransactionTwice() public {
        // Submit and confirm transaction
        vm.prank(signers[0]);
        uint256 txId = wallet.submitTransaction(RECEIVER, 1 ether, "");

        vm.prank(signers[0]);
        wallet.confirmTransaction(txId);

        vm.prank(signers[1]);
        wallet.confirmTransaction(txId);

        // Execute twice
        vm.startPrank(signers[0]);
        wallet.executeTransaction(txId);
        wallet.executeTransaction(txId); // Should fail
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            REVOCATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevokeConfirmation() public {
        // Submit and confirm transaction
        vm.prank(signers[0]);
        uint256 txId = wallet.submitTransaction(RECEIVER, 1 ether, "");

        vm.prank(signers[0]);
        wallet.confirmTransaction(txId);

        // Revoke confirmation
        vm.prank(signers[0]);
        vm.expectEmit(true, true, false, true);
        emit TransactionRevoked(txId, signers[0]);

        wallet.revokeConfirmation(txId);

        assertEq(wallet.getConfirmationCount(txId), 0);
        assertFalse(wallet.isConfirmed(txId, signers[0]));
    }

    function testFail_RevokeUnconfirmedTransaction() public {
        vm.prank(signers[0]);
        uint256 txId = wallet.submitTransaction(RECEIVER, 1 ether, "");

        vm.prank(signers[1]);
        wallet.revokeConfirmation(txId); // Should fail - not confirmed
    }

    /*//////////////////////////////////////////////////////////////
                          RECEIVE FUNCTION TEST
    //////////////////////////////////////////////////////////////*/

    function test_ReceiveEther() public {
        // Test direct ETH transfer
        vm.deal(address(this), 1 ether);
        (bool success,) = address(wallet).call{ value: 1 ether }("");
        assertTrue(success);
        assertEq(address(wallet).balance, 11 ether); // 10 from setup + 1 new
    }

    /*//////////////////////////////////////////////////////////////
                               FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SubmitTransaction(address to, uint256 value, bytes calldata data) public {
        vm.assume(to != address(0));
        vm.assume(value <= address(wallet).balance);

        vm.prank(signers[0]);
        uint256 txId = wallet.submitTransaction(to, value, data);
        assertEq(txId, 0);
    }

    function testFuzz_AddSigner(address newSigner) public {
        vm.assume(newSigner != address(0));
        vm.assume(!wallet.isSigner(newSigner));

        vm.prank(signers[0]);
        wallet.addSigner(newSigner);

        assertTrue(wallet.isSigner(newSigner));
    }
}
