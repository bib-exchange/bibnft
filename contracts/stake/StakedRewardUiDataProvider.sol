//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "../interfaces/IStakedSoccerStarNftV2.sol";
import "../interfaces/DividendPayingTokenInterface.sol";
import "../lib/SafeMath.sol";

contract StakedRewardUiDataProvider {
    using SafeMath for uint;

    IStakedSoccerStarNftV2 staked;
    DividendPayingTokenInterface dividend;

    constructor(address _staked, address _dividend){
        require((address(0) != _staked) && (address(0) != _dividend), "INVALID_ADDRESS");
        staked = IStakedSoccerStarNftV2(_staked);
        dividend = DividendPayingTokenInterface(_dividend);
    }
        // get unclamined rewards
    function getUnClaimedRewards(address user) 
    public view returns(uint amount){
        return staked.getUnClaimedRewards(user).add(dividend.dividendOf(user));
    }

    // Claim rewards
    function claimRewards() public{
        staked.claimRewards();
        dividend.withdrawDividend();
    }
}