//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {SafeMath} from "../lib/SafeMath.sol";
import {SafeCast} from "../lib/SafeCast.sol";
import {ISoccerStarNft} from "../interfaces/ISoccerStarNft.sol";
import {IStakedSoccerStarNft} from "../interfaces/IStakedSoccerStarNft.sol";

contract StakedSoccerStarNft is IStakedSoccerStarNft, Ownable {
    using SafeMath for uint;
    using SafeCast for uint;

    event FrozenDurationChanged(uint oldValue, uint newValue);
    event RewardPeriodChanged(uint oldValue, uint newValue);
    event RewardStartChanged(uint oldValue, uint newValue);
    event RewardContractChanged(address oldValue, address newValue);
    event NftContractChanged(address oldValue, address newValue);

    IERC20 public rewardContract;
    IERC721 public nftContract;

    int constant public INVLID_ROUND = -1;
    uint public rewardPeriod = 1 days;
    uint public frozenDuration = 7 days;
    uint public rewardStart;
    uint public totalStaked;
    uint public totalPower;

    DepositInfo[] public depositInfos;

    mapping(address=>UserStakedInfo[]) public stakedInfos;

    // Keep a fast index to avoid too many times of loop
    mapping(uint=>UserStakedInfo) public tokenToUserStakedInfo;

    constructor(
        address _rewardContract,
        address _nftContract,
        uint _rewardPeriod,
        uint _rewardStart
        ){
        rewardContract = IERC20(_rewardContract);
        nftContract = IERC721(_nftContract);
        rewardPeriod = _rewardPeriod;
        rewardStart = _rewardStart;
    }

    modifier onlyContract(address cntr) {
        require(address(0) != cntr, "INVALID_ADDRESS");
        require(Address.isContract(cntr), "NOT_CONTRACT");
        _;
    }

    modifier onlyStarted(){
        require(isStakedStart(), "REWARD_NOT_START");
        _;
    }

    modifier ownToken(uint tokenId){
        require(msg.sender == nftContract.ownerOf(tokenId), "TOKEN_NOT_BELONG_TO_SENDER");
        _;
    }

    // check if staked start
    function isStakedStart() public view returns(bool){
        return rewardStart <= block.timestamp;
    }

   function setFrozenDuration(uint newValue) public onlyOwner {
        emit FrozenDurationChanged(frozenDuration, newValue);
        frozenDuration = newValue;
    }

    function setRewardPeroid(uint newValue) public onlyOwner {
        require(newValue >= 1 days,  "REWARD_PERIOD_TOO_SHORT");
        emit RewardPeriodChanged(rewardPeriod, newValue);
        rewardPeriod = newValue;
    }

    function setRewardStart(uint newValue) public onlyOwner {
        require(newValue >= block.timestamp, "REWARD_START_LESS_THAN_CURRENT");
        emit RewardStartChanged(rewardStart, newValue);
        rewardStart = newValue;
    }

    function setRewardContract(address newValue) public onlyOwner onlyContract(newValue){
        emit RewardContractChanged(address(rewardContract), newValue);
        rewardContract = IERC20(newValue);
    }

    function setNftContract(address newValue) public onlyOwner onlyContract(newValue){
        emit NftContractChanged(address(nftContract), newValue);
        nftContract = IERC721(newValue);
    }

      // deposit a specified funds to pool
    function deposit(uint amount) public override onlyStarted{
        require(amount > 0, "AMOUNT_TOOL_SMALL");
        
        (bool hasRound, uint round, DepositInfo memory roundInfo) = checkAndGetRound();
        if(!hasRound || (round > roundInfo.round)){
            // close old 
            if(hasRound){
                closeRound();
            }

            DepositInfo memory depositInfo = DepositInfo({
                round:round,
                totalDeposit:amount,
                totalStaked:0,
                totalPower:0,
                totalClaimed:0
            });
            depositInfos.push(depositInfo);
        }else {
            roundInfo.totalDeposit += amount;
            depositInfos[depositInfos.length - 1] = roundInfo;
        }

        rewardContract.transferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, round, amount);
    } 

    function getCurrentRound() public view override onlyStarted returns(uint round){
        return block.timestamp.sub(rewardStart).div(rewardPeriod);
    }

    function checkAndGetRound() public view  returns(bool, uint, DepositInfo memory){
        DepositInfo memory roundInfo;
        if(depositInfos.length <= 0){
            return (false, 0, roundInfo);
        }
        uint round = getCurrentRound();
        roundInfo = depositInfos[depositInfos.length - 1];
        require(round >= roundInfo.round, "INVALID_ROUND");
        return (true, round, roundInfo);
    }

    // close a reward period
    function closeRound() public onlyStarted override{
        (bool hasRound, uint round, DepositInfo memory roundInfo) = checkAndGetRound();
        if(hasRound && (round > roundInfo.round) ){
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
    function stake(uint tokenId) public override onlyStarted ownToken(tokenId){
        require(!isStaking(tokenId), "TOKEN_STAKING");

        // check if need to close the old round
        closeRound();

        totalStaked++;
        totalPower += getTokenPower(tokenId);

        UserStakedInfo memory userStakedInfo = UserStakedInfo({
            tokenId: tokenId,
            round: getCurrentRound(),
            unfrozenTime: 0,
            claimedRound: INVLID_ROUND
        });
        stakedInfos[msg.sender].push(userStakedInfo);
        tokenToUserStakedInfo[tokenId] = userStakedInfo;
        
        nftContract.transferFrom(msg.sender, address(this), tokenId);

        emit Stake(msg.sender, tokenId);
    }

    function getTokenPower(uint tokenId) public view returns(uint power){
        ISoccerStarNft.SoccerStar memory cardInfo = ISoccerStarNft(address(nftContract)).getCardProperty(tokenId);
        require(cardInfo.starLevel > 0, "CARD_UNREAL");
        // The power equation: power = gradient * 10 ^ (starLevel -1)
        return cardInfo.gradient.exp(cardInfo.starLevel.sub(1));
    }

    // user redeem one or more nft cards
    function redeem(uint tokenId) public override onlyStarted ownToken(tokenId){
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

        emit Redeem(msg.sender, tokenId);
    }

    // withdraw token after the unfrozen period
    function withdraw(uint tokenId) public override onlyStarted ownToken(tokenId){
        require(isWithdrawAble(tokenId), "TOKEN_NOT_WITHDRAWABLE");

        // check if need to close the old round
        closeRound();

        // delete from the fast index
        delete tokenToUserStakedInfo[tokenId];

        nftContract.transferFrom(address(this), msg.sender, tokenId);

        emit Withdraw(msg.sender, tokenId);
    }

    function getUnClaimedRewardsByToken(uint tokenId) public view override returns(uint){
        if(!isStaked(tokenId)){
            return 0;
        }

        if( 0 == depositInfos.length){
            return 0;
        }

        uint curRound = getCurrentRound();
        uint totalRewards = 0;

        UserStakedInfo storage userStakedInfo = tokenToUserStakedInfo[tokenId];
        if(curRound != userStakedInfo.round){

            // walk through from the last to the frist
            for(uint j = depositInfos.length - 1; j >= 0; ){
                
                DepositInfo storage depositInfo = depositInfos[j];

                if(depositInfo.round != curRound){
                    if(depositInfo.round.toInt() == userStakedInfo.claimedRound){
                        break;
                    }

                    if(depositInfo.totalPower > 0
                    && depositInfo.totalDeposit > 0){
                        totalRewards += depositInfo.totalDeposit.mul(getTokenPower(userStakedInfo.tokenId)).div(depositInfo.totalPower);
                    }
                }

                // avoid overflow
                if(j > 0){
                    j--;
                } else {
                    break;
                }
            }
        }
        return totalRewards;
    }

        // Get unclaimed rewards by a set of the specified tokens
    function getUnClaimedRewardsByTokens(uint[] memory tokenIds) public view override returns(uint[] memory amount){
        uint[] memory rewards = new uint[](tokenIds.length);
        for(uint i = 0; i < tokenIds.length; i++){
            rewards[i] = getUnClaimedRewardsByToken(tokenIds[i]);
        }
        return rewards;
    }

    function getUnClaimedRewards(address user) public override view returns(uint amount){
        uint totalRewards = 0;

        // go through to accurate the rewards
        UserStakedInfo[] storage userStakedInfos = stakedInfos[user];
        for(uint i = 0; i < userStakedInfos.length; i++){
            totalRewards += getUnClaimedRewardsByToken(userStakedInfos[i].tokenId);
        }

        return totalRewards;
    }

    // Get unclaimed rewards 
    function getAndMarkUnClaimedRewards(address user, bool markClaim)
     internal returns(uint amount){
        uint totalRewards = 0;
        uint curRound = getCurrentRound();

        if(0 == depositInfos.length){
            return 0;
        }

        // go through to accurate the rewards
        UserStakedInfo[] storage userStakedInfos = stakedInfos[user];
        for(uint i = 0; i < userStakedInfos.length; i++){

            UserStakedInfo storage userStakedInfo = userStakedInfos[i];
            
            int tailRound = INVLID_ROUND;

            if(curRound != userStakedInfo.round){

                // walk through from the last to the frist
                for(uint j = depositInfos.length - 1; j >= 0; ){
                    
                    DepositInfo storage depositInfo = depositInfos[j];

                    if(depositInfo.round != curRound){
                    
                        if(depositInfo.round.toInt() == userStakedInfo.claimedRound){
                            break;
                        }

                        // record the tail round
                        if(tailRound == INVLID_ROUND){
                            tailRound = depositInfo.round.toInt();
                        }

                        if(depositInfo.totalPower > 0
                        && depositInfo.totalDeposit > 0){
                            uint share = depositInfo.totalDeposit
                            .mul(getTokenPower(userStakedInfo.tokenId))
                            .div(depositInfo.totalPower);

                            if(markClaim){
                                depositInfo.totalClaimed = depositInfo.totalClaimed.add(share);
                            }
                            totalRewards += share;
                        }
                    }

                    // avoid overflow
                    if(j > 0){
                        j--;
                    } else {
                        break;
                    }
                }

                if(markClaim){
                    userStakedInfo.claimedRound = tailRound;
                }
            }
        }

        return totalRewards;
    }

    // Claim rewards
    function claimRewards() public onlyStarted override{
        // close round
        closeRound();

        uint unClaimedRewards = getAndMarkUnClaimedRewards(msg.sender, true);
        rewardContract.transfer(msg.sender, unClaimedRewards);

        emit ClaimReward(msg.sender,  unClaimedRewards);
    }

    // Get staked info
    function getDepositInfo() public view override returns(DepositInfo[] memory){
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
        return retDepositInfos;
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
