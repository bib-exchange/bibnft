
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./library/FixedPoint.sol";
import "./library/IterableMapping.sol";

contract BIBDividend is OwnableUpgradeable{
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;

    event Initialized(
        IERC20Upgradeable indexed asset,
        uint256 dripRatePerSecond
    );

    event DripRateChanged(
        uint256 dripRatePerSecond
    );

    event Withdrawn(
        address indexed to,
        uint256 amount
    );

    struct ExState {
        uint128 lastExchangeRateMantissa;
        uint128 balance;
        uint256 totalClaim;
        uint256 unClaim;
        uint256 lastDividendPerShare;
    }

    event UserClaimed(
        address indexed user,
        uint256 newTokens
    );

    event NodeClaimed(
        address indexed user,
        uint256 newTokens
    );
    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    IERC20Upgradeable public asset;

    address public controller;
    address public dividendSetter;
    uint256 public dripRatePerSecond;
    uint256 public nodeRate = 20;
    // 线性释放
    uint112 public userExchangeRateMantissa;
    uint112 public nodeExchangeRateMantissa;
    uint32 public lastDripTimestamp;
    // 一次性释放
    uint256 public userDividendPerShare;
    uint256 public nodeDividendPerShare;
    uint256 public totalDividendsDistributed;
    // 用户状态
    uint256 public userTotalStake;
    uint256 public nodeTotalStake;
    mapping(address => ExState) public userStates;
    mapping(address => ExState) public nodeStates;

    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;
    mapping (address => uint256) public lastClaimTimes;
    uint256 public claimWait = 1 hours;
    uint256 public gasForProcessing = 300000;
    uint256 public immutable minimumTokenBalanceForDividends = 1e5 * (10**9);
    event ClaimWaitUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    
    function initialize (
        IERC20Upgradeable _asset,
        uint256 _dripRatePerSecond
    ) public initializer {
        __Ownable_init();
        lastDripTimestamp = _currentTime();
        asset = _asset;
        setDripRatePerSecond(_dripRatePerSecond);
        emit Initialized(
            asset,
            dripRatePerSecond
        );
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

    function distributeDividends(uint256 amount) external onlyDividendSetter {
        if (amount == 0 || nodeTotalStake.add(userTotalStake) == 0) return;
        uint256 _nodeAmount = amount.mul(nodeRate).div(100);
        if (nodeTotalStake > 0) {
            nodeDividendPerShare = _nodeAmount.div(nodeTotalStake).add(nodeDividendPerShare);
            totalDividendsDistributed = totalDividendsDistributed.add(_nodeAmount);
        }
        if (userTotalStake > 0) {
            userDividendPerShare = amount.sub(_nodeAmount).div(userTotalStake).add(userDividendPerShare);
            totalDividendsDistributed = totalDividendsDistributed.add(amount.sub(_nodeAmount));
        }
    }

    function drip() public returns (uint256) {
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
            nodeExchangeRateMantissa = uint256(nodeExchangeRateMantissa).add(nodeIndexDeltaMantissa).toUint112();
        }
        if (userTotalStake > 0) {
            uint256 userIndexDeltaMantissa = FixedPoint.calculateMantissa(allNewTokens.sub(nodeNewTokens), userTotalStake);
            userExchangeRateMantissa = uint256(userExchangeRateMantissa).add(userIndexDeltaMantissa).toUint112();
        }
        lastDripTimestamp = currentTimestamp.toUint32();
        return allNewTokens;
    }

    function userClaim(address user) public returns (uint256) {
        drip();
        _captureNewTokensForUser(userStates[user], user, userExchangeRateMantissa, userDividendPerShare);
        uint128 newTokens = _claim(userStates[user], user);
        emit UserClaimed(user, newTokens);
        return newTokens;
    }

    function nodeClaim(address user) public returns (uint256) {
        drip();
        _captureNewTokensForUser(nodeStates[user], user, nodeExchangeRateMantissa, nodeDividendPerShare);
        uint128 newTokens = _claim(nodeStates[user], user);
        emit NodeClaimed(user, newTokens);
        return newTokens;
    }

    function processAccount(address account, bool automatic) public returns (bool) {
        uint256 amount = userClaim(account).add(nodeClaim(account));

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

    function _claim(ExState storage userState, address user) private returns(uint128) {
        if (userState.unClaim == 0) {
            return 0;
        }
        uint256 _c = userState.unClaim;
        userState.unClaim = 0;
        userState.totalClaim = userState.totalClaim.add(_c);
        asset.transfer(user, _c);
        return _c.toUint128();
    }

    function setUserBalance(address user, uint256 amount) external onlyController {
        drip();
        _captureNewTokensForUser(userStates[user], user, userExchangeRateMantissa, userDividendPerShare);
        userTotalStake = userTotalStake.sub(userStates[user].balance).add(amount);
        userStates[user].balance = amount.toUint128();

        if(amount >= minimumTokenBalanceForDividends) {
            tokenHoldersMap.set(user, amount);
        }
        else {
            tokenHoldersMap.remove(user);
        }
        try process(gasForProcessing) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
            emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gasForProcessing, tx.origin);
        } 
        catch {}
    }

    function setNodeBalance(address nodeOwner, uint256 amount) external onlyController {
        drip();
        _captureNewTokensForUser(nodeStates[nodeOwner], nodeOwner, nodeExchangeRateMantissa, nodeDividendPerShare);
        nodeTotalStake = nodeTotalStake.sub(nodeStates[nodeOwner].balance).add(amount);
        nodeStates[nodeOwner].balance = amount.toUint128();
        
        tokenHoldersMap.set(nodeOwner, amount);
        try process(gasForProcessing) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
            emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gasForProcessing, tx.origin);
        } 
        catch {}
    }

    function _captureNewTokensForUser(ExState storage userState, address user, uint112 _exchangeRateMantissa, uint256 _dividendPerShare) private returns (uint128){
        if (_exchangeRateMantissa == userState.lastExchangeRateMantissa) {
            return 0;
        }
        uint256 deltaExchangeRateMantissa = uint256(_exchangeRateMantissa).sub(userState.lastExchangeRateMantissa);
        uint128 newTokens = FixedPoint.multiplyUintByMantissa(userState.balance, deltaExchangeRateMantissa).toUint128();
        userState.lastExchangeRateMantissa = _exchangeRateMantissa;
        userState.unClaim = userState.unClaim.add(newTokens);

        uint256 _dividend = uint256(userState.balance).mul(_dividendPerShare.sub(userState.lastDividendPerShare));
        userState.lastDividendPerShare = _dividendPerShare;
        userState.unClaim = userState.unClaim.add(_dividend);

        return uint256(newTokens).add(_dividend).toUint128();
    }

    function setDripRatePerSecond(uint256 _dripRatePerSecond) public onlyOwner {
        require(_dripRatePerSecond > 0, "TokenFaucet/dripRate-gt-zero");

        drip();
        dripRatePerSecond = _dripRatePerSecond;
        emit DripRateChanged(dripRatePerSecond);
    }

    function updateClaimWait(uint256 newClaimWait) public onlyOwner {
        require(newClaimWait >= 3600 && newClaimWait <= 86400, "Token_Dividend_Tracker: claimWait must be updated to between 1 and 24 hours");
        require(newClaimWait != claimWait, "Token_Dividend_Tracker: Cannot update claimWait to same value");
        emit ClaimWaitUpdated(newClaimWait, claimWait);
        claimWait = newClaimWait;
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(newValue != gasForProcessing, "Token: Cannot update gasForProcessing to same value");
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
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

        withdrawableDividends = userStates[account].unClaim.add(nodeStates[account].unClaim);
        totalDividends = userStates[account].totalClaim.add(nodeStates[account].totalClaim);

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
            rewards[i] = _getUserAllRewards(userStates[users[i]], _getUserCurrentExchageMantissa(), userDividendPerShare);
        }
    }

    function getNodesAllRewards(address[] calldata users) public view returns(uint256[] memory rewards) {
        rewards = new uint256[](users.length);
        for(uint256 i=0;i<users.length;i++){
            rewards[i] = _getUserAllRewards(nodeStates[users[i]], _getNodeCurrentExchageMantissa(), nodeDividendPerShare);
        }
    }

    function getUserUnClaim(address user) external view returns(uint256) {
        return _getUnClaim(userStates[user], _getUserCurrentExchageMantissa(), userDividendPerShare);
    }

    function getUsersUnClaim(address[] calldata users) external view returns(uint256[] memory unClaims) {
        for(uint256 i=0;i<users.length;i++){
            unClaims[i] = _getUnClaim(userStates[users[i]], _getUserCurrentExchageMantissa(), userDividendPerShare);
        }
    }

    function getNodeUnClaim(address user) external view returns(uint256) {
        return _getUnClaim(nodeStates[user], _getNodeCurrentExchageMantissa(), nodeDividendPerShare);
    }

    function getNodesUnClaim(address[] calldata users) external view returns(uint256[] memory unClaims) {
        for(uint256 i=0;i<users.length;i++){
            unClaims[i] = _getUnClaim(nodeStates[users[i]], _getNodeCurrentExchageMantissa(), nodeDividendPerShare);
        }
    }

    function _getUserAllRewards(ExState memory userState, uint112 _exchangeRateMantissa, uint256 _dividendPerShare) public pure returns(uint256) {
        uint256 _userUnClaim = _getUnClaim(userState, _exchangeRateMantissa, _dividendPerShare);
        return userState.totalClaim.add(_userUnClaim);
    }

    function _getUnClaim(ExState memory userState, uint112 _exchangeRateMantissa, uint256 _dividendPerShare) internal pure returns(uint256){
        if (_exchangeRateMantissa == userState.lastExchangeRateMantissa) {
            return userState.unClaim;
        }
        uint256 deltaExchangeRateMantissa = uint256(_exchangeRateMantissa).sub(userState.lastExchangeRateMantissa);
        uint256 _new = FixedPoint.multiplyUintByMantissa(userState.balance, deltaExchangeRateMantissa);
        uint256 _newDividend = _dividendPerShare.sub(userState.lastDividendPerShare).mul(userState.balance);
        return _newDividend.add(_new).add(userState.unClaim);
    }

    function _getNodeCurrentExchageMantissa() internal view returns(uint112) {
        uint256 newSeconds = _currentTime() - lastDripTimestamp;
        uint256 allNewTokens;
        allNewTokens = newSeconds.mul(dripRatePerSecond);
        uint256 nodeNewTokens = allNewTokens.mul(nodeRate).div(100);
        return _getCurrentExchangeMantissa(nodeExchangeRateMantissa, nodeTotalStake, nodeNewTokens);
    }

    function _getUserCurrentExchageMantissa() internal view returns(uint112) {
        uint256 newSeconds = _currentTime() - lastDripTimestamp;
        uint256 allNewTokens;
        allNewTokens = newSeconds.mul(dripRatePerSecond);
        uint256 nodeNewTokens = allNewTokens.mul(nodeRate).div(100);
        return _getCurrentExchangeMantissa(userExchangeRateMantissa, userTotalStake, allNewTokens.sub(nodeNewTokens));
    }

    function _getCurrentExchangeMantissa(uint112 _exchangeRateMantissa, uint256 _totalStake, uint256 _newTokens) internal pure returns (uint112) {
        uint256 _IndexDeltaMantissa = FixedPoint.calculateMantissa(_newTokens, _totalStake);
        return _IndexDeltaMantissa.add(_exchangeRateMantissa).toUint112();
    }


    function _currentTime() internal virtual view returns (uint32) {
        return block.timestamp.toUint32();
    }
}