// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console} from "forge-std/Test.sol";

/**
 * @title A sample Raffle contract
 * @author Shariq Hasan Khan
 * @notice This contract creates a sample Raffle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus /*, AutomationCompatibleInterface*/ {
    /**
     * @dev Errors
     */
    error Raffle__InsufficientEntryFee();
    error Raffle__TransferFailed(address recepient);
    error Raffle__NotOpen();
    error Raffle__NotProcessing();
    error Raffle__UpkeepNotNeeded(
        bool isRaffleRunning,
        bool hasEnoughTimePassed,
        bool hasBalance,
        bool hasPlayers
    );
    error Raffle__InvalidRequestId(uint256 lastRequestId, uint256 requestId);
    error Raffle__InvalidIndex(uint256 totalPlayers, uint256 index);

    /**
     * @dev Type declarations
     */
    enum RaffleState {
        OPEN,
        PROCESSING
    }

    /**
     * @dev State variables
     */
    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    uint256 private s_lastRequestId;
    address private s_lastWinner;
    RaffleState private s_raffleState;

    uint256 private immutable i_entryFee;
    uint256 private immutable i_interval;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint8 private constant NUM_RANDOM_WORDS = 1;

    //hash the subscription and reuest the confirmation for gas limit of numwords with xtraargs

    /**
     * @dev Events
     */
    event Raffle__PlayerEnteredRaffle(address indexed player);
    event Raffle__WinnerPicked(address indexed player);
    event Raffle__UpkeepPerformed(uint256 indexed requestId);

    constructor(
        uint256 entryFee,
        uint256 interval,
        uint256 subscriptionId,
        bytes32 hashKey,
        address vrfCoordinator,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entryFee = entryFee;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
        i_subscriptionId = subscriptionId;
        i_keyHash = hashKey;
        i_callbackGasLimit = callbackGasLimit;
    }

    /**
     * @dev Modifiers
     */
    modifier onlyOpen() {
        _onlyOpen();
        _;
    }

    modifier onlyProcessing() {
        _onlyProcessing();
        _;
    }

    /**
     * @dev Functions
     */
    function _onlyOpen() internal view {
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
    }

    function _onlyProcessing() internal view {
        if (s_raffleState != RaffleState.PROCESSING) {
            revert Raffle__NotProcessing();
        }
    }

    function enterRaffle() external payable onlyOpen {
        if (msg.value < i_entryFee) {
            revert Raffle__InsufficientEntryFee();
        }
        s_players.push(payable(msg.sender));
        emit Raffle__PlayerEnteredRaffle(msg.sender);
    }

    function _checkUpkeepDependencies()
        private
        view
        returns (
            bool isRaffleRunning,
            bool hasEnoughTimePassed,
            bool hasBalance,
            bool hasPlayers
        )
    {
        isRaffleRunning = s_raffleState == RaffleState.OPEN;
        hasEnoughTimePassed = (block.timestamp - s_lastTimestamp > i_interval);
        hasBalance = address(this).balance > 0;
        hasPlayers = s_players.length > 0;

        return (isRaffleRunning, hasEnoughTimePassed, hasBalance, hasPlayers);
    }

    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory performData) {
        (
            bool isRaffleRunning,
            bool hasEnoughTimePassed,
            bool hasBalance,
            bool hasPlayers
        ) = _checkUpkeepDependencies();

        upkeepNeeded =
            isRaffleRunning &&
            hasEnoughTimePassed &&
            hasBalance &&
            hasPlayers;
        return (upkeepNeeded, hex"");
    }

    function performUpkeep(
        bytes calldata /*performData*/
    ) external returns (uint256) {
        (
            bool isRaffleRunning,
            bool hasEnoughTimePassed,
            bool hasBalance,
            bool hasPlayers
        ) = _checkUpkeepDependencies();

        bool upkeepNeeded = isRaffleRunning &&
            hasEnoughTimePassed &&
            hasBalance &&
            hasPlayers;

        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                isRaffleRunning,
                hasEnoughTimePassed,
                hasBalance,
                hasPlayers
            );
        }

        s_raffleState = RaffleState.PROCESSING;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_RANDOM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        s_lastRequestId = requestId;

        emit Raffle__UpkeepPerformed(requestId);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        if (requestId != s_lastRequestId) {
            revert Raffle__InvalidRequestId(s_lastRequestId, requestId);
        }

        uint256 winnerIndex = randomWords[0] % s_players.length;
        s_lastWinner = s_players[winnerIndex];
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;

        emit Raffle__WinnerPicked(s_lastWinner);
        (bool success, ) = payable(s_lastWinner).call{
            value: address(this).balance
        }("");

        if (!success) {
            revert Raffle__TransferFailed(s_lastWinner);
        }
    }

    /**
     * Getter functions
     */
    function getEntryFee() public view returns (uint256) {
        return i_entryFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayerAtIndex(uint256 index) public view returns (address) {
        if (index >= s_players.length) {
            //revert Raffle__InvalidIndex(s_players.length, index);
        }
        return s_players[index];
    }

    function getLastTimestamp() public view returns (uint256) {
        return s_lastTimestamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getLastRequestId() public view returns (uint256) {
        return s_lastRequestId;
    }

    function getLastWinner() public view returns (address) {
        return s_lastWinner;
    }
}
