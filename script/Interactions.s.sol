//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5MockLocal} from "test/mocks/VRFCoordinatorV2_5MockLocal.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {console2} from "forge-std/Test.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {Raffle} from "src/Raffle.sol";

uint256 constant ANVIL_CHAINID = 31337;

contract SubscriptionCreator is Script {
    function run() public {
        // On Anvil: find the existing deployed mock coordinator, don't deploy fresh ones.
        if (block.chainid == ANVIL_CHAINID) {
            createSubscription(DevOpsTools.get_most_recent_deployment(
                "VRFCoordinatorV2_5MockLocal", block.chainid
            ));
            return;
        }
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getActiveConfig().vrfCoordinator;
        createSubscription(vrfCoordinator);
    }

    // vm.startBroadcast() with no address uses the --account signer automatically.
    function createSubscription(
        address vrfCoordinator
    ) public returns (uint256, address) {
        if (block.chainid == ANVIL_CHAINID) {
            vm.startBroadcast();
            uint256 subscriptionId = VRFCoordinatorV2_5MockLocal(vrfCoordinator)
                .createSubscription();
            vm.stopBroadcast();
            console2.log("your mock subscription id is: ", subscriptionId);
            return (subscriptionId, vrfCoordinator);
        } else {
            vm.startBroadcast();
            uint256 subscriptionId = IVRFCoordinatorV2Plus(vrfCoordinator)
                .createSubscription();
            vm.stopBroadcast();
            console2.log("your subscription id is: ", subscriptionId);
            console2.log("please update CHAINLINK_SEPOLIA_SUBSCRIPTION_ID in .env");
            (
                uint96 balance,
                ,
                uint64 reqCount,
                address subOwner,

            ) = IVRFCoordinatorV2Plus(vrfCoordinator).getSubscription(
                    subscriptionId
                );
            console2.log("Subscription owner:", subOwner);
            console2.log("Balance:", balance);
            console2.log("Request count:", reqCount);
            return (subscriptionId, vrfCoordinator);
        }
    }
}

contract SubscriptionFunder is Script {
    function run() public {
        // On Anvil: read all addresses from the existing deployment rather than
        // creating a fresh HelperConfig (which would deploy new mocks with sub ID 0).
        if (block.chainid == ANVIL_CHAINID) {
            address _coord = DevOpsTools.get_most_recent_deployment("VRFCoordinatorV2_5MockLocal", block.chainid);
            address _link  = DevOpsTools.get_most_recent_deployment("LinkToken", block.chainid);
            address _raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
            fundSubscription(_coord, Raffle(_raffle).getSubscriptionId(), _link, 10);
            return;
        }
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveConfig();
        fundSubscription(config.vrfCoordinator, config.subscriptionId, config.linkToken, 10);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken,
        uint256 amount
    ) public {
        if (block.chainid == ANVIL_CHAINID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5MockLocal(vrfCoordinator).fundSubscription(
                subscriptionId,
                amount * 1000
            );
            vm.stopBroadcast();
        } else {
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
        // On Anvil: read all addresses from the existing deployment.
        if (block.chainid == ANVIL_CHAINID) {
            address _coord = DevOpsTools.get_most_recent_deployment("VRFCoordinatorV2_5MockLocal", block.chainid);
            address _raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
            addConsumer(_coord, Raffle(_raffle).getSubscriptionId(), _raffle);
            return;
        }
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveConfig();
        address raffleAddr = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumer(config.vrfCoordinator, config.subscriptionId, raffleAddr);
    }

    function addConsumer(
        address vrfCoordinator,
        uint256 subscriptionId,
        address consumerContractToAdd
    ) public {
        (uint96 balance, , , address subOwner, ) = IVRFCoordinatorV2Plus(
            vrfCoordinator
        ).getSubscription(subscriptionId);
        console2.log("*******************");
        console2.log("Subscription owner:", subOwner);
        console2.log("Balance:", balance);
        console2.log("consumerContractToAdd:", consumerContractToAdd);
        console2.log("=============================");

        vm.startBroadcast();
        if (block.chainid == ANVIL_CHAINID) {
            VRFCoordinatorV2_5MockLocal(vrfCoordinator).addConsumer(
                subscriptionId,
                consumerContractToAdd
            );
        } else {
            IVRFCoordinatorV2Plus(vrfCoordinator).addConsumer(
                subscriptionId,
                consumerContractToAdd
            );
        }
        vm.stopBroadcast();
    }
}
