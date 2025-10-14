//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig.NetworkConfig config;

    address PLAYER = makeAddr("player");
    uint256 constant STARTING_BALANCE = 10 ether;

    event Raffle__PlayerEnteredRaffle(address indexed player);
    event Raffle__WinnerPicked(address indexed player);

    function setUp() external {
        console2.log("Raffle test setup");
        vm.deal(PLAYER, STARTING_BALANCE);
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, config) = deployRaffle.run();
    }

    function testRaffleStartsInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testPlayersNeedMinimumFeeToPlay() external {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__InsufficientEntryFee.selector);
        raffle.enterRaffle();
    }

    function testPlayersAreRecordedIList() external {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: config.entryFee}();
        assertEq(raffle.getPlayerAtIndex(0), PLAYER);
    }

    function testEnterigRaffleEmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle__PlayerEnteredRaffle(PLAYER);
        raffle.enterRaffle{value: config.entryFee}();
    }

    function testPlayerCannotEnterInRaffleProcessingState() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: config.entryFee}();
        /**
         * @dev Fast forward the time so that we meet
         * the "enough time has passed" criterio.
         */
        vm.warp(block.timestamp + config.interval + 1);
        /**
         * @dev OPTIONAL: Increment the block number
         */
        vm.roll(block.number + 1);

        /**
         * @dev Let's call `performUpkeep()' manually,
         * so that the raffle enters the PROCESSING state.
         * At that point, no player should be able to enter
         * the raffle
         */
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: config.entryFee}();
    }
}
