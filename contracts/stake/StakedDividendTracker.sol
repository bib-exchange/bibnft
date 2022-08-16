//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../lib/SafeMathUint.sol";
import "../lib/SafeMathInt.sol";

import {DividendPayingToken} from "../misc/DividendPayingToken.sol";
import {IBalanceHook} from "../interfaces/IBalanceHook.sol";
import "../interfaces/IFeeReceiver.sol";

contract StakedDividendTracker is 
DividendPayingToken,
Ownable,
IFeeReceiver,
IBalanceHook {
    using SafeMath for uint256;
    using SafeMathUint for uint256;
    using SafeMathInt for int256;

    mapping(address=>bool) public allowCallTb;
    mapping(address=>uint[]) public userTokenTb;

    bool public _paused;

    IERC20 rewardToken;

    event ReceivedFee(address sender, uint amount);
    event DividendWithdrawn(address user, uint tokenId, uint amount);
    event RewardTokenChanged(address sender, address newValue, address oldValue);

    modifier onlyWhenNotPaused {
        require(!_paused, "PAUSED");
        _;
    }

    function puase() public onlyOwner {
        _paused = true;
    }

    function unpause() public onlyOwner{
        _paused = false;
    }

    constructor(address _rewardToken){
        require(address(0) != _rewardToken, "INVALID_ADDRESS");
        rewardToken = IERC20(_rewardToken);
    }

    function setRewardToken(address _rewardToken) public onlyOwner {
        require(address(0) != _rewardToken, "INVALID_ADDRESS");
        emit RewardTokenChanged(msg.sender, _rewardToken, address(rewardToken));
        rewardToken = IERC20(_rewardToken);
    }

    function setAllowToCall(address caller, bool allow) public onlyOwner{
        allowCallTb[caller] = true;
    }

    function isAllowToCall(address caller) public view returns(bool){
        return allowCallTb[caller];
    }

    modifier onlyCaller(){
        require(allowCallTb[msg.sender], "ONLY_CALLER");
        _;
    }

    function hookBalanceChange(address user, uint tokenId, uint newBalance)
     public override onlyCaller{
        if(newBalance > 0){
            userTokenTb[user].push(tokenId);
        } else {
            // remove token
            uint[] storage tokens = userTokenTb[user];
            uint indexToRm = tokens.length;
            for(uint i = 0; i < tokens.length; i++){
                if(tokens[i] == tokenId){
                    indexToRm = i;
                    break;
                }
            }
            require(indexToRm < tokens.length, "TOKEN_NOT_EXIST");
            for(uint i = indexToRm; i < tokens.length - 1; i++){
                tokens[i] = tokens[i+1];
            }
            tokens.pop();
        }

        _setBalance(tokenId, newBalance);
    }

    function handleReceive(uint amount) public override onlyCaller{
        emit ReceivedFee(msg.sender, amount);
        _distributeDividends(amount);
    }

    /// @notice Withdraws the ether distributed to the sender.
    /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn ether is greater than 0.
    function withdrawDividendOfToken(uint tokenId) public onlyWhenNotPaused{
        _withdrawDividendOfToken(msg.sender, tokenId);
    }

    /// @notice Withdraws the ether distributed to the sender.
    /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn ether is greater than 0.
    function withdrawDividend() public onlyWhenNotPaused{
        uint[] storage tokens = userTokenTb[msg.sender];
        for(uint i = 0; i < tokens.length; i++){
            _withdrawDividendOfToken(msg.sender, tokens[i]); 
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