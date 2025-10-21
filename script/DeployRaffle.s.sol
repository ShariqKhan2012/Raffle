//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {SubscriptionCreator, SubscriptionFunder, ConsumerAdder} from "script/Interactions.s.sol";
import {console2} from "forge-std/Test.sol";

contract DeployRaffle is Script {
    function run()
        external
        returns (Raffle, HelperConfig.NetworkConfig memory)
    {
        /**
         * Any transaction that comes after vm.startBroadcast()
         * is a real trasaction. Anything before that isn't.
         * So, it make sense to initialize HelperConfig before
         * we call vm.startBroadcast()
         */
        HelperConfig helperConfig = new HelperConfig();

        /**
         * If you are passing the price feed address as
         * command-line arguments, then you can access it
         * here as:
         * address priceFeedAddress = vm.envAddress("PRICE_FEED_ADDRESS");
         */
        HelperConfig.NetworkConfig memory config = helperConfig
            .getActiveConfig();
        console2.log(
            "Checking config.subscriptionId => ",
            config.subscriptionId
        );
        if (config.subscriptionId == 0) {
            /**
             * @dev Populate the correct subscription Id
             * Following code should NOT be between
             * `vm.startBroadcast()` and `vm.stopBroadcast()`
             * because `createSubscription()` already contains
             * a broadcast block
             */
            SubscriptionCreator subscriptionCreator = new SubscriptionCreator();
            (config.subscriptionId, ) = subscriptionCreator.createSubscription(
                config.vrfCoordinator,
                config.deployerAccount
            );

            /**
             * @dev Fund the subscription with link tokens
             * Following code should NOT be between
             * `vm.startBroadcast()` and `vm.stopBroadcast()`
             * because `fundSubscription()` already contains
             * a broadcast block
             */
            SubscriptionFunder subscriptionFunder = new SubscriptionFunder();
            subscriptionFunder.fundSubscription(
                config.vrfCoordinator,
                config.subscriptionId,
                config.linkToken,
                config.entryFee * 10000, // Just so that we have more than sufficiet funds,
                config.deployerAccount
            );
        }

        vm.startBroadcast(config.deployerAccount);
        Raffle raffle = new Raffle(
            config.entryFee,
            config.interval,
            config.subscriptionId,
            config.hashKey,
            config.vrfCoordinator,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        /**
         * @dev Add consumer to the subscription
         * Following code should NOT be between
         * `vm.startBroadcast()` and `vm.stopBroadcast()` because
         * `addCosumer()` already contains a broadcast block
         */
        ConsumerAdder consumerAdder = new ConsumerAdder();
        consumerAdder.addConsumer(
            config.vrfCoordinator,
            config.subscriptionId,
            address(raffle),
            config.deployerAccount
        );

        return (raffle, config);
    }
}
