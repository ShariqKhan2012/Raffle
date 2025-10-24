//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {console2} from "forge-std/Test.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

uint256 constant ANVIL_CHAINID = 31337;

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
        if (block.chainid == ANVIL_CHAINID) {
            vm.startBroadcast(deployerAccount);
            uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator)
                .createSubscription();
            vm.stopBroadcast();
            console2.log("your mock subscription id is: ", subscriptionId);
            console2.log("please update your sub id in HelperConfig.s.sol");
            return (subscriptionId, vrfCoordinator);
        } else {
            vm.startBroadcast(deployerAccount);
            uint256 subscriptionId = IVRFCoordinatorV2Plus(vrfCoordinator)
                .createSubscription();
            vm.stopBroadcast();
            console2.log("your subscription id is: ", subscriptionId);
            console2.log("please update your sub id in HelperConfig.s.sol");
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
    //uint256 constant ANVIL_CHAINID = 31337;

    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getActiveConfig();

        fundSubscription(
            config.vrfCoordinator,
            config.subscriptionId,
            config.linkToken,
            //0.001 ether,
            10,
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
                amount * 1000
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerAccount);
            //first check balance
            uint256 walletLinkBalance = LinkToken(linkToken).balanceOf(
                deployerAccount
            );
            uint256 scriptLinkBalance = LinkToken(linkToken).balanceOf(
                address(this)
            );
            console2.log("Link Balance of wallet => ", walletLinkBalance);
            console2.log(
                "Link Balance of scriptLinkBalance => ",
                scriptLinkBalance
            );
            //LinkToken(linkToken).transfer(address(this), 1e18 * 10);

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
        (uint96 balance, , , address subOwner, ) = IVRFCoordinatorV2Plus(
            vrfCoordinator
        ).getSubscription(subscriptionId);
        console2.log("*******************");
        console2.log("Subscription owner:", subOwner);
        console2.log("Balance:", balance);
        console2.log("consumerContractToAdd:", consumerContractToAdd);
        console2.log("=============================");

        vm.startBroadcast(deployerAccount);
        if (block.chainid == ANVIL_CHAINID) {
            VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
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
