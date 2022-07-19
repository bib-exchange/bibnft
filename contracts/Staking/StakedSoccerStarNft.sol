//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {SafeMath} from "../libs/SafeMath.sol";
import {ISoccerStarNft} from "../interfaces/ISoccerStarNft.sol";
import {IStakedSoccerStarNft} from "../interfaces/IStakedSoccerStarNft.sol";

contract StakedSoccerStarNft is Ownable {
    using SafeMath for uint;

    event FrozenDurationChanged(uint oldValue, uint newValue);
    event RewardPeriodChanged(uint oldValue, uint newValue);
    event RewardStartChanged(uint oldValue, uint newValue);
    event RewardContractChanged(uint oldValue, uint newValue);
    event NftContractChanged(uint oldValue, uint newValue);

    IERC20 public rewardContract;
    IERC721 public nftContract;
    
    uint public rewardPeriod = 1 days;
    uint public frozenDuration = 7 days;
    uint public rewardStart;
    uint public totalStaked;
    uint public totalPower;

    DepositInfo[] public depositInfos;

    // Keep a fast index to avoid too many times of loop
    mapping(uint=>DepositInfo) public roundToDepositInfos;

    mapping(address=>UserStakedInfo[]) public stakedInfos;

    // Keep a fast index to avoid too many times of loop
    mapping(uint=>UserStakedInfo) public tokenToUserStakedInfo;

    constructor(
        address _rewardContract,
        address _nftContract,
        uint _rewardPeriod,
        uint _rewardStart
        ){
        rewardContract = _rewardContract;
        nftContract = _nftContract;
        rewardPeriod = _rewardPeriod;
        rewardStart = _rewardStart;
    }

    modifier onlyContract(address cntr) {
        require(address(0) != cntr, "INVALID_ADDRESS");
        require(Address.isContract(cntr), "NOT_CONTRACT");
        _;
    }

    modifier ownToken(uint tokenId){
        require(msg.sender == nftContract.ownerOf(tokenId), "TOKEN_NOT_BELONG_TO_SENDER");
        _;
    }

   function setFrozenDuration(uint newValue) onlyOwner {
        emit FrozenDurationChanged(frozenDuration, newValue);
        frozenDuration = newValue;
    }

    function setRewardPeroid(uint newValue) onlyOwner {
        require(newValue >= 1 days,  "REWARD_PERIOD_TOO_SHORT");
        emit RewardPeriodChanged(rewardPeriod, newValue);
        rewardPeriod = newValue;
    }

    function setRewardStart(uint newValue) onlyOwner {
        require(newValue >= block.timestamp, "REWARD_START_LESS_THAN_CURRENT");
        emit RewardStartChanged(rewardStart, newValue);
        rewardStart = newValue;
    }

    function setRewardContract(address newValue) onlyOwner onlyContract(newValue){
        emit RewardContractChanged(rewardContract, newValue);
        rewardContract = IERC20(newValue);
    }

    function setNftContract(address newValue) onlyOwner onlyContract(newValue){
        emit NftContractChanged(nftContract, newValue);
        nftContract = IERC721(newValue);
    }

      // deposit a specified funds to pool
    function deposit(uint amount) public override {
        require(amout > 0, "AMOUNT_TOOL_SMALL");
        
        (bool hasRound, uint round, DepositInfo memory roundInfo) = checkAndGetRound();
        if(!hasRound || (round > roundInfo.round)){
            // close old 
            if(hasRound){
                closeRound();
            }

            DepositInfo memory depositInfo = DepositInfo({
                round:round,
                totalDeposit:amuont,
                totalStaked:0,
                totalPower:0,
                totalClaimed:0
            });
            depositInfos.push(depositInfo);
            roundToDepositInfos[round] = depositInfo;
        }else {
            roundInfo.totalDeposit += amount;
            depositInfos[depositInfos.length - 1] = roundInfo;
        }

        rewardContract.transferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, round, amount);
    } 

    function getCurrentRound() public view override returns(uint round){
        return block.timestamp.sub(rewardStart).div(rewardPeriod);
    }

    function checkAndGetRound() public returns(uint, uint, DepositInfo memory){
        if(depositInfos.length <= 0){
            return (false, 0, DepositInfo({round:0,totalDeposit:0,totalStaked:0}));
        }
        uint round = getCurrentRound();
        DepositInfo storage roundInfo = depositInfos[depositInfos.length - 1];
        require(round >= roundInfo.round, "INVALID_ROUND");
        return (true, round, roundInfo);
    }

    // close a reward period
    function closeRound() public override{
        (bool hasRound, uint round, DepositInfo memory roundInfo) = checkAndGetRound();
        if(hasRound && (round > roundInfo.round)){
            // finalize total amount
            roundInfo.totalStaked = totalStaked;
            roundInfo.totalPower = totalPower;
            depositInfos[depositInfos.length - 1] = roundInfo;
            
            emit CloseRound(
            msg.sender, 
            roundInfo.round, 
            roundInfo.totalDeposit, 
            roundInfo.totalStaked,
            roundInfo.totalPower
            );
        }
    }

    // check is the specified token is staked
    function isStaked(uint tokenId) public view override returns(bool){
        // give that the token id start with 1
        return tokenToUserStakedInfo[tokenId].tokenId == tokenId 
        && tokenToUserStakedInfo[tokenId].unfrozenTime == 0;
    }

    // Check if is the specified token is staking
    function isStaking(uint tokenId) public view override returns(bool){
        return (tokenToUserStakedInfo[tokenId].tokenId == tokenId);
    }

    // Check if the specified token is unfreezing
    function isUnfreezing(uint tokenId) public view override returns(bool){
        uint unfrozenTime = tokenToUserStakedInfo[tokenId].unfrozenTime;
        return (unfrozenTime > 0
        && block.timestamp <=  unfrozenTime);
    }

    // Check if the specified token is withdrawable
    function isWithdrawAble(uint tokenId) public view override returns(bool){
        uint unfrozenTime = tokenToUserStakedInfo[tokenId].unfrozenTime;
        return (unfrozenTime > 0 && block.timestamp >  unfrozenTime);
    }
    
    // user staken one or more nft card to safty module
    function stake(uint tokenId) public override ownToken(tokenId){
        require(!isStaking(tokenId), "TOKEN_STAKING");

        // check if need to close the old round
        closeRound();

        totalStaked++;
        totalPower += getTokenPower(tokenId);

        stakedInfos[msg.sender].push(UserStakedInfo({
            tokenId: tokenId,
            round: getCurrentRound(),
            unfrozenTime:0,
            claimed: false
        }));
        nftContract.transferFrom(msg.sender, address(this), tokenId);

        emit Stake(msg.sender, tokenId);
    }

    function getTokenPower(uint tokenId) public view returns(uint power){
        ISoccerStarNft.SoccerStar memory cardInfo = ISoccerStarNft(nftContract).getCardProperty(tokenId);
        require(0 != cardInfo.starLevel, "CARD_UNREAL");
        // The power equation: power = gradient * 10 ^ (starLevel -1)
        return cardInfo.gradient.exp(cardInfo.starLevel.sub(1));
    }

    // user redeem one or more nft cards
    function redeem(uint tokenId) public override ownToken(tokenId){
        require(isStaked(tokenId), "TOKEN_NOT_STAKED");

        // check if need to close the old round
        closeRound();

        // claim all rewards
        claimRewards();

        // update global data
        totalPower -= getTokenPower(tokenId);
        totalStaked--;

        // update fast index
        tokenToUserStakedInfo[tokenId].unfrozenTime = block.timestamp + frozenDuration;

        UserStakedInfo[] storage userStakedInfos = stakedInfos[msg.sender];
        uint indexToRm = userStakedInfos.length;
        for(uint i = 0; i < userStakedInfos.length; i++){
           if(userStakedInfos[i].tokenId == tokenId){
                indexToRm = i;
           }
        }
        require(indexToRm < userStakedInfos.length, "TOKEN_NOT_EXIST");
        // delete from index
        for(uint i = indexToRm; i < userStakedInfos.length - 1; i++){
            userStakedInfos[i] = userStakedInfos[i+1];
        }
        userStakedInfos.pop();

        emit Reem(msg.sender, tokenId);
    }

    // withdraw token after the unfrozen period
    function withdraw(uint tokenId) public override ownToken(tokenId){
        require(isWithdrawAble(tokenId), "TOKEN_NOT_WITHDRAWABLE");

        // check if need to close the old round
        closeRound();

        // delete from the fast index
        delete tokenToUserStakedInfo[tokenId];

        nftContract.transferFrom(address(this), msg.sender, tokenId);

        emit Withdraw(msg.sender, tokenId);
    }

    function getUnClaimedRewards(address user) public override view returns(uint amount){
        return getAndMarkUnClaimedRewards(user, false);
    }

    // Get unclaimed rewards 
    function getAndMarkUnClaimedRewards(address user, bool markClaim)
     internal returns(uint amount){
        UserStakedInfo[] storage userStakedInfos = stakedInfos[user];
        if(0 == userStakedInfos.length){
            return 0;
        }

        uint totalRewards = 0;
        uint curRound = getCurrentRound();

        // go through to accurate the rewards
        for(uint i = 0; i < userStakedInfos.length; i++){
            UserStakedInfo storage userStakedInfo = userStakedInfos[i];
            if(!userStakedInfo.claimed && curRound > userStakedInfo.round){
                DepositInfo storage depositInfo = roundToDepositInfos[userStakedInfo.round];
                if(depositInfo.totalPower > 0
                 && depositInfo.totalDeposit > 0){
                     uint share = depositInfo.totalDeposit.mul(getTokenPower(userStakedInfo.tokenId)).div(depositInfo.totalPower);
                    if(markClaim){
                        userStakedInfo.claimed = true;
                        depositInfo.totalClaimed = depositInfo.totalClaimed.add(share);
                    }
                    totalRewards += share;
                }
            }
            return totalRewards;
        }
    }

    // Claim rewards
    function claimRewards() public override{
        // close round
        closeRound();

        uint unClaimedRewards = getAndMarkUnClaimedRewards(msg.sender, true);
        rewardContract.transfer(msg.sender, unClaimedRewards);

        emit ClaimReward(msg.sender,  unClaimedRewards);
    }

    // Get staked info
    function getDepositInfo() public view override returns(DepositInfo[] memory depositInfos){
        return depositInfos;
    }

    // Get deposit info by page
    function getDepositInfoByPage(uint pageSt, uint pageSz) public view override
     returns(DepositInfo[] memory ){
        DepositInfo[] memory retDepositInfos;
        if(pageSt < depositInfos.length){
            uint end = pageSt + pageSz;
            end = end > depositInfos.length?depositInfos.length : end;
            retDepositInfos = new DepositInfo[](end - pageSt);
            for(uint i = 0;pageSt < end; i++){
                retDepositInfos[i] = depositInfos[pageSt];
                pageSt++;
            } 
        }
        return depositInfo;
    }


    // Get user staked info
    function getUserStakedInfo(address user) public view override
    returns(UserStakedInfo[] memory userStaked){
        return stakedInfos[user];
    }

    function getUserStakedInfoByPage(address user,uint pageSt, uint pageSz)
     public view override returns(UserStakedInfo[] memory userStaked){
        UserStakedInfo[] memory retUserStakedInfos;
        UserStakedInfo[] storage userStakedInfos = stakedInfos[user];

        if(pageSt < userStakedInfos.length){
            uint end = pageSt + pageSz;
            end = end > userStakedInfos.length?userStakedInfos.length : end;
            retUserStakedInfos = new UserStakedInfo[](end - pageSt);
            for(uint i = 0;pageSt < end; i++){
                retUserStakedInfos[i] = userStakedInfos[pageSt];
                pageSt++;
            } 
        }

        return retUserStakedInfos;
     }

}
