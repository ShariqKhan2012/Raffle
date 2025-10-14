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
        createSubscription(vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint256, address) {
        vm.startBroadcast();
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
            3 ether
        );
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken,
        uint256 amount
    ) public {
        console2.log("Inside fundSubscription 1", subscriptionId);
        if (block.chainid == ANVIL_CHAINID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                amount
            );
            vm.stopBroadcast();
        } else {
            console2.log("Inside fundSubscription 2", subscriptionId);
            vm.startBroadcast();
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
        address mostRecentlyDeployedRaffle = DevOpsTools
            .get_most_recent_deployment("Raffle", block.chainid);

        addConsumer(vrfCoordinator, subscriptionId, mostRecentlyDeployedRaffle);
    }

    function addConsumer(
        address vrfCoordinator,
        uint256 subscriptionId,
        address consumerContractToAdd
    ) public {
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            consumerContractToAdd
        );
        vm.stopBroadcast();
    }
}
