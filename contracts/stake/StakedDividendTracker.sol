//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../lib/SafeMathUint.sol";
import "../lib/SafeMathInt.sol";

import {DividendPayingToken} from "../misc/DividendPayingToken.sol";
import {IBalanceHook} from "../interfaces/IBalanceHook.sol";
import "../interfaces/IFeeReceiver.sol";
import "../interfaces/IStakedDividendTracker.sol";

contract StakedDividendTracker is 
DividendPayingToken,
OwnableUpgradeable,
PausableUpgradeable,
IStakedDividendTracker,
IFeeReceiver,
IBalanceHook {
    using SafeMath for uint256;
    using SafeMathUint for uint256;
    using SafeMathInt for int256;

    mapping(address=>bool) public allowCallTb;
    mapping(address=>uint[]) public userTokenTb;

    IERC20 public rewardToken;

    event ReceivedFee(address sender, uint amount);
    event DividendWithdrawn(address user, uint tokenId, uint amount);
    event RewardTokenChanged(address sender, address newValue, address oldValue);

    function initialize(
    address _rewardToken
    ) reinitializer(1) public {
        require(address(0) != _rewardToken, "INVALID_ADDRESS");
        rewardToken = IERC20(_rewardToken);
        __Pausable_init();
        __Ownable_init();
    }

    function setRewardToken(address _rewardToken) public onlyOwner {
        require(address(0) != _rewardToken, "INVALID_ADDRESS");
        emit RewardTokenChanged(msg.sender, _rewardToken, address(rewardToken));
        rewardToken = IERC20(_rewardToken);
    }

    function setAllowToCall(address caller, bool allow) public onlyOwner{
        allowCallTb[caller] = allow;
    }

    function isAllowToCall(address caller) public view returns(bool){
        return allowCallTb[caller];
    }

    modifier onlyCaller(){
        require(allowCallTb[msg.sender], "ONLY_CALLER");
        _;
    }

    function dividendOf(address user) public view override returns(uint256) {
        uint unclaimed = 0;
        uint[] storage tokens = userTokenTb[user];
        for(uint i = 0; i < tokens.length; i++){
            unclaimed += dividendOfToken(tokens[i]);
        }
        return unclaimed;
    }

    function dividendOfToken(uint tokenId) 
    public view  override returns(uint256) {
        return withdrawableDividendOf(tokenId);
    }
 
    function hookBalanceChange(address user, uint tokenId, uint newBalance)
     public override onlyCaller{
        if(newBalance > 0){
            userTokenTb[user].push(tokenId);
        } else {
            // remove token
            uint[] storage tokens = userTokenTb[user];
            for(uint i = 0; i < tokens.length; i++){
                if(tokens[i] == tokenId){
                    tokens[i] = tokens[tokens.length - 1];
                    tokens.pop();
                    break;
                }
            }
        }

        _setBalance(tokenId, newBalance);
    }

    function handleReceive(uint amount) public override onlyCaller{
        emit ReceivedFee(msg.sender, amount);
        _distributeDividends(amount);
    }

    /// @notice Withdraws the ether distributed to the sender.
    /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn ether is greater than 0.
    function withdrawDividendOfToken(uint tokenId) public whenNotPaused{
        uint[] storage tokenIds = userTokenTb[msg.sender];
        uint index = tokenIds.length;
        for(uint i; i < tokenIds.length; i++){
            if(tokenId == tokenIds[i]){
                index = i;
                break;
            }
        }
        require(index <  tokenIds.length, "TOKEN_NOT_BELONG_TO_USER");
    
        _withdrawDividendOfToken(msg.sender, tokenId);
    }

    /// @notice Withdraws the ether distributed to the sender.
    /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn ether is greater than 0.
    function withdrawDividendOnbehalfOf(address to) public whenNotPaused{
        _withdrawDividend(to);
    }

    function withdrawDividend() public whenNotPaused{
        _withdrawDividend(msg.sender);
    }

    function _withdrawDividend(address to) internal {
        uint[] storage tokens = userTokenTb[to];
        for(uint i = 0; i < tokens.length; i++){
            _withdrawDividendOfToken(to, tokens[i]); 
        }
    }

    function _withdrawDividendOfToken(address user, uint256 tokenId) 
    internal returns (uint256) {
        uint256 _withdrawableDividend = withdrawableDividendOf(tokenId);
        if (_withdrawableDividend > 0) {
            withdrawnDividends[tokenId] = withdrawnDividends[tokenId].add(_withdrawableDividend);
            emit DividendWithdrawn(user, tokenId, _withdrawableDividend);
            bool success = rewardToken.transfer(user, _withdrawableDividend);

            if(!success) {
                withdrawnDividends[tokenId] = withdrawnDividends[tokenId].sub(_withdrawableDividend);
                return 0;
            }

            return _withdrawableDividend;
        }

        return 0;
    }
}