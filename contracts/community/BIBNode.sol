// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./interface/IBIBStaking.sol";
import "./interface/IStakedSoccerStarNft.sol";

contract BIBNode is PausableUpgradeable, OwnableUpgradeable, ERC721Upgradeable{
    using SafeMath for uint256;
    
    struct Node {
        address ownerAddress;
        uint256 cardNftId;
        uint256 createTime;
        uint256 upNode;
    }

    struct CardNFTFreeze {
        uint256 cardNftId;
        uint256 expireTime;
    }

    string public baseURI;
    // 球星卡质押合约地址
    IStakedSoccerStarNft public cardNFTStake;
    IBIBStaking public BIBStaking;
    // BIB token 合约地址
    IERC20Upgradeable public BIBToken;
    ERC721Upgradeable public soccerStarNft;
    // 节点凭证 NFT id => 节点详情
    mapping(uint256 => Node) public nodeMap;
    // 节点数组，存放节点凭证id
    uint256[] public nodeList;
    // 用户地址 -> 节点凭证 NFT id
    mapping(address => uint256) public ticketMap;
    // 球星卡 -> 用户地址
    mapping(uint256 => address) public cardNFTOwners;

    mapping(address => CardNFTFreeze) public cardNFTFreezeMap;
    mapping(uint256 => uint256[]) public subNodes; // 数量最多10个

    event CreateNode(
        address indexed user,
        uint256 indexed cardNFTId,
        uint256 bibAmount,
        uint256 ticketId
    );

    event UpgradeNode(
        address indexed user,
        uint256 indexed cardNFTId
    );

    event DisbandNode(
        address indexed user,
        uint256 indexed cardNFTId,
        uint256 ticketId
    );

    event NodeStaking(
        uint256 indexed fromTicketId,
        uint256 indexed ticketId,
        uint256 bibAmount
    );

    event NodeUnStaking(
        uint256 indexed fromTicketId,
        uint256 indexed ticketId,
        uint256 bibAmount
    );
    
    // 1. 创建和升级点时，需要转入用户球星卡，所以要提前将多张球星卡授权给该合约
    // 2. 升级球星卡，该方法应该在球星卡合约中，需要销毁旧卡
    // 3. 需要获取球星卡等级的接口。
    // 4. 
    function initialize(
        address _cardNFTStake, address _soccerStarNft, address _bibToken, address _bibStaking
        ) initializer public {
        cardNFTStake = IStakedSoccerStarNft(_cardNFTStake);
        soccerStarNft = ERC721Upgradeable(_soccerStarNft);
        BIBToken = IERC20Upgradeable(_bibToken);
        BIBStaking = IBIBStaking(_bibStaking);
        __ERC721_init("BIB NODE ERC 721", "BIBNode");
        __Pausable_init();
        __Ownable_init();
    }
     
    function createNode(uint256 _cardNFTId, uint256 _bibAmount, uint256 ticket) external {
        // 0. 判断调用者是否已经拥有节点
        // 1. 用户BIB资金冻结，冻结前检查用户可用余额
        // 2. 转入球星卡
        // 3. mint 节点凭证 NFT
        require(cardNFTStake.isStaked(_cardNFTId), "Card must be staked");
        address operator = _msgSender();
        // require(soccerStarNft.ownerOf(_cardNFTId) == operator, "NFT is not yours");
        require(balanceOf(operator) == 0, "Already have node");
        require(cardNFTOwners[_cardNFTId] == address(0), "Already registered");
        require(nodeMap[ticket].ownerAddress == address(0), "ticket is used");
        // TODO:: transfer card nft
        cardNFTOwners[_cardNFTId] = operator;
        Node storage node = nodeMap[ticket];
        node.ownerAddress = operator;
        node.cardNftId = _cardNFTId;
        node.createTime = _currentTime();
        _mint(operator, ticket);
        ticketMap[operator] = ticket;
        nodeList.push(ticket);
        BIBStaking.createNode(operator, ticket, _bibAmount);
        emit CreateNode(operator, _cardNFTId, _bibAmount, ticket);
    }
    
    function upgradeNode(uint256[] calldata _cardNFTIds) external {
        address operator = _msgSender();
        uint _ticket = ticketMap[operator];
        Node storage node = nodeMap[_ticket];
        require(node.createTime > 0, "You don't have node.");
        uint256 _cardNFTId = getCardNFTByAddress(operator);
        uint256 newCardNFTId = _ticket;
        // TODO:: 销毁球星卡并生成新的球星卡
        node.cardNftId = newCardNFTId;
        delete cardNFTOwners[_cardNFTId];
        cardNFTOwners[newCardNFTId] = operator;
        emit UpgradeNode(operator, newCardNFTId);
    }
    
    function disbandNode() external {
        // 解散节点
        address operator = _msgSender();
        uint256 _ticket = ticketMap[operator];
        Node storage node = nodeMap[_ticket];
        require(node.createTime > 0, "You don't have node.");
        uint256 _cardNFTId = getCardNFTByAddress(operator);
        // TODO：解除下级节点委托
        // TODO: 球星卡冻结7天
        // TODO: 代币冻结7天
        _burn(_ticket);
        delete ticketMap[operator];
        BIBStaking.disbandNode(operator, _ticket);
        uint256 index = nodeList.length;
        while(index > 0) {
            index--;
            if (nodeList[index] == _ticket) {
                nodeList[index] = nodeList[nodeList.length - 1];
                nodeList.pop();
                break;
            }
        }
        emit DisbandNode(operator, _cardNFTId, _ticket);
    }

    function changeStakeNode(uint256 _ticket) external{
        address operator = _msgSender();
        uint256 fromTicket = ticketMap[operator];
        if(nodeMap[fromTicket].upNode == _ticket) {
            return;
        }
        unStakeNode(nodeMap[fromTicket].upNode);
        stakeNode(_ticket);
    }

    function stakeNode(uint256 _ticket) public returns(bool) {
        require(nodeMap[_ticket].createTime > 0, "Node not exist");
        require(subNodes[_ticket].length < 10, "Node is full");
        address operator = _msgSender();
        uint256 fromTicket = ticketMap[operator];
        require(fromTicket != _ticket, "Cann't stake yourself");
        Node storage fromNode = nodeMap[fromTicket];
        require(fromNode.createTime > 0, "You don't have node.");
        subNodes[_ticket].push(fromTicket);
        fromNode.upNode = _ticket;
        uint256 stakingAmount = BIBStaking.nodeStake(fromTicket, _ticket);
        emit NodeStaking(fromTicket, _ticket, stakingAmount);
        return true;
    }

    function unStakeNode(uint256 _ticket) public returns(bool) {
        require(nodeMap[_ticket].createTime > 0, "Node not exist");
        require(subNodes[_ticket].length < 10, "Node is full");
        address operator = _msgSender();
        uint256 fromTicket = ticketMap[operator];
        Node storage fromNode = nodeMap[fromTicket];
        require(fromNode.createTime > 0, "You don't have node.");

        uint256 index = subNodes[_ticket].length;
        while(index > 0) {
            index--;
            if (subNodes[_ticket][index] == fromTicket) {
                subNodes[_ticket][index] = subNodes[_ticket][subNodes[_ticket].length - 1];
                subNodes[_ticket].pop();
                break;
            }
        }
        fromNode.upNode = 0;
        uint256 stakingAmount = BIBStaking.nodeUnStake(fromTicket, _ticket);
        emit NodeUnStaking(fromTicket, _ticket, stakingAmount);
        return true;
    }
    
    // 转让节点凭证
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        delete ticketMap[from];
        ticketMap[to] = tokenId;
        nodeMap[tokenId].ownerAddress = to;
        super._transfer(from, to, tokenId);
        BIBStaking.transferNodeSetUp(from, to, tokenId);
    }

    function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

    function getCardNFTByAddress(address user) public view returns(uint256) {
        return nodeMap[ticketMap[user]].cardNftId;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // TODO: 用户年化收益计算，用户在某个节点的待领取收益

    /**
     * @dev See {ERC721-_mint}.
     */
    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
    }

    /**
     * @dev See {ERC721-_burn}.
     */
    function burn(uint256 tokenId) public onlyOwner {
        _burn(tokenId);
    }

    function _currentTime() internal virtual view returns (uint256) {
        return block.timestamp;
    }
}
