// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../interfaces/IBIBStaking.sol";
import "../interfaces/ISoccerStarNft.sol";
import "../interfaces/IStakedSoccerStarNftV2.sol";

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
    IStakedSoccerStarNftV2 public cardNFTStake;
    IBIBStaking public BIBStaking;
    IERC20Upgradeable public BIBToken;
    ERC721Upgradeable public soccerStarNft;
    // node ticket id -> node detail
    mapping(uint256 => Node) public nodeMap;
    // node ticket id list
    uint256[] public nodeList;
    // user address -> node ticket id
    mapping(address => uint256) public ticketMap;
    // card nft -> user
    mapping(uint256 => address) public cardNFTOwners;

    mapping(uint256 => ISoccerStarNft.SoccerStar) public ticketProperty;
    mapping(uint256 => uint256[]) public subNodes; 
    uint256 public constant maxSubNodeCount = 10;

    address public constant BLACK_HOLE = address(0x0000000000000000000000000000000000000001);

    event CreateNode(
        address indexed user,
        uint256 indexed cardNFTId,
        uint256 bibAmount,
        uint256 ticketId
    );

    event UpgradeNode(
        address indexed user,
        uint256 indexed cardNFTId,
        uint256 starLevel
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

    function initialize(
        address _cardNFTStake, 
        address _soccerStarNft, 
        address _bibToken, 
        address _bibStaking
        ) reinitializer(1) public {
        cardNFTStake = IStakedSoccerStarNftV2(_cardNFTStake);
        soccerStarNft = ERC721Upgradeable(_soccerStarNft);
        BIBToken = IERC20Upgradeable(_bibToken);
        BIBStaking = IBIBStaking(_bibStaking);
        __ERC721_init("BIB NODE ERC 721", "BIBNode");
        __Pausable_init();
        __Ownable_init();
    }

    function isStakedAsNode(uint tokenId) external view returns(bool){
        return (address(0) != cardNFTOwners[tokenId]);
    }
     
    function createNode(uint256 _cardNFTId, uint256 _bibAmount, uint256 ticket) external {
        require(cardNFTStake.isStaked(_cardNFTId), "Card must be staked");
        address operator = _msgSender();
        require(cardNFTStake.getTokenOwner(_cardNFTId) == operator, "NFT is not yours");
        require(balanceOf(operator) == 0, "Already have node");
        require(cardNFTOwners[_cardNFTId] == address(0), "Already registered");
        require(nodeMap[ticket].ownerAddress == address(0), "ticket is used");
        cardNFTOwners[_cardNFTId] = operator;
        Node storage node = nodeMap[ticket];
        node.ownerAddress = operator;
        node.cardNftId = _cardNFTId;
        node.createTime = _currentTime();
        _mint(operator, ticket);
        ticketMap[operator] = ticket;
        nodeList.push(ticket);
        BIBStaking.createNode(operator, ticket, _bibAmount);
        ticketProperty[ticket] =ISoccerStarNft(address(soccerStarNft)).getCardProperty(_cardNFTId);
        emit CreateNode(operator, _cardNFTId, _bibAmount, ticket);
    }

    function cmpProperty (
    ISoccerStarNft.SoccerStar memory a, 
    ISoccerStarNft.SoccerStar memory b) internal pure returns(bool){
        return keccak256(bytes(a.name)) == keccak256(bytes(b.name))
        && keccak256(bytes(a.country)) == keccak256(bytes(b.country))
        && keccak256(bytes(a.position)) == keccak256(bytes(b.position))
        && a.gradient == b.gradient;
    }

    function validToken(uint base, uint[] memory tokensToValid) 
    internal view returns(bool){
        if(0 == tokensToValid.length){
            return false;
        }

        ISoccerStarNft tokenContract = ISoccerStarNft(address(soccerStarNft));
        ISoccerStarNft.SoccerStar memory baseProperty = tokenContract.getCardProperty(base);
        for(uint i = 0; i < tokensToValid.length; i++){
            if(!cmpProperty(baseProperty, tokenContract.getCardProperty(tokensToValid[i]))){
                return false;
            }
        }
        return true;
    }
    
    function upgradeNode(uint256[] calldata _cardNFTIds) external {
        address operator = _msgSender();
        uint _ticket = ticketMap[operator];
        Node storage node = nodeMap[_ticket];
        require(node.createTime > 0, "You don't have node.");
        uint256 _cardNFTId = getCardNFTByAddress(operator);

        ISoccerStarNft.SoccerStar memory cardInfo = ISoccerStarNft(address(soccerStarNft)).getCardProperty(_cardNFTId);
        require(cardInfo.starLevel == 3, "ONLY_STARLEVEL_THREE");
        cardNFTStake.updateStarlevel(_cardNFTId, (cardInfo.starLevel + 1));
        ticketProperty[_ticket].starLevel = cardInfo.starLevel + 1;

        // need the other 4 tokens share the same property
        require(_cardNFTIds.length == 4, "NEED_FOUR_TOKENS");
        require(validToken(_cardNFTId, _cardNFTIds), "NEED_SAME_TOKEN_PROPERTY");

        // burn all
        for(uint i = 0; i < _cardNFTIds.length; i++){
            soccerStarNft.transferFrom(msg.sender, BLACK_HOLE, _cardNFTIds[i]);
        }

        emit UpgradeNode(operator, _cardNFTId, (cardInfo.starLevel + 1));
    }
    
    function disbandNode() external {
        address operator = _msgSender();
        uint256 _ticket = ticketMap[operator];
        Node storage node = nodeMap[_ticket];
        require(node.createTime > 0, "You don't have node.");
        uint256 _cardNFTId = getCardNFTByAddress(operator);
        // TODO: 球星卡冻结7天
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
        delete cardNFTOwners[_cardNFTId];
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
        require(subNodes[_ticket].length < maxSubNodeCount, "Node is full");
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
        require(fromNode.upNode == _ticket, "Not your up node");

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

        // transfer staken ownership
        uint256 _cardNFTId = getCardNFTByAddress(from);
        cardNFTStake.transferOwnershipNFT(_cardNFTId, to);
    }

    function setCardNftStake(address _cardNftStake) external onlyOwner {
        require(_cardNftStake != address(0), 'Invalid address');
        cardNFTStake = IStakedSoccerStarNftV2(_cardNftStake);
    }

    function setCardNft(address _cardNft) external onlyOwner {
        require(_cardNft != address(0), 'Invalid address');
        soccerStarNft = ERC721Upgradeable(_cardNft);
    }

    function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

    function getCardNFTByAddress(address user) public view returns(uint256) {
        return nodeMap[ticketMap[user]].cardNftId;
    }

    function getTicketProperty(uint256 tokenId) public view
    returns(ISoccerStarNft.SoccerStar memory){
        return ticketProperty[tokenId];
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

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
