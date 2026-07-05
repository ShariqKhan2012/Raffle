// SPDX-License-Identifier: MIT
// @dev Forked from @chainlink/contracts/src/v0.8/vrf/dev/SubscriptionAPI.sol (v1.1.1).
// @dev createSubscription() below drops the `blockhash(block.number - 1)` term from the
// @dev subscription id derivation. The upstream formula makes the id depend on chain history,
// @dev which differs between forge script's local simulation pass and its real broadcast pass
// @dev whenever a block is mined in between (routine on Anvil, which mines a block per tx) —
// @dev causing InvalidSubscription() on the immediately-following fundSubscription/addConsumer
// @dev calls in the same script run. Local dev only; Sepolia deploys use the real coordinator.
pragma solidity 0.8.19;

import {EnumerableSet} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.7.3/contracts/utils/structs/EnumerableSet.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC677Receiver} from "@chainlink/contracts/src/v0.8/shared/interfaces/IERC677Receiver.sol";
import {IVRFSubscriptionV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFSubscriptionV2Plus.sol";

abstract contract SubscriptionAPILocal is ConfirmedOwner, IERC677Receiver, IVRFSubscriptionV2Plus {
  using EnumerableSet for EnumerableSet.UintSet;

  LinkTokenInterface public LINK;
  AggregatorV3Interface public LINK_NATIVE_FEED;

  uint16 public constant MAX_CONSUMERS = 100;
  error TooManyConsumers();
  error InsufficientBalance();
  error InvalidConsumer(uint256 subId, address consumer);
  error InvalidSubscription();
  error OnlyCallableFromLink();
  error InvalidCalldata();
  error MustBeSubOwner(address owner);
  error PendingRequestExists();
  error MustBeRequestedOwner(address proposedOwner);
  error BalanceInvariantViolated(uint256 internalBalance, uint256 externalBalance);
  event FundsRecovered(address to, uint256 amount);
  event NativeFundsRecovered(address to, uint256 amount);
  error LinkAlreadySet();
  error FailedToSendNative();
  error FailedToTransferLink();
  error IndexOutOfRange();
  error LinkNotSet();

  struct Subscription {
    uint96 balance;
    uint96 nativeBalance;
    uint64 reqCount;
  }
  struct SubscriptionConfig {
    address owner;
    address requestedOwner;
    address[] consumers;
  }
  struct ConsumerConfig {
    bool active;
    uint64 nonce;
    uint64 pendingReqCount;
  }
  mapping(address => mapping(uint256 => ConsumerConfig)) internal s_consumers;
  mapping(uint256 => SubscriptionConfig) internal s_subscriptionConfigs;
  mapping(uint256 => Subscription) internal s_subscriptions;
  uint64 public s_currentSubNonce;
  EnumerableSet.UintSet internal s_subIds;
  uint96 public s_totalBalance;
  uint96 public s_totalNativeBalance;
  uint96 internal s_withdrawableTokens;
  uint96 internal s_withdrawableNative;

  event SubscriptionCreated(uint256 indexed subId, address owner);
  event SubscriptionFunded(uint256 indexed subId, uint256 oldBalance, uint256 newBalance);
  event SubscriptionFundedWithNative(uint256 indexed subId, uint256 oldNativeBalance, uint256 newNativeBalance);
  event SubscriptionConsumerAdded(uint256 indexed subId, address consumer);
  event SubscriptionConsumerRemoved(uint256 indexed subId, address consumer);
  event SubscriptionCanceled(uint256 indexed subId, address to, uint256 amountLink, uint256 amountNative);
  event SubscriptionOwnerTransferRequested(uint256 indexed subId, address from, address to);
  event SubscriptionOwnerTransferred(uint256 indexed subId, address from, address to);

  struct Config {
    uint16 minimumRequestConfirmations;
    uint32 maxGasLimit;
    bool reentrancyLock;
    uint32 stalenessSeconds;
    uint32 gasAfterPaymentCalculation;
    uint32 fulfillmentFlatFeeNativePPM;
    uint32 fulfillmentFlatFeeLinkDiscountPPM;
    uint8 nativePremiumPercentage;
    uint8 linkPremiumPercentage;
  }
  Config public s_config;

  error Reentrant();
  modifier nonReentrant() {
    _nonReentrant();
    _;
  }

  function _nonReentrant() internal view {
    if (s_config.reentrancyLock) {
      revert Reentrant();
    }
  }

  constructor() ConfirmedOwner(msg.sender) {}

  function setLINKAndLINKNativeFeed(address link, address linkNativeFeed) external onlyOwner {
    if (address(LINK) != address(0)) {
      revert LinkAlreadySet();
    }
    LINK = LinkTokenInterface(link);
    LINK_NATIVE_FEED = AggregatorV3Interface(linkNativeFeed);
  }

  function ownerCancelSubscription(uint256 subId) external onlyOwner {
    address subOwner = s_subscriptionConfigs[subId].owner;
    if (subOwner == address(0)) {
      revert InvalidSubscription();
    }
    _cancelSubscriptionHelper(subId, subOwner);
  }

  function recoverFunds(address to) external onlyOwner {
    if (address(LINK) == address(0)) {
      revert LinkNotSet();
    }
    uint256 externalBalance = LINK.balanceOf(address(this));
    uint256 internalBalance = uint256(s_totalBalance);
    if (internalBalance > externalBalance) {
      revert BalanceInvariantViolated(internalBalance, externalBalance);
    }
    if (internalBalance < externalBalance) {
      uint256 amount = externalBalance - internalBalance;
      if (!LINK.transfer(to, amount)) {
        revert FailedToTransferLink();
      }
      emit FundsRecovered(to, amount);
    }
  }

  function recoverNativeFunds(address payable to) external onlyOwner {
    uint256 externalBalance = address(this).balance;
    uint256 internalBalance = uint256(s_totalNativeBalance);
    if (internalBalance > externalBalance) {
      revert BalanceInvariantViolated(internalBalance, externalBalance);
    }
    if (internalBalance < externalBalance) {
      uint256 amount = externalBalance - internalBalance;
      (bool sent, ) = to.call{value: amount}("");
      if (!sent) {
        revert FailedToSendNative();
      }
      emit NativeFundsRecovered(to, amount);
    }
  }

  function withdraw(address recipient) external nonReentrant onlyOwner {
    if (address(LINK) == address(0)) {
      revert LinkNotSet();
    }
    if (s_withdrawableTokens == 0) {
      revert InsufficientBalance();
    }
    uint96 amount = s_withdrawableTokens;
    s_withdrawableTokens -= amount;
    s_totalBalance -= amount;
    if (!LINK.transfer(recipient, amount)) {
      revert InsufficientBalance();
    }
  }

  function withdrawNative(address payable recipient) external nonReentrant onlyOwner {
    if (s_withdrawableNative == 0) {
      revert InsufficientBalance();
    }
    uint96 amount = s_withdrawableNative;
    s_withdrawableNative -= amount;
    s_totalNativeBalance -= amount;
    (bool sent, ) = recipient.call{value: amount}("");
    if (!sent) {
      revert FailedToSendNative();
    }
  }

  function onTokenTransfer(address /* sender */, uint256 amount, bytes calldata data) external override nonReentrant {
    if (msg.sender != address(LINK)) {
      revert OnlyCallableFromLink();
    }
    if (data.length != 32) {
      revert InvalidCalldata();
    }
    uint256 subId = abi.decode(data, (uint256));
    if (s_subscriptionConfigs[subId].owner == address(0)) {
      revert InvalidSubscription();
    }
    uint256 oldBalance = s_subscriptions[subId].balance;
    s_subscriptions[subId].balance += uint96(amount);
    s_totalBalance += uint96(amount);
    emit SubscriptionFunded(subId, oldBalance, oldBalance + amount);
  }

  function fundSubscriptionWithNative(uint256 subId) external payable override nonReentrant {
    if (s_subscriptionConfigs[subId].owner == address(0)) {
      revert InvalidSubscription();
    }
    uint256 oldNativeBalance = s_subscriptions[subId].nativeBalance;
    s_subscriptions[subId].nativeBalance += uint96(msg.value);
    s_totalNativeBalance += uint96(msg.value);
    emit SubscriptionFundedWithNative(subId, oldNativeBalance, oldNativeBalance + msg.value);
  }

  function getSubscription(
    uint256 subId
  )
    public
    view
    override
    returns (uint96 balance, uint96 nativeBalance, uint64 reqCount, address subOwner, address[] memory consumers)
  {
    subOwner = s_subscriptionConfigs[subId].owner;
    if (subOwner == address(0)) {
      revert InvalidSubscription();
    }
    return (
      s_subscriptions[subId].balance,
      s_subscriptions[subId].nativeBalance,
      s_subscriptions[subId].reqCount,
      subOwner,
      s_subscriptionConfigs[subId].consumers
    );
  }

  function getActiveSubscriptionIds(
    uint256 startIndex,
    uint256 maxCount
  ) external view override returns (uint256[] memory ids) {
    uint256 numSubs = s_subIds.length();
    if (startIndex >= numSubs) revert IndexOutOfRange();
    uint256 endIndex = startIndex + maxCount;
    endIndex = endIndex > numSubs || maxCount == 0 ? numSubs : endIndex;
    uint256 idsLength = endIndex - startIndex;
    ids = new uint256[](idsLength);
    for (uint256 idx = 0; idx < idsLength; ++idx) {
      ids[idx] = s_subIds.at(idx + startIndex);
    }
    return ids;
  }

  /// @dev Deterministic id: drops the blockhash(block.number - 1) term upstream uses.
  function createSubscription() external override nonReentrant returns (uint256 subId) {
    uint64 currentSubNonce = s_currentSubNonce;
    subId = uint256(keccak256(abi.encodePacked(msg.sender, address(this), currentSubNonce)));
    s_currentSubNonce = currentSubNonce + 1;
    address[] memory consumers = new address[](0);
    s_subscriptions[subId] = Subscription({balance: 0, nativeBalance: 0, reqCount: 0});
    s_subscriptionConfigs[subId] = SubscriptionConfig({
      owner: msg.sender,
      requestedOwner: address(0),
      consumers: consumers
    });
    s_subIds.add(subId);

    emit SubscriptionCreated(subId, msg.sender);
    return subId;
  }

  function requestSubscriptionOwnerTransfer(
    uint256 subId,
    address newOwner
  ) external override onlySubOwner(subId) nonReentrant {
    SubscriptionConfig storage subscriptionConfig = s_subscriptionConfigs[subId];
    if (subscriptionConfig.requestedOwner != newOwner) {
      subscriptionConfig.requestedOwner = newOwner;
      emit SubscriptionOwnerTransferRequested(subId, msg.sender, newOwner);
    }
  }

  function acceptSubscriptionOwnerTransfer(uint256 subId) external override nonReentrant {
    address oldOwner = s_subscriptionConfigs[subId].owner;
    if (oldOwner == address(0)) {
      revert InvalidSubscription();
    }
    if (s_subscriptionConfigs[subId].requestedOwner != msg.sender) {
      revert MustBeRequestedOwner(s_subscriptionConfigs[subId].requestedOwner);
    }
    s_subscriptionConfigs[subId].owner = msg.sender;
    s_subscriptionConfigs[subId].requestedOwner = address(0);
    emit SubscriptionOwnerTransferred(subId, oldOwner, msg.sender);
  }

  function addConsumer(uint256 subId, address consumer) external override onlySubOwner(subId) nonReentrant {
    ConsumerConfig storage consumerConfig = s_consumers[consumer][subId];
    if (consumerConfig.active) {
      return;
    }
    address[] storage consumers = s_subscriptionConfigs[subId].consumers;
    if (consumers.length == MAX_CONSUMERS) {
      revert TooManyConsumers();
    }
    consumerConfig.active = true;
    consumers.push(consumer);

    emit SubscriptionConsumerAdded(subId, consumer);
  }

  function _deleteSubscription(uint256 subId) internal returns (uint96 balance, uint96 nativeBalance) {
    address[] storage consumers = s_subscriptionConfigs[subId].consumers;
    balance = s_subscriptions[subId].balance;
    nativeBalance = s_subscriptions[subId].nativeBalance;
    uint256 consumersLength = consumers.length;
    for (uint256 i = 0; i < consumersLength; ++i) {
      delete s_consumers[consumers[i]][subId];
    }
    delete s_subscriptionConfigs[subId];
    delete s_subscriptions[subId];
    s_subIds.remove(subId);
    if (balance != 0) {
      s_totalBalance -= balance;
    }
    if (nativeBalance != 0) {
      s_totalNativeBalance -= nativeBalance;
    }
    return (balance, nativeBalance);
  }

  function _cancelSubscriptionHelper(uint256 subId, address to) internal {
    (uint96 balance, uint96 nativeBalance) = _deleteSubscription(subId);

    if (address(LINK) != address(0) && balance != 0) {
      if (!LINK.transfer(to, uint256(balance))) {
        revert InsufficientBalance();
      }
    }

    (bool success, ) = to.call{value: uint256(nativeBalance)}("");
    if (!success) {
      revert FailedToSendNative();
    }
    emit SubscriptionCanceled(subId, to, balance, nativeBalance);
  }

  modifier onlySubOwner(uint256 subId) {
    _onlySubOwner(subId);
    _;
  }

  function _onlySubOwner(uint256 subId) internal view {
    address subOwner = s_subscriptionConfigs[subId].owner;
    if (subOwner == address(0)) {
      revert InvalidSubscription();
    }
    if (msg.sender != subOwner) {
      revert MustBeSubOwner(subOwner);
    }
  }
}
