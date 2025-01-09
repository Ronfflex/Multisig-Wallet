// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { MultisigWallet } from "../src/MultisigWallet.sol";

contract DeployMultisig is Script {
    // Configuration
    uint256 constant REQUIRED_CONFIRMATIONS = 2;
    uint256 constant INITIAL_SIGNERS_COUNT = 3;

    function run() public returns (MultisigWallet) {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Get signers from environment or use defaults for testing
        address[] memory signers = _getSigners();

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy MultisigWallet
        MultisigWallet wallet = new MultisigWallet(signers, REQUIRED_CONFIRMATIONS);

        vm.stopBroadcast();

        // Log deployment info
        _logDeployment(address(wallet), signers);

        return wallet;
    }

    function _getSigners() internal view returns (address[] memory) {
        address[] memory signers = new address[](INITIAL_SIGNERS_COUNT);

        // Try to get signers from environment variables
        try vm.envAddress("SIGNER1") returns (address signer1) {
            signers[0] = signer1;
        } catch {
            signers[0] = makeAddr("signer1");
        }

        try vm.envAddress("SIGNER2") returns (address signer2) {
            signers[1] = signer2;
        } catch {
            signers[1] = makeAddr("signer2");
        }

        try vm.envAddress("SIGNER3") returns (address signer3) {
            signers[2] = signer3;
        } catch {
            signers[2] = makeAddr("signer3");
        }

        return signers;
    }

    function _logDeployment(address wallet, address[] memory signers) internal view {
        console2.log("Multisig Wallet deployed at:", wallet);
        console2.log("Required confirmations:", REQUIRED_CONFIRMATIONS);
        console2.log("Initial signers:");
        for (uint256 i = 0; i < signers.length; i++) {
            console2.log("Signer", i + 1, ":", signers[i]);
        }
    }
}

// Optional: Deployment configuration for different networks
contract DeployLocal is DeployMultisig {
    function run() public override returns (MultisigWallet) {
        // Set default values for local testing
        vm.deal(msg.sender, 100 ether);
        return super.run();
    }
}

contract DeployMainnet is DeployMultisig {
    function run() public override returns (MultisigWallet) {
        // Mainnet specific configuration
        require(block.chainid == 1, "Not mainnet");
        return super.run();
    }
}

contract DeployGoerli is DeployMultisig {
    function run() public override returns (MultisigWallet) {
        // Goerli specific configuration
        require(block.chainid == 5, "Not Goerli");
        return super.run();
    }
}
