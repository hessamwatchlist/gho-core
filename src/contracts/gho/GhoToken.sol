// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.8.0;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ERC20} from './ERC20.sol';
import {IGhoToken} from './interfaces/IGhoToken.sol';

/**
 * @title GHO Token
 * @author Aave
 */
contract GhoToken is ERC20, Ownable, IGhoToken {
  using EnumerableSet for EnumerableSet.AddressSet;

  mapping(address => Facilitator) internal _facilitators;
  EnumerableSet.AddressSet internal _facilitatorsList;

  /**
   * @dev Constructor
   */
  constructor() ERC20('Gho Token', 'GHO', 18) {}

  /**
   * @notice Mints the requested amount of tokens to the account address.
   * @dev Only facilitators with enough bucket capacity available can mint.
   * @dev The bucket level is increased upon minting.
   * @param account The address receiving the GHO tokens
   * @param amount The amount to mint
   */
  function mint(address account, uint256 amount) external override {
    uint256 bucketCapacity = _facilitators[msg.sender].bucket.capacity;
    require(bucketCapacity > 0, 'INVALID_FACILITATOR');

    uint256 currentBucketLevel = _facilitators[msg.sender].bucket.level;
    uint256 newBucketLevel = currentBucketLevel + amount;
    require(bucketCapacity >= newBucketLevel, 'FACILITATOR_BUCKET_CAPACITY_EXCEEDED');
    _facilitators[msg.sender].bucket.level = uint128(newBucketLevel);

    emit BucketLevelChanged(msg.sender, currentBucketLevel, newBucketLevel);
    _mint(account, amount);
  }

  /**
   * @notice Burns the requested amount of tokens from the account address.
   * @dev Only active facilitators (capacity > 0) can burn.
   * @dev The bucket level is decreased upon burning.
   * @param amount The amount to burn
   */
  function burn(uint256 amount) external override {
    uint256 currentBucketLevel = _facilitators[msg.sender].bucket.level;
    uint256 newBucketLevel = currentBucketLevel - amount;
    _facilitators[msg.sender].bucket.level = uint128(newBucketLevel);
    emit BucketLevelChanged(msg.sender, currentBucketLevel, newBucketLevel);
    _burn(msg.sender, amount);
  }

  /// @inheritdoc IGhoToken
  function addFacilitator(address facilitatorsAddress, Facilitator memory facilitatorConfig)
    external
    onlyOwner
  {
    Facilitator storage facilitator = _facilitators[facilitatorsAddress];
    require(bytes(facilitator.label).length == 0, 'FACILITATOR_ALREADY_EXISTS');
    require(bytes(facilitatorConfig.label).length > 0, 'INVALID_LABEL');
    require(facilitatorConfig.bucket.level == 0, 'INVALID_BUCKET_CONFIGURATION');

    facilitator.label = facilitatorConfig.label;
    facilitator.bucket = facilitatorConfig.bucket;

    _facilitatorsList.add(facilitatorsAddress);

    emit FacilitatorAdded(
      facilitatorsAddress,
      facilitatorConfig.label,
      facilitatorConfig.bucket.capacity
    );
  }

  /// @inheritdoc IGhoToken
  function removeFacilitator(address facilitatorAddress) external onlyOwner {
    require(
      bytes(_facilitators[facilitatorAddress].label).length > 0,
      'FACILITATOR_DOES_NOT_EXIST'
    );
    require(
      _facilitators[facilitatorAddress].bucket.level == 0,
      'FACILITATOR_BUCKET_LEVEL_NOT_ZERO'
    );

    delete _facilitators[facilitatorAddress];
    _facilitatorsList.remove(facilitatorAddress);

    emit FacilitatorRemoved(facilitatorAddress);
  }

  /// @inheritdoc IGhoToken
  function setFacilitatorBucketCapacity(address facilitator, uint128 newCapacity)
    external
    onlyOwner
  {
    require(bytes(_facilitators[facilitator].label).length > 0, 'FACILITATOR_DOES_NOT_EXIST');

    uint256 oldCapacity = _facilitators[facilitator].bucket.capacity;
    _facilitators[facilitator].bucket.capacity = newCapacity;

    emit FacilitatorBucketCapacityUpdated(facilitator, oldCapacity, newCapacity);
  }

  /// @inheritdoc IGhoToken
  function getFacilitator(address facilitator) external view returns (Facilitator memory) {
    return _facilitators[facilitator];
  }

  /// @inheritdoc IGhoToken
  function getFacilitatorBucket(address facilitator) external view returns (Bucket memory) {
    return _facilitators[facilitator].bucket;
  }

  /// @inheritdoc IGhoToken
  function getFacilitatorsList() external view returns (address[] memory) {
    return _facilitatorsList.values();
  }
}
