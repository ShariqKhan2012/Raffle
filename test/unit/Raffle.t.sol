//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig.NetworkConfig config;

    address PLAYER = makeAddr("player");
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant ANVIL_CHAINID = 31337;

    event Raffle__PlayerEnteredRaffle(address indexed player);
    event Raffle__WinnerPicked(address indexed player);

    function setUp() external {
        console2.log("Raffle test setup");
        vm.deal(PLAYER, STARTING_BALANCE);
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, config) = deployRaffle.run();
    }

    modifier raffleEntered() {
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

        _;
    }

    modifier skipFork() {
        if (block.chainid != ANVIL_CHAINID) {
            return;
        }
        _;
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

    function testPlayerCannotEnterInRaffleProcessingState()
        public
        raffleEntered
    {
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

    function testCheckUpkeepFailsOnNoBalance() public {
        /**
         * @dev Fast forward the time so that we meet
         * the "enough time has passed" criterio.
         */
        vm.warp(block.timestamp + config.interval + 1);
        /**
         * @dev OPTIONAL: Increment the block number
         */
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepFailsIfRaffleIsProcessing() public raffleEntered {
        /**
         * @dev Let's call `performUpkeep()' manually,
         * so that the raffle enters the PROCESSING state.
         * At that point, checkUpkeep() should return false
         */
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testPerformUkeepRunsIfCheckUpkeepPasses() public raffleEntered {
        /**
         * @dev At that point, performUpkeep() should
         * run successfully
         */
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepFails() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: config.entryFee}();

        bool isRaffleRunning = raffle.getRaffleState() ==
            Raffle.RaffleState.OPEN;
        bool hasEnoughTimePassed = (block.timestamp -
            raffle.getLastTimestamp() >
            raffle.getInterval());
        bool hasBalance = raffle.getBalance() > 0;
        bool hasPlayers = raffle.getPlayerAtIndex(0) != address(0);

        /**
         * @dev We are expecting a revert because enough
         * time has not passed and we have not manually
         * fast-forwarded the time using `vm.warp()` either
         */
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                isRaffleRunning,
                hasEnoughTimePassed,
                hasBalance,
                hasPlayers
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesStateAndEmitsLogs() public raffleEntered {
        vm.recordLogs();
        raffle.performUpkeep("");

        assert(raffle.getRaffleState() == Raffle.RaffleState.PROCESSING);

        /**
         * @dev entries[0] is the first log. It is the event
         * `RandomWordsRequested()` emitted by the vrfCoordinator.
         * We are not interested in it, so we skip it.
         * The event emitted by our contract `Raffle.sol` in
         * `performUpkeep()` is the second log, so we focus on entries[1].
         * Further topics[0] is the keccak256 hash of the event
         * signature (e.g. keccak256("Raffle__UpkeepPerformed(uint256)")).
         * So, we skip topics[0] ad focus o topics[1]
         */
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        assert(uint256(requestId) > 0);
    }

    /**
     *
     * @param randomRequestId Passing a parameter to the test
     * function invokes fuzz testing i.e. the test will be run `N`
     * times with random values of the parameter.
     * `N` defaults to 256, bt ca be configured in the
     * `foundry.toml` file by the variable ``
     */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public skipFork raffleEntered {
        /**
         * @dev If `performUpkeep()` has not been called,
         * then there will not be a valid `s_lastRequestId`.
         * Therefore, the evm will revert with the error:
         * `Raffle__InvalidRequestId(uint256 lastRequestId, uint256 requestId)`
         *
         * Also, since `Raffle::fulfillRandomWords()` is an internal
         * function, we can't call it from here.
         * Instead, we will call `VRFCoordinatorV2_5Mock::fulfillRandomWords()`
         * which in turn will call `Raffle::fulfillRandomWords()`
         * You can read it in more detail at:
         * https://chatgpt.com/c/68f1e483-88c8-8321-8785-0cca22bc25d2
         */
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksWinnerAndSendsMoney()
        public
        skipFork
        raffleEntered
    {
        //Arrange
        uint8 NUM_PLAYERS = 5;

        /**
         * @dev Start from index 1 because the `raffleEntered`
         * modifier already results in one player enterig the
         * raffle.
         */
        for (uint256 i = 1; i < NUM_PLAYERS; i++) {
            //address player = makeAddr(string(abi.encodePacked("player", i)));
            // Or use vm.addr() for numeric approach in tests
            address player = vm.addr(i);
            hoax(player, STARTING_BALANCE);
            raffle.enterRaffle{value: config.entryFee}();
        }

        /**
         * All the players should have the same balance
         * at this moment, which should be equal to their
         * starting balance minus the entry fee of the
         * raffle i.e (STARTING_BALANCE - config.entryFee)
         */
        uint256 balanceBeforeWinning = address(PLAYER).balance;

        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        //vm.expectEmit(false, false, false, false, address(raffle));
        /**
         * @dev It is okay to pass any player's address to
         * `Raffle__WinnerPicked()` because in `vm.expectEmit()`
         * we have indicated we are not interested in checking the
         * address, by passing `false` to the first argument.
         */
        //emit Raffle__WinnerPicked(PLAYER);

        //Act
        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        address winner = raffle.getLastWinner();
        uint256 winnerEndingBalance = winner.balance;
        uint rewardAmount = (NUM_PLAYERS * config.entryFee);

        // Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);

        assert(uint256(requestId) == raffle.getLastRequestId());

        assert(winnerEndingBalance == balanceBeforeWinning + rewardAmount);
    }
}
