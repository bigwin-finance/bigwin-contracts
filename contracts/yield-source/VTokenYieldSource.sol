// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@pooltogether/fixed-point/contracts/FixedPoint.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@pooltogether/yield-source-interface/contracts/IYieldSource.sol";

import "../external/venus/VTokenInterface.sol";

/// @title Defines the functions used to interact with a yield source.  The Prize Pool inherits this contract.
/// @notice Prize Pools subclasses need to implement this interface so that yield can be generated.
contract VTokenYieldSource is IYieldSource {
  using SafeMathUpgradeable for uint256;

  event VTokenYieldSourceInitialized(address indexed vToken);

  mapping(address => uint256) public balances;

  /// @notice Interface for the Yield-bearing vToken by Venus
  VTokenInterface public vToken;

  /// @notice Initializes the Yield Service with the Venus vToken
  /// @param _vToken Address of the Venus vToken interface
  constructor (
    VTokenInterface _vToken
  )
    public
  {
    vToken = _vToken;

    emit VTokenYieldSourceInitialized(address(vToken));
  }

  /// @notice Returns the ERC20 asset token used for deposits.
  /// @return The ERC20 asset token
  function depositToken() public override view returns (address) {
    return _tokenAddress();
  }

  function _tokenAddress() internal view returns (address) {
    return vToken.underlying();
  }

  function _token() internal view returns (IERC20Upgradeable) {
    return IERC20Upgradeable(_tokenAddress());
  }

  /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
  /// @return The underlying balance of asset tokens
  function balanceOfToken(address addr) external override returns (uint256) {
    uint256 totalUnderlying = vToken.balanceOfUnderlying(address(this));
    uint256 total = vToken.balanceOf(address(this));
    if (total == 0) {
      return 0;
    }
    return balances[addr].mul(totalUnderlying).div(total);
  }

  /// @notice Supplies asset tokens to the yield source.
  /// @param amount The amount of asset tokens to be supplied
  function supplyTokenTo(uint256 amount, address to) external override {
    _token().transferFrom(msg.sender, address(this), amount);
    IERC20Upgradeable(vToken.underlying()).approve(address(vToken), amount);
    uint256 vTokenBalanceBefore = vToken.balanceOf(address(this));
    require(vToken.mint(amount) == 0, "VTokenYieldSource/mint-failed");
    uint256 vTokenDiff = vToken.balanceOf(address(this)).sub(vTokenBalanceBefore);
    balances[to] = balances[to].add(vTokenDiff);
  }

  /// @notice Redeems asset tokens from the yield source.
  /// @param redeemAmount The amount of yield-bearing tokens to be redeemed
  /// @return The actual amount of tokens that were redeemed.
  function redeemToken(uint256 redeemAmount) external override returns (uint256) {
    uint256 vTokenBalanceBefore = vToken.balanceOf(address(this));
    uint256 balanceBefore = _token().balanceOf(address(this));
    require(vToken.redeemUnderlying(redeemAmount) == 0, "VTokenYieldSource/redeem-failed");
    uint256 vTokenDiff = vTokenBalanceBefore.sub(vToken.balanceOf(address(this)));
    uint256 diff = _token().balanceOf(address(this)).sub(balanceBefore);
    balances[msg.sender] = balances[msg.sender].sub(vTokenDiff);
    _token().transfer(msg.sender, diff);
    return diff;
  }
}
