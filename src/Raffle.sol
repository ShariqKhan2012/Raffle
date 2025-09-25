// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @author Shariq Hasan Khan
 * @notice This contract creates a sample Raffle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle {
    /**
     * @dev Errors
     */
    error Raffle__InsufficientEntryFee();

    /**
     * @dev State variables
     */
    uint256 private immutable i_entryFee;
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    uint256 private s_lastRequestId;

    /**
     * @dev Events
     */
    event Raffle__PlayerEnteredRaffle(address indexed player);

    constructor(uint256 entryFee, uint256 interval) {
        i_entryFee = entryFee;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entryFee) {
            revert Raffle__InsufficientEntryFee();
        }
        s_players.push(payable(msg.sender));
        emit Raffle__PlayerEnteredRaffle(msg.sender);
    }

    function pickWiner() public view {
        if (block.timestamp - s_lastTimestamp < i_interval) {
            revert();
        }
    }

    /**
     * Getter functions
     */
    function getEntryFee() public view returns (uint256) {
        return i_entryFee;
    }
}
