
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../lib/FixedPoint.sol";
import "../lib/IterableMapping.sol";
import "../lib/SafeMathInt.sol";

contract BIBDividend is OwnableUpgradeable{
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;

    event DripRateChanged(
        uint256 dripRatePerSecond
    );
    event NodeRateChange(uint256 nodeRate);

    event Withdrawn(
        address indexed to,
        uint256 amount
    );

    struct ExState {
        uint256 lastExchangeRateMantissa;
        uint256 balance;
        uint256 totalClaim;
        uint256 unClaim;
        uint256 lastDividendPerShare;
    }

    struct UserStake {
        uint256[] nodeList;
        mapping(uint256 => ExState) stakeDetail;
        uint256 unClaim;
        uint256 totalClaim;
    }

    event UserClaimed(
        address indexed user,
        uint256 newTokens
    );

    event NodeClaimed(
        address indexed user,
        uint256 newTokens
    );

    IERC20Upgradeable public asset;

    address public controller;
    address public dividendSetter;
    uint256 public dripRatePerSecond;
    uint256 public nodeRate;
    // drip per second
    uint256 public userExchangeRateMantissa;
    uint256 public nodeExchangeRateMantissa;
    uint32 public lastDripTimestamp;
    uint256 public totalDrip;
    // direct dividend
    uint256 public userDividendPerShare;
    uint256 public nodeDividendPerShare;
    uint256 public totalDividendsDistributed;
    // user -> node -> drip per second
    uint256 public userNodeTotalStake;
    uint256 public nodeTotalStake;
    // ticket -> node states for user
    mapping(uint256 => ExState) public userNodeStates;
    mapping(address => ExState) public nodeStates;

    mapping(uint256 => uint256) public nodeWeight;
    // user -> stake detail on node
    mapping(address => UserStake) public userStakeStates;

    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;
    mapping (address => uint256) public lastClaimTimes;
    uint256 public claimWait;
    uint256 public minimumTokenBalanceForDividends;
    event ClaimWaitUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    
    function initialize (
        IERC20Upgradeable _asset,
        uint256 _dripRatePerSecond
    ) public reinitializer(1) {
        __Ownable_init();
        lastDripTimestamp = _currentTime();
        asset = _asset;
        setDripRatePerSecond(_dripRatePerSecond);

        nodeRate = 20;
        minimumTokenBalanceForDividends = 1e5 * (10**9);
        claimWait = 1 hours;
    }

    function setController(address _cntr) external onlyOwner {
        require(address(0) != _cntr, "INVLID_ADDR");
        controller = _cntr;
    }

    modifier onlyController {
        require(msg.sender == controller, "ONLY_CONTROLLER");
        _;
    }

    function setDividendSetter(address _setter) external onlyOwner {
        require(address(0) != _setter, "INVLID_ADDR");
        dividendSetter = _setter;
    }

    modifier onlyDividendSetter {
        require(msg.sender == dividendSetter, "ONLY_Dividend Seeter");
        _;
    }

    modifier onlyControllerOrOwner {
        require(msg.sender == controller || msg.sender == owner(), "ONLY_CONTROLLER_OR_OWNER");
        _;
    }

    function withdrawTo(address to, uint256 amount) external onlyOwner {
        drip();
        uint256 assetTotalSupply = asset.balanceOf(address(this));
        require(amount <= assetTotalSupply, "Dividend/insufficient-funds");
        asset.transfer(to, amount);
        emit Withdrawn(to, amount);
    }

    function handleReceive(uint amount) public onlyDividendSetter {
        distributeDividends(amount);
    }

    function distributeDividends(uint256 amount) public onlyDividendSetter {
        if (amount == 0 || nodeTotalStake.add(userNodeTotalStake) == 0) return;
        uint256 _nodeAmount = amount.mul(nodeRate).div(100);
        if (nodeTotalStake > 0) {
            nodeDividendPerShare = _nodeAmount.div(nodeTotalStake).add(nodeDividendPerShare);
            totalDividendsDistributed = totalDividendsDistributed.add(_nodeAmount);
        }
        if (userNodeTotalStake > 0) {
            userDividendPerShare = amount.sub(_nodeAmount).div(userNodeTotalStake).add(userDividendPerShare);
            totalDividendsDistributed = totalDividendsDistributed.add(amount.sub(_nodeAmount));
        }
    }

    function drip() public returns (uint256) {
        // udpate exchange rate mantissa
        uint256 currentTimestamp = _currentTime();
        if (lastDripTimestamp == uint32(currentTimestamp)) {
            return 0;
        }
        uint256 newSeconds = currentTimestamp.sub(lastDripTimestamp);
        uint256 allNewTokens;
        allNewTokens = newSeconds.mul(dripRatePerSecond);
        uint256 nodeNewTokens = allNewTokens.mul(nodeRate).div(100);
        if (nodeTotalStake > 0) {
            uint256 nodeIndexDeltaMantissa = FixedPoint.calculateMantissa(nodeNewTokens, nodeTotalStake);
            nodeExchangeRateMantissa = uint256(nodeExchangeRateMantissa).add(nodeIndexDeltaMantissa);
        }
        if (userNodeTotalStake > 0) {
            uint256 userIndexDeltaMantissa = FixedPoint.calculateMantissa(allNewTokens.sub(nodeNewTokens), userNodeTotalStake);
            userExchangeRateMantissa = uint256(userExchangeRateMantissa).add(userIndexDeltaMantissa);
        }
        lastDripTimestamp = currentTimestamp.toUint32();
        totalDrip = totalDrip.add(allNewTokens);
        return allNewTokens;
    }

    function userClaim(address user) public returns (uint256) {
        drip();
        uint256[] storage list = userStakeStates[user].nodeList;
        uint256 newTokens = userStakeStates[user].unClaim;
        userStakeStates[user].unClaim = 0;
        for(uint256 _i=0;_i<list.length;_i++){
            // drip node exchange rate mantissa
            _captureNewTokensForUser(userNodeStates[list[_i]], userNodeStates[list[_i]].balance, userExchangeRateMantissa, userDividendPerShare);

            // set to user unclaim for every node
            ExState storage _userExState = userStakeStates[user].stakeDetail[list[_i]];
            _captureNewTokensForUser(_userExState, _userExState.balance.mul(nodeWeight[list[_i]]).div(100),
                userNodeStates[list[_i]].lastExchangeRateMantissa, userNodeStates[list[_i]].lastDividendPerShare);
            newTokens = _userExState.unClaim.add(newTokens);
            _userExState.unClaim = 0;
        }
        userStakeStates[user].totalClaim = userStakeStates[user].totalClaim.add(newTokens);
        asset.transfer(user, newTokens);
        emit UserClaimed(user, newTokens);
        return newTokens;
    }

    function nodeClaim(address user) public returns (uint256) {
        drip();
        _captureNewTokensForUser(nodeStates[user], nodeStates[user].balance, nodeExchangeRateMantissa, nodeDividendPerShare);

        if (nodeStates[user].unClaim == 0) {
            return 0;
        }
        uint256 newTokens = nodeStates[user].unClaim;
        nodeStates[user].unClaim = 0;
        nodeStates[user].totalClaim = nodeStates[user].totalClaim.add(newTokens);
        asset.transfer(user,newTokens);

        emit NodeClaimed(user, newTokens);
        return newTokens;
    }

    function processAccount(address account, bool automatic) public returns (bool) {
        uint256 amount = userClaim(account);

        if(amount > 0) {
            lastClaimTimes[account] = block.timestamp;
            return true;
        }
        return false;
    }
    
    function process(uint256 gas) public returns (uint256, uint256, uint256) {
        uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;
        if(numberOfTokenHolders == 0) {
            return (0, 0, lastProcessedIndex);
        }
        uint256 _lastProcessedIndex = lastProcessedIndex;
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        uint256 iterations = 0;
        uint256 claims = 0;

        while(gasUsed < gas && iterations < numberOfTokenHolders) {
            _lastProcessedIndex++;

            if(_lastProcessedIndex >= tokenHoldersMap.keys.length) {
                _lastProcessedIndex = 0;
            }

            address account = tokenHoldersMap.keys[_lastProcessedIndex];

            if(canAutoClaim(lastClaimTimes[account])) {
                if(processAccount(payable(account), true)) {
                    claims++;
                }
            }
            iterations++;
            uint256 newGasLeft = gasleft();
            if(gasLeft > newGasLeft) {
                gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
            }
            gasLeft = newGasLeft;
        }
        lastProcessedIndex = _lastProcessedIndex;
        return (iterations, claims, lastProcessedIndex);
    }

    /**
     * amount: user stake for this node
     */
    function setUserBalance(address user, uint256 ticketId, uint256 amount) external onlyController {
        drip();
        _captureNewTokensForUser(userNodeStates[ticketId], userNodeStates[ticketId].balance, userExchangeRateMantissa, userDividendPerShare);
        
        ExState storage _userExState = userStakeStates[user].stakeDetail[ticketId];
        _captureNewTokensForUser(_userExState,  _userExState.balance.mul(nodeWeight[ticketId]).div(100),
            userNodeStates[ticketId].lastExchangeRateMantissa, userNodeStates[ticketId].lastDividendPerShare);

        // update user node stake
        userNodeStates[ticketId].balance = userNodeStates[ticketId].balance.sub(_userExState.balance).add(amount);
        // update user node total stake
        uint256 _oldUserStake = _userExState.balance.mul(nodeWeight[ticketId]).div(100);
        uint256 _newUserStake = amount.mul(nodeWeight[ticketId]).div(100);
        userNodeTotalStake = userNodeTotalStake.sub(_oldUserStake).add(_newUserStake);
        // update user stake balance
        if(_userExState.balance == 0 && amount > 0) userStakeStates[user].nodeList.push(ticketId);
        _userExState.balance = amount;
        if (amount == 0) {
            delete userStakeStates[user].stakeDetail[ticketId];
            uint256[] storage list = userStakeStates[user].nodeList;
            uint256 index = list.length;
            while(index > 0) {
                index--;
                if (list[index] == ticketId) {
                    list[index] = list[list.length - 1];
                    list.pop();
                    break;
                }
            }
        }

        if(amount >= minimumTokenBalanceForDividends) {
            tokenHoldersMap.set(user, amount);
        }
        else {
            tokenHoldersMap.remove(user);
        }
    }

    function setNodeBalance(address nodeOwner, uint256 amount, uint256 ticketId, uint256 weight) external onlyController {
        drip();
        _captureNewTokensForUser(nodeStates[nodeOwner], nodeStates[nodeOwner].balance, nodeExchangeRateMantissa, nodeDividendPerShare);
        nodeTotalStake = nodeTotalStake.sub(nodeStates[nodeOwner].balance).add(amount);
        nodeStates[nodeOwner].balance = amount;

        if (nodeWeight[ticketId] != weight) {
            uint256 _oldNodeStake = userNodeStates[ticketId].balance.mul(nodeWeight[ticketId]).div(100);
            uint256 _newNodeStake = userNodeStates[ticketId].balance.mul(weight);
            userNodeTotalStake = userNodeTotalStake.sub(_oldNodeStake).add(_newNodeStake);
            nodeWeight[ticketId] = weight;
        }
        
        tokenHoldersMap.set(nodeOwner, amount);
    }

    function _captureNewTokensForUser(ExState storage userState, uint256 _balance, uint256 _exchangeRateMantissa, uint256 _dividendPerShare) private returns (uint256){
        if (_exchangeRateMantissa == userState.lastExchangeRateMantissa) {
            return 0;
        }
        uint256 deltaExchangeRateMantissa = uint256(_exchangeRateMantissa).sub(userState.lastExchangeRateMantissa);
        uint256 newTokens = FixedPoint.multiplyUintByMantissa(_balance, deltaExchangeRateMantissa);
        userState.lastExchangeRateMantissa = _exchangeRateMantissa;
        userState.unClaim = userState.unClaim.add(newTokens);

        uint256 _dividend = uint256(_balance).mul(_dividendPerShare.sub(userState.lastDividendPerShare));
        userState.lastDividendPerShare = _dividendPerShare;
        userState.unClaim = userState.unClaim.add(_dividend);

        return uint256(newTokens).add(_dividend);
    }

    function setDripRatePerSecond(uint256 _dripRatePerSecond) public onlyOwner {
        require(_dripRatePerSecond > 0, "TokenFaucet/dripRate-gt-zero");

        drip();
        dripRatePerSecond = _dripRatePerSecond;
        emit DripRateChanged(dripRatePerSecond);
    }

    function setNodeRate(uint256 _nodeRate) external onlyOwner {
        require(_nodeRate > 0, "TokenFaucet/nodeRate-gt-zero");
        drip();
        nodeRate = _nodeRate;
        emit NodeRateChange(nodeRate);
    }

    function updateClaimWait(uint256 newClaimWait) public onlyOwner {
        require(newClaimWait >= 3600 && newClaimWait <= 86400, "Token_Dividend_Tracker: claimWait must be updated to between 1 and 24 hours");
        require(newClaimWait != claimWait, "Token_Dividend_Tracker: Cannot update claimWait to same value");
        emit ClaimWaitUpdated(newClaimWait, claimWait);
        claimWait = newClaimWait;
    }

    function getLastProcessedIndex() public view returns(uint256) {
        return lastProcessedIndex;
    }

    function getNumberOfTokenHolders() public view returns(uint256) {
        return tokenHoldersMap.keys.length;
    }

    function getAccount(address _account)
        public view returns (
            address account,
            int256 index,
            int256 iterationsUntilProcessed,
            uint256 withdrawableDividends,
            uint256 totalDividends,
            uint256 lastClaimTime,
            uint256 nextClaimTime,
            uint256 secondsUntilAutoClaimAvailable) {
        account = _account;

        index = tokenHoldersMap.getIndexOfKey(account);

        iterationsUntilProcessed = -1;

        if(index >= 0) {
            if(uint256(index) > lastProcessedIndex) {
                iterationsUntilProcessed = index.sub(int256(lastProcessedIndex));
            }
            else {
                uint256 processesUntilEndOfArray = tokenHoldersMap.keys.length > lastProcessedIndex ?
                                                        tokenHoldersMap.keys.length.sub(lastProcessedIndex) :
                                                        0;
                iterationsUntilProcessed = index.add(int256(processesUntilEndOfArray));
            }
        }

        withdrawableDividends = userStakeStates[account].unClaim.add(nodeStates[account].unClaim);
        totalDividends = userStakeStates[account].totalClaim.add(nodeStates[account].totalClaim);

        lastClaimTime = lastClaimTimes[account];

        nextClaimTime = lastClaimTime > 0 ?
                                    lastClaimTime.add(claimWait) :
                                    0;

        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ?
                                                    nextClaimTime.sub(block.timestamp) :
                                                    0;
    }

    function getAccountAtIndex(uint256 index)
        public view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
        if(index >= tokenHoldersMap.size()) {
            return (address(0), -1, -1, 0, 0, 0, 0, 0);
        }

        address account = tokenHoldersMap.getKeyAtIndex(index);

        return getAccount(account);
    }

    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
        if(lastClaimTime > block.timestamp)  {
            return false;
        }
        return block.timestamp.sub(lastClaimTime) >= claimWait;
    }

    function getUsersAllRewards(address[] calldata users) public view returns(uint256[] memory rewards) {
        rewards = new uint256[](users.length);
        for(uint256 i=0;i<users.length;i++){
            rewards[i] = getUserUnClaim(users[i]).add(userStakeStates[users[i]].totalClaim);
        }
    }

    function getNodesAllRewards(address[] calldata users) public view returns(uint256[] memory rewards) {
        rewards = new uint256[](users.length);
        for(uint256 i=0;i<users.length;i++){
            rewards[i] = _getUserAllRewards(nodeStates[users[i]], _getNodeCurrentExchageMantissa(), nodeDividendPerShare);
        }
    }

    function getUsersUnClaim(address[] calldata users) external view returns(uint256[] memory unClaims) {
        unClaims = new uint256[](users.length);
        for(uint256 i=0;i<users.length;i++){
            unClaims[i] = getUserUnClaim(users[i]);
        }
    }

    function getUserUnClaim(address user) public view returns(uint256) {
        uint256 _currentExchangeMantissa = _getUserCurrentExchageMantissa();
        uint256[] storage list = userStakeStates[user].nodeList;
        uint256 newTokens = userStakeStates[user].unClaim;
        for(uint256 _i=0;_i<list.length;_i++){
            // set to user unclaim for every node
            ExState storage _userExState = userStakeStates[user].stakeDetail[list[_i]];
            uint256 _stakeBalance = _userExState.balance.mul(nodeWeight[list[_i]]).div(100);
            uint256 deltaExchangeRateMantissa = uint256(_currentExchangeMantissa).sub(_userExState.lastExchangeRateMantissa);
            uint256 _dripToken = FixedPoint.multiplyUintByMantissa(_stakeBalance, deltaExchangeRateMantissa);
            uint256 _dividend = uint256(_stakeBalance).mul(userDividendPerShare.sub(_userExState.lastDividendPerShare));
            newTokens = newTokens.add(_dripToken).add(_dividend);
        }
        return newTokens;
    }

    function getNodeUnClaim(address user) external view returns(uint256) {
        return _getUnClaim(nodeStates[user], _getNodeCurrentExchageMantissa(), nodeDividendPerShare);
    }

    function getNodesUnClaim(address[] calldata users) external view returns(uint256[] memory unClaims) {
        unClaims = new uint256[](users.length);
        for(uint256 i=0;i<users.length;i++){
            unClaims[i] = _getUnClaim(nodeStates[users[i]], _getNodeCurrentExchageMantissa(), nodeDividendPerShare);
        }
    }

    function getUserApr(address _user) external view returns(uint256) {
        if (userNodeTotalStake == 0) return 0;
        uint256 _userTotalStake = 0;
        uint256 _userStake = 0;
        uint256[] storage list = userStakeStates[_user].nodeList;
        for(uint256 _i=0;_i<list.length;_i++){
            ExState storage _userExState = userStakeStates[_user].stakeDetail[list[_i]];
            _userTotalStake = _userExState.balance.mul(nodeWeight[list[_i]]).div(100).add(_userTotalStake);
            _userStake = _userStake.add(_userExState.balance);
        }
        return _userTotalStake.div(userNodeTotalStake).mul(totalDrip.add(totalDividendsDistributed)).div(_userStake);
    }

    function _getUserAllRewards(ExState memory userState, uint256 _exchangeRateMantissa, uint256 _dividendPerShare) public pure returns(uint256) {
        uint256 _userUnClaim = _getUnClaim(userState, _exchangeRateMantissa, _dividendPerShare);
        return userState.totalClaim.add(_userUnClaim);
    }

    function _getUnClaim(ExState memory userState, uint256 _exchangeRateMantissa, uint256 _dividendPerShare) internal pure returns(uint256){
        uint256 _newDividend = _dividendPerShare.sub(userState.lastDividendPerShare).mul(userState.balance);
        if (_exchangeRateMantissa == userState.lastExchangeRateMantissa) {
            return userState.unClaim.add(_newDividend);
        }
        uint256 deltaExchangeRateMantissa = uint256(_exchangeRateMantissa).sub(userState.lastExchangeRateMantissa);
        uint256 _new = FixedPoint.multiplyUintByMantissa(userState.balance, deltaExchangeRateMantissa);
        return userState.unClaim.add(_new).add(_newDividend);
    }

    function _getNodeCurrentExchageMantissa() internal view returns(uint256) {
        uint256 newSeconds = _currentTime() - lastDripTimestamp;
        uint256 allNewTokens = newSeconds.mul(dripRatePerSecond);
        uint256 nodeNewTokens = allNewTokens.mul(nodeRate).div(100);
        return _getCurrentExchangeMantissa(nodeExchangeRateMantissa, nodeTotalStake, nodeNewTokens);
    }

    function _getUserCurrentExchageMantissa() internal view returns(uint256) {
        uint256 newSeconds = _currentTime() - lastDripTimestamp;
        uint256 allNewTokens = newSeconds.mul(dripRatePerSecond);
        uint256 nodeNewTokens = allNewTokens.mul(nodeRate).div(100);
        return _getCurrentExchangeMantissa(userExchangeRateMantissa, userNodeTotalStake, allNewTokens.sub(nodeNewTokens));
    }

    function _getCurrentExchangeMantissa(uint256 _exchangeRateMantissa, uint256 _totalStake, uint256 _newTokens) internal pure returns (uint256) {
        if(_totalStake == 0) return _exchangeRateMantissa;
        uint256 _IndexDeltaMantissa = FixedPoint.calculateMantissa(_newTokens, _totalStake);
        return _IndexDeltaMantissa.add(_exchangeRateMantissa);
    }

    function _calcAmount(uint256 amount, uint256 ticket) internal view returns(uint256){
        return amount.mul(nodeWeight[ticket]).div(100);
    }

    function _currentTime() internal virtual view returns (uint32) {
        return block.timestamp.toUint32();
    }
}