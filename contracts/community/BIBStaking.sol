
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../interfaces/IBIBNode.sol";
import "../interfaces/IBIBDividend.sol";
import "../interfaces/ISoccerStarNft.sol";
import "../lib/StructuredLinkedList.sol";

contract BIBStaking is PausableUpgradeable, OwnableUpgradeable {
    using SafeMath for uint256;
    using StructuredLinkedList for StructuredLinkedList.List;
    
    struct BIBFreeze {
        uint256 amount;
        uint256 expireTime;
    }
    struct Node {
        uint256 stakingAmount;
        uint256 expireTime;
        address owner;
    }

    StructuredLinkedList.List list;
    IBIBNode public BIBNode;
    // BIB token address
    IERC20Upgradeable public BIBToken;
    IBIBDividend public BIBDividend;
    ISoccerStarNft public soccerStarNft;
    
    uint256 public freezeTime = 7 days;
    uint256 public stakeCapTimes = 50;
    uint256 public topNodeCount = 30;
    uint256[] public nodeWigth = [100, 90, 80, 72];
    mapping(uint256 => uint256) public maxSetupAmount;
    // user -> stake node list
    mapping(address => uint256[]) public stakeNodesMap;
    mapping(address => BIBFreeze[]) public userFreezeMap;
    // node -> stake user list
    mapping(uint256 => address[]) public nodeStakedUsers;
    mapping(uint256 => mapping(address => uint256)) public nodeStakedDetail;
    mapping(uint256 => Node) public nodeMap;
    
    uint256 public gasForProcessing = 300000;
    event UpdateMaxSetUp(uint256 indexed level, uint256 newMaxSetUp);
    event SuperNode(uint256 ticketId);
    event UnSuperNode(uint256 ticketId);
    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    event Staking(
        address indexed user,
        uint256 indexed ticketId,
        uint256 bibAmount
    );

    event UnStaking(
        address indexed user,
        uint256 indexed ticketId,
        uint256 bibAmount
    );

    modifier onlyNode {
        require(msg.sender == address(BIBNode), "ONLY_NODE");
        _;
    }

    function initialize(
        address _bibToken,address _bibNode, address _bibDividend, address _soccerStarNft
        ) initializer public {
        BIBToken = IERC20Upgradeable(_bibToken);
        BIBNode = IBIBNode(_bibNode);
        BIBDividend = IBIBDividend(_bibDividend);
        soccerStarNft = ISoccerStarNft(_soccerStarNft);
        __Pausable_init();
        __Ownable_init();
        maxSetupAmount[3] = 200000*10**18;
        maxSetupAmount[4] = 2000000*10**18;
    }

    function createNode(address operator, uint256 _ticket, uint256 _bibAmount) external onlyNode {
        Node storage node = nodeMap[_ticket];
        require(node.stakingAmount == 0, "Node is exist");
        require(getAvailableAmount(operator) >= _bibAmount, "Insufficient balance");
        node.stakingAmount = _bibAmount;
        node.owner = operator;
        nodeStakedUsers[_ticket].push(operator);
        stakeNodesMap[operator].push(_ticket);
        nodeStakedDetail[_ticket][operator] = _bibAmount;
        updataNodeWigth(_ticket);
        require(getNodeMaxStake(_ticket) >= node.stakingAmount, "Limit exceeded");
        BIBDividend.setUserBalance(operator, _ticket, getUserStakeAmount(operator));
    }

    function disbandNode(address operator, uint256 _ticket) external onlyNode {
        Node storage node = nodeMap[_ticket];
        require(node.stakingAmount >= 0, "Node is not exist");
        node.expireTime = _currentTime().add(freezeTime);
        node.stakingAmount = 0;
        updataNodeWigth(_ticket);
        BIBDividend.setUserBalance(operator, _ticket, getUserStakeAmount(operator));
    }

    function transferNodeSetUp(address from, address to, uint256 _ticket) external onlyNode {
        Node storage node = nodeMap[_ticket];
        require(node.stakingAmount >= 0, "Node is not exist");
        node.owner = to;
        nodeStakedDetail[_ticket][to] = nodeStakedDetail[_ticket][from];
        delete nodeStakedDetail[_ticket][from];
        updataNodeWigth(_ticket);
        BIBDividend.setUserBalance(from, _ticket, getUserStakeAmount(from));
        BIBDividend.setUserBalance(to, _ticket, getUserStakeAmount(to));
    }

    function nodeStake(uint256 _from, uint256 _to) external onlyNode returns(uint256){
        uint256 _amount = nodeMap[_from].stakingAmount;
        BIBDividend.setNodeBalance(nodeMap[_from].owner, _calcAmount(_amount, 0), _from, nodeWigth[0]);
        emit SuperNode(_from);
        if (isTopNode(_to)) {
            BIBDividend.setNodeBalance(nodeMap[_from].owner, _calcAmount(_amount, 1), _from, nodeWigth[1]);
            emit UnSuperNode(_from);
        }else {
            BIBDividend.setNodeBalance(nodeMap[_from].owner, _calcAmount(_amount, 3), _from, nodeWigth[3]);
            emit UnSuperNode(_from);
        }
        return nodeMap[_from].stakingAmount;
    }

    function nodeUnStake(uint256 _from, uint256 _to) external onlyNode returns(uint256){
        BIBDividend.setNodeBalance(nodeMap[_from].owner, _calcAmount(nodeMap[_from].stakingAmount, 1), _from, nodeWigth[1]);
        emit UnSuperNode(_from);
        return nodeMap[_from].stakingAmount;
    }

    function updateStake(uint256[] calldata _tickets, uint256[] calldata _bibAmounts) external {
        require(_tickets.length == _bibAmounts.length, "Invalid args");
        address operator = _msgSender();
        uint256 availableAmount = getAvailableAmount(operator);
        for(uint256 i=0;i<_tickets.length;i++){
            uint256 alreadyStake = nodeStakedDetail[_tickets[i]][operator];
            if (_bibAmounts[i] == alreadyStake) {
                continue;
            } else if (_bibAmounts[i] > alreadyStake) {
                uint256 _stakeAmount = _bibAmounts[i].sub(alreadyStake);
                require(availableAmount >= _stakeAmount, "Insufficient balance");
                _stake(operator, _tickets[i], _stakeAmount);
            } else if (_bibAmounts[i] < alreadyStake) {
                _unStake(operator, _tickets[i], alreadyStake.sub(_bibAmounts[i]));
            }
        }
        freeExpireStake(operator);
        try BIBDividend.process(gasForProcessing) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
            emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gasForProcessing, tx.origin);
        } 
        catch {}
    }

    function _stake(address operator, uint256 _ticket, uint256 _bibAmount) internal returns(bool) {
        Node storage node = nodeMap[_ticket];
        require(node.expireTime == 0, "Node not exist");
        if (nodeStakedDetail[_ticket][operator] == 0) {
            nodeStakedUsers[_ticket].push(operator);
            stakeNodesMap[operator].push(_ticket);
        }
        nodeStakedDetail[_ticket][operator] = nodeStakedDetail[_ticket][operator].add(_bibAmount);
        node.stakingAmount = node.stakingAmount.add(_bibAmount);
        require(getNodeCurrentMaxStake(_ticket) >= node.stakingAmount, "Limit exceeded");
        emit Staking(operator, _ticket, _bibAmount);
        updataNodeWigth(_ticket);
        BIBDividend.setUserBalance(operator, _ticket, getUserStakeAmount(operator));
        return true;
    }
    
    function _unStake(address operator, uint256 _ticket, uint256 _bibAmount) internal returns(bool) {
        Node storage node = nodeMap[_ticket];
        uint256 stakeAmount = nodeStakedDetail[_ticket][operator];
        if (stakeAmount == 0){
            return true;
        }
        require(stakeAmount >= _bibAmount, "Insufficient stake");
        if (operator == node.owner) {
            require(getNodeMinStake(_ticket) <= stakeAmount.sub(_bibAmount), "Min setup limit");
        }
        node.stakingAmount = node.stakingAmount.sub(_bibAmount);
        if (stakeAmount == _bibAmount) {
            address[] storage stakedUserList = nodeStakedUsers[_ticket];
            uint256 index = stakedUserList.length;
            while(index > 0) {
                index--;
                if (stakedUserList[index] == operator) {
                    stakedUserList[index] = stakedUserList[stakedUserList.length-1];
                    stakedUserList.pop();
                    break;
                }
            }
            delete nodeStakedDetail[_ticket][operator];
            uint256[] storage list = stakeNodesMap[operator];
            uint256 i = list.length;
            while (i > 0){
                i--;
                if (list[i] == _ticket){
                    list[i] = list[list.length-1];
                    list.pop();
                    break;
                }
            }
        } else {
            nodeStakedDetail[_ticket][operator] = stakeAmount.sub(_bibAmount);
        }
        userFreezeMap[operator].push(BIBFreeze({
            amount: _bibAmount,
            expireTime: _currentTime().add(freezeTime)
        }));
        emit UnStaking(operator, _ticket, _bibAmount);
        updataNodeWigth(_ticket);
        BIBDividend.setUserBalance(operator, _ticket, getUserStakeAmount(operator));
        return true;
    }

    function freeExpireStake(address _account) internal {
        BIBFreeze[] storage list = userFreezeMap[_account];
        uint256 i = list.length;
        while (i > 0){
            i--;
            if (list[i].expireTime < _currentTime()){
                list[i] = list[list.length-1];
                list.pop();
            }
        }
    }

    function setSoccerStarNft(address _soccerStarNft) external onlyOwner {
        soccerStarNft = ISoccerStarNft(_soccerStarNft);
    }

    function setNodeWeight(uint256[] memory _nodeWigth) external onlyOwner {
        require(_nodeWigth.length >=4, "Invalid config");
        nodeWigth = _nodeWigth;
    }
    function setTopNodeCount(uint256 c) external onlyOwner{
        topNodeCount = c;
    }
    function setStakeCapTimes(uint256 times) external onlyOwner {
        stakeCapTimes = times;
    }
    function setMaxSetupAmount(uint256 level, uint256 setupAmount) external onlyOwner {
        maxSetupAmount[level] = setupAmount;
        emit UpdateMaxSetUp(level, setupAmount);
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(newValue != gasForProcessing, "Same value");
        gasForProcessing = newValue;
    }
    
    function getAvailableAmount(address _account) public view returns(uint256) {
        return BIBToken.balanceOf(_account).sub(getFreezeAmount(_account));
    }

    function getFreezeAmount(address _account) public view returns(uint256) {
        uint256[] memory list = stakeNodesMap[_account];
        uint256 freezeAmount;
        for (uint256 i=0;i<list.length;i++){
            if(nodeMap[list[i]].expireTime == 0 || nodeMap[list[i]].expireTime >= _currentTime()) {
                freezeAmount = freezeAmount.add(nodeStakedDetail[list[i]][_account]);
            }
        }
        BIBFreeze[] memory flist = userFreezeMap[_account];
        for (uint256 i=0;i<flist.length;i++){
            if(flist[i].expireTime >= _currentTime()) {
                freezeAmount = freezeAmount.add(flist[i].amount);
            }
        }

        return freezeAmount;
    }

    function getUserStakeList(address _account) public view returns (uint256[] memory nodeList, uint256[] memory stakeDetail){
        nodeList = stakeNodesMap[_account];
        stakeDetail = new uint256[](nodeList.length);
        for (uint256 i=0;i<nodeList.length;i++){
            stakeDetail[i] = nodeStakedDetail[nodeList[i]][_account];
        }
    }

    function getUserStakeAmount(address _account) public view returns(uint256) {
        uint256[] memory list = stakeNodesMap[_account];
        uint256 _stakeAmount;
        for (uint256 i=0;i<list.length;i++){
            if(nodeMap[list[i]].expireTime == 0) {
                _stakeAmount = _stakeAmount.add(nodeStakedDetail[list[i]][_account]);
            }
        }
        return _stakeAmount;
    }

    function getNodeStakingList(uint256 _ticket) public view returns(address[] memory) {
        return nodeStakedUsers[_ticket];
    }

    function getNodeStakeAmount(uint256 _ticket) external view returns(uint256) {
        return nodeMap[_ticket].stakingAmount;
    }

    function getNodeMaxStake(uint256 _ticketId) public view returns(uint256) {
        uint256 _cardId = BIBNode.nodeMap(_ticketId).cardNftId;
        ISoccerStarNft.SoccerStar memory card = soccerStarNft.getCardProperty(_cardId);
        return maxSetupAmount[card.starLevel].mul(stakeCapTimes);
    }

    function getNodeMinStake(uint256 _ticketId) public view returns(uint256) {
        return nodeMap[_ticketId].stakingAmount.div(stakeCapTimes + 1);
    }

    function getNodeCurrentMaxStake(uint256 _ticketId) public view returns(uint256) {
        uint256 _max = getNodeMaxStake(_ticketId);
        address _owner = nodeMap[_ticketId].owner;
        uint256 _setup = nodeStakedDetail[_ticketId][_owner];
        uint256 _currentMaxStake = _setup.mul(stakeCapTimes + 1);
        return _max <= _currentMaxStake ? _max : _currentMaxStake;
    }

    function isTopNode(uint256 _ticketId) public view returns(bool) {
        if (list.sizeOf() < topNodeCount) return true;
        uint256 rank = list.getIndex(_ticketId);
        // rank start from 0
        return rank < topNodeCount;
    }

    function updataNodeWigth(uint256 _ticketId) private{
        uint256 rank = list.getIndex(_ticketId) + 1;
        list.remove(_ticketId);
        uint256 _amount = nodeMap[_ticketId].stakingAmount;
        uint256 p = list.getSortedSpot(address(this), _amount);
        list.insertAfter(p, _ticketId);
        address nodeOwner = nodeMap[_ticketId].owner;
        uint256 newRank = list.getIndex(_ticketId) + 1;
        if(newRank <= topNodeCount || list.sizeOf() <= topNodeCount) {
            BIBDividend.setNodeBalance(nodeOwner, _calcAmount(_amount, 0), _ticketId, nodeWigth[0]);
            emit SuperNode(_ticketId);
        } else if (newRank > topNodeCount) {
            BIBDividend.setNodeBalance(nodeOwner, _calcAmount(_amount, 2), _ticketId, nodeWigth[2]);
            emit UnSuperNode(_ticketId);
        }
        if (rank <= topNodeCount && newRank > topNodeCount) {
            uint256 e = list.getNodeByIndex(topNodeCount-1);
            BIBDividend.setNodeBalance(nodeMap[e].owner, _calcAmount(nodeMap[e].stakingAmount, 0), e, nodeWigth[0]);
            emit SuperNode(e);
        } else if (rank > topNodeCount && newRank <= topNodeCount) {
            uint256 e = list.getNodeByIndex(topNodeCount);
            BIBDividend.setNodeBalance(nodeMap[e].owner, _calcAmount(nodeMap[e].stakingAmount, 2), e, nodeWigth[2]);
            emit UnSuperNode(e);
        }
    }

    function _calcAmount(uint256 amount, uint256 level) internal view returns(uint256){
        return amount.mul(nodeWigth[level]).div(100);
    }

    function _currentTime() internal virtual view returns (uint256) {
        return block.timestamp;
    }

}