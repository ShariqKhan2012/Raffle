//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {console2} from "forge-std/Test.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract SubscriptionCreator is Script {
    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getActiveConfig().vrfCoordinator;
        address deployerAccount = helperConfig
            .getActiveConfig()
            .deployerAccount;
        createSubscription(vrfCoordinator, deployerAccount);
    }

    function createSubscription(
        address vrfCoordinator,
        address deployerAccount
    ) public returns (uint256, address) {
        vm.startBroadcast(deployerAccount);
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        return (subscriptionId, vrfCoordinator);
    }
}

contract SubscriptionFunder is Script {
    uint256 constant ANVIL_CHAINID = 31337;

    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getActiveConfig();

        fundSubscription(
            config.vrfCoordinator,
            config.subscriptionId,
            config.linkToken,
            3 ether,
            config.deployerAccount
        );
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken,
        uint256 amount,
        address deployerAccount
    ) public {
        if (block.chainid == ANVIL_CHAINID) {
            vm.startBroadcast(deployerAccount);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                amount
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerAccount);
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                amount,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }
}

contract ConsumerAdder is Script {
    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getActiveConfig();
        address vrfCoordinator = config.vrfCoordinator;
        uint256 subscriptionId = config.subscriptionId;
        address deployerAccount = config.deployerAccount;
        address mostRecentlyDeployedRaffle = DevOpsTools
            .get_most_recent_deployment("Raffle", block.chainid);

        addConsumer(
            vrfCoordinator,
            subscriptionId,
            mostRecentlyDeployedRaffle,
            deployerAccount
        );
    }

    function addConsumer(
        address vrfCoordinator,
        uint256 subscriptionId,
        address consumerContractToAdd,
        address deployerAccount
    ) public {
        vm.startBroadcast(deployerAccount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            consumerContractToAdd
        );
        vm.stopBroadcast();
    }
}
