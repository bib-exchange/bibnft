// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/ISoccerStarNft.sol";
import "./ERC721A.sol";
import "../deps/Ownable.sol";
import {VersionedInitializable} from "../deps/VersionedInitializable.sol";
import {SafeMath} from "../lib/SafeMath.sol";
import {IBIBOracle} from "../interfaces/IBIBOracle.sol";
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

contract SoccerStarNft is ISoccerStarNft, ERC721A, Ownable, VersionedInitializable {
    using Strings for uint;
    using SafeMath for uint;

    uint constant VERSION = 1;
    
    IERC20 public bibContract;
    IERC20 public busdContract;
    IUniswapV2Router02 public router;

    //URI of the NFTs when revealed
    string public baseURI;
    //URI of the NFTs when not revealed
    string public notRevealedURI;
    //The extension of the file containing the Metadatas of the NFTs
    string public baseExtension = ".json";

    //Are the NFTs revealed yet ?
    bool public revealed = false;

    uint constant public ORACLE_PRECISION = 1e18;

    address constant public BLACK_HOLE = 0x0000000000000000000000000000000000000001;

    // _paused is used to pause the contract in case of an emergency
    bool public _paused;

    uint public maxMintSupply;

    uint constant public PRE_SELL_ROUND  = 0;
    uint constant public PUB_SELL_ROUND1 = 1;
    uint constant public PUB_SELL_ROUND2 = 2;
    uint constant public PUB_SELL_ROUND3 = 3;
    uint constant public PUB_SELL_ROUND4 = 4;
    uint constant public PUB_SELL_ROUND5 = 5;
    uint constant public MAX_ROUND = PUB_SELL_ROUND5;

    event BIBContractChanged(address sender, address oldValue, address newValue);
    event BUSDContractChanged(address sender, address oldValue, address newValue);
    event TreasuryChanged(address sender, address oldValue, address newValue);
    event SwapRouterChanged(address sender, address oldValue, address newValue);
    event ComposerChanged(address sender, address oldValue, address newValue);
    event SellTimeChanged(address sender, uint oldValue, uint newValue);
    event Changed(address sender, uint oldValue, uint newValue);

    address public composer;
    address public treasury;

    uint256 public maxPubicsaleUserMintAmount = 10;
    bytes32 public merkleRoot;

    mapping(uint256 => bool) public isOwnerMint; // if the NFT was freely minted by owner
    mapping(uint256 => SoccerStar) public cardProperty;

    // round->boxType->price
    mapping(uint=>mapping(BlindBoxesType=>uint)) public mintPriceTb;
    // round->boxType->amount
    mapping(uint=>mapping(BlindBoxesType=>uint)) public maxAmountTb;
    // round->boxType->maxAmount
    mapping(uint=>mapping(BlindBoxesType=>uint)) public mintAmountTb;
    mapping(address=>mapping(uint=>uint))        public mintAmountPerAddrTb;
    mapping(uint=>TimeInfo) public timeInfoTb;

    struct QuotaTracker {
        uint quota;
        uint used;
    }

    // track busd quota per public round
    mapping(uint=>QuotaTracker) public busdQuotaPerPubRoundTb;

    // track user quota at pre-round
    mapping(address=>QuotaTracker) public userQutaPreRoundTb;
    
    constructor()ERC721A("SoccerStarNft", "SCSTAR"){}

    function initialize(   
    uint _maxMintSupply, 
    address _bibContract,
    address _busdContract,
    address _treasury,
    address _router) public initializer{
        maxMintSupply = _maxMintSupply;
        bibContract = IERC20(_bibContract);
        busdContract = IERC20(_busdContract);
        treasury = _treasury;
        router = IUniswapV2Router02(_router);

        // set owner
        _owner = msg.sender;

        // set token info
        _name = "SoccerStarNft";
        _symbol = "SCSTAR";
        _currentIndex = _startTokenId();
    }

    modifier onlyWhenNotPaused {
        require(!_paused, "PAUSED");
        _;
    }

    function setComposer(address value) public onlyOwner{
        require(address(0) != value, "INVALID_ADDRESS");
        emit ComposerChanged(msg.sender, composer, value);
        composer = value;
    }

    modifier onlyComposer(){
        require(msg.sender == composer, "NEED_COMPOSER");
        _;
    }

    function  getRemainingAmount(uint round, BlindBoxesType boxType) public view returns(uint){
        return maxAmountTb[round][boxType].sub(mintAmountTb[round][boxType]);
    }

    function setBIBContract(address _bibContract) public onlyOwner{
        require(address(0) != _bibContract, "INVLID_ADDRESS");
        emit BIBContractChanged(msg.sender, address(bibContract), _bibContract);
        bibContract = IERC20(_bibContract);
    }

    function setTreasury(address _treasury) public onlyOwner{
        require(address(0) != _treasury, "INVLID_ADDRESS");
        emit TreasuryChanged(msg.sender, treasury, _treasury);
        treasury = _treasury;
    }

    function setSwapRouter(address _router) public onlyOwner{
        require(address(0) != _router, "INVLID_ADDRESS");
        emit SwapRouterChanged(msg.sender, address(router), _router);
        router = IUniswapV2Router02(_router);
    }

    function setBUSDContract(address _busdContract) public onlyOwner{
        require(address(0) != _busdContract, "INVLID_ADDRESS");
        emit BUSDContractChanged(msg.sender, address(busdContract), _busdContract);
        busdContract = IERC20(_busdContract);
    }

    function caculateBUSDAmount(uint bibAmount) public view returns(uint){
        // the price has ORACLE_PRECISION
        address[] memory path = new address[](2);
        path[0] = address(bibContract);
        path[1] = address(busdContract);
        return router.getAmountsOut(bibAmount, path)[1];
    }

   // only allow protocol related contract to mint
    function protocolMint() public override onlyComposer returns(uint tokenId){
        tokenId = _currentIndex;
        _mint(msg.sender, 1);
        require(msg.sender == ownerOf(tokenId), "PROTOCOL_MINT_FAILED");
    }

    // only allow protocol related contract to mint to burn
    function protocolBurn(uint tokenId) public onlyComposer override {
        require(msg.sender == ownerOf(tokenId), "TOKEN_NOT_BELLONG_TO_CALLER");
        _burn(tokenId);
        require(msg.sender != ownerOf(tokenId), "PROTOCOL_BRUN_FAILED");
    }

    // only allow protocol related contract to bind star property
    function protocolBind(uint tokenId, SoccerStar memory soccerStar) public override onlyComposer{
        require(msg.sender == ownerOf(tokenId), "TOKEN_NOT_BELLONG_TO_CALLER");
        require(cardProperty[tokenId].starLevel == 0, "TOKEN_REVEALED");
        cardProperty[tokenId] = soccerStar;
    }

    function addUserQuotaPreRoundBatch(address[] memory users, uint[] memory quotas) public override onlyOwner {
        require(users.length == quotas.length, "SHOULD_BE_SAME_LENGTH");
        for(uint i = 0; i < users.length; i++){
            userQutaPreRoundTb[users[i]].quota = quotas[i];
        }
    }

    function setUserQuotaPreRound(address user, uint quota) public override onlyOwner{
        userQutaPreRoundTb[user].quota = quota;
    }

    function getUserQuotaPreRound(address user) public override view returns(uint){
        return userQutaPreRoundTb[user].quota;
    }

    function getUserRemainningQuotaPreRound(address user) public view override returns(uint){
        return userQutaPreRoundTb[user].quota.sub(userQutaPreRoundTb[user].used);
    }

    function setBUSDQuotaPerPubRound(uint round, uint quota) public override onlyOwner{
        require(isPublicRound(round), "NOT_PUBLIC_ROUND");
        busdQuotaPerPubRoundTb[round].quota = quota;
    }

    function getBUSDQuotaPerPubRound(uint round) public view override returns(uint){
        require(isPublicRound(round), "NOT_PUBLIC_ROUND");
        return busdQuotaPerPubRoundTb[round].quota;
    }

    function getBUSDUsedQuotaPerPubRound(uint round) public view override returns(uint){
        require(isPublicRound(round), "NOT_PUBLIC_ROUND");
        return busdQuotaPerPubRoundTb[round].used;
    }

    function getBUSDRemainningQuotaPerPubRound(uint round) public view returns(uint){
        require(isPublicRound(round), "NOT_PUBLIC_ROUND");
        return busdQuotaPerPubRoundTb[round].quota.sub(busdQuotaPerPubRoundTb[round].used);
    }
    
    /**
    * @dev setPaused makes the contract paused or unpaused
     */
    function setPaused(bool val) public onlyOwner {
        _paused = val;
    }

    function setMaxMintAmount(uint round, BlindBoxesType boxType, uint amount) public onlyOwner{
        maxAmountTb[round][boxType] = amount;
    }

    function getMaxMintAmount(uint round, BlindBoxesType boxType) public view returns(uint){
        return maxAmountTb[round][boxType];
    }

    function setSellTime(uint round, uint _startTime, uint _endTime, uint _revealTime) public onlyOwner {
        require(round <= MAX_ROUND, "INVLID_ROUND");
        require(_startTime >= block.timestamp, "INVLID_START_TIME");
        require(_endTime >= _startTime, "INVLID_END_TIME");
        require(_revealTime >= _endTime, "INVLID_END_TIME");

        timeInfoTb[round] = TimeInfo({
            startTime: _startTime,
            endTime: _endTime,
            revealTime: _revealTime
        });
    }

    function getSellTime(uint round) public view returns (uint){
        return timeInfoTb[round].startTime;
    }

    function setMaxMintSupply(uint _maxMintSupply) public onlyOwner{
        maxMintSupply = _maxMintSupply;
    }

    function getMaxMintSupply() public view returns(uint){
        return maxMintSupply;
    }

    function setMaxAmountPerAddress(uint _amount) public onlyOwner{
        maxPubicsaleUserMintAmount = _amount;
    }

    function getMaxAmountPerAddress() public view returns(uint){
        return maxPubicsaleUserMintAmount;
    }

    function setMintPrice(uint round, uint256 _mintPrice, BlindBoxesType boxType) public onlyOwner {
        require(round<= MAX_ROUND, "INVLID_ROUND");
        mintPriceTb[round][boxType] = _mintPrice;
    }

    function getMintPrice(uint round, BlindBoxesType boxType) public view returns(uint){
        return mintPriceTb[round][boxType];
    }

    function setMerkleRoot(bytes32 _root) external onlyOwner {
        merkleRoot = _root;
    }

    function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

     /**
    * @notice Allows to set the revealed variable to true
    **/
    function reveal(bool _revealed) external onlyOwner{
        revealed = _revealed;
    }

    function getCardProperty(uint256 tokenId) public view override
    returns(SoccerStar memory){
        return cardProperty[tokenId];
    }

   function updateProperty(uint[] memory tokenIds, SoccerStar[] memory _soccerStars)
        external
        onlyOwner{
        require(tokenIds.length == _soccerStars.length, "NEED_SAME_LENGTH");
        for(uint i = 0; i < _soccerStars.length; i++){
            require(cardProperty[tokenIds[i]].starLevel == 0, "TOKEN_REVEALED");
            cardProperty[tokenIds[i]] = _soccerStars[i];
        }
    }

    function isRoundOpen(uint round) public view returns(bool){
        TimeInfo storage timeInfo = timeInfoTb[round]; 
        return (currentTime() >= timeInfo.startTime) 
        && (currentTime() <= timeInfo.endTime);
    }

    function preSellMint(uint256 quantity)
        external
        payable
        onlyWhenNotPaused{
        require(isRoundOpen(PRE_SELL_ROUND), "PRE_SELL_ROUND_NOT_OPENED");
        require(getUserRemainningQuotaPreRound(msg.sender) >= quantity, "USER_HAS_NO_QUOTA");
        require(
           getRemainingAmount(PRE_SELL_ROUND,BlindBoxesType.presale) >=  quantity,
            "EXCEED_MAX_MINT_AMOUNT"
        );

        // burn bib tokens
        uint sales = quantity.mul(getMintPrice(PRE_SELL_ROUND, BlindBoxesType.presale));
        bibContract.transferFrom(msg.sender, BLACK_HOLE, sales);

        _safeMint(msg.sender, quantity);

        mintAmountTb[PRE_SELL_ROUND][BlindBoxesType.presale] = mintAmountTb[PRE_SELL_ROUND][BlindBoxesType.presale].add(quantity);
        
        // deducate user presell quota
        userQutaPreRoundTb[msg.sender].used = userQutaPreRoundTb[msg.sender].used.add(quantity);

        emit Mint(msg.sender, 
        PRE_SELL_ROUND,
        BlindBoxesType.presale, 
        _currentIndex.sub(quantity), 
        quantity,
        PayMethod.PAY_BIB,
        sales);
    }

    function isPublicRound(uint round) public pure returns(bool){
        return (round >= PUB_SELL_ROUND1) && (round <= PUB_SELL_ROUND5);
    }

    function getPubicRoundMintAmountByUser(address user, uint round) public view returns(uint){
        return mintAmountPerAddrTb[user][round];
    }

    function publicSellMint(
    uint round, 
    BlindBoxesType boxType, 
    uint256 quantity, 
    PayMethod payMethod) public onlyWhenNotPaused  {
        require(isPublicRound(round), "NOT_PUBLIC_ROUND_NUM");
        require(isRoundOpen(round), "ROUND_NOT_OPEN");
        require(boxType != BlindBoxesType.presale, "PRESALE_BOX_NOT_ALLOWED");

        // check constraint per address 
        require(getPubicRoundMintAmountByUser(msg.sender, round).add(quantity) <= getMaxAmountPerAddress(),
                "EXCEED_ADDRESS_MAX_MINT_AMOUNT");
        // check constraint per round && box type 
        require(getRemainingAmount(round, boxType) >=  quantity,
                "EXCEED_MAX_MINT_AMOUNT");

        uint sales = quantity.mul(getMintPrice(round, boxType));
        if(payMethod == PayMethod.PAY_BIB){
            // burn out bib
            bibContract.transferFrom(msg.sender, BLACK_HOLE, sales);
        } else {
            //check BUSD quota
            require(getBUSDRemainningQuotaPerPubRound(round) >= quantity, "EXCEED_MAX_BUSD_QUOTA");
            sales = caculateBUSDAmount(sales);

            // transfer to treasury
            busdContract.transferFrom(msg.sender, treasury, sales);

            // update used quota
            busdQuotaPerPubRoundTb[round].used = busdQuotaPerPubRoundTb[round].used.add(quantity);
        }
        _safeMint(msg.sender, quantity);

        mintAmountTb[round][boxType] = mintAmountTb[round][boxType].add(quantity);
        mintAmountPerAddrTb[msg.sender][round] = mintAmountPerAddrTb[msg.sender][round].add(quantity);

        emit Mint(msg.sender, 
        round,
        boxType, 
        _currentIndex.sub(quantity), 
        quantity,
        payMethod,
        sales);
     }

    function ownerMint(uint256 quantity) external onlyOwner onlyWhenNotPaused {
        require(
            _totalMinted() + quantity <= getMaxMintSupply(),
            "MAX_SUPPLY_REACHED"
        );

         _safeMint(msg.sender, quantity);

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            isOwnerMint[i] = true;
        }

        emit Mint(msg.sender,
        PRE_SELL_ROUND, 
        BlindBoxesType.presale, 
        _currentIndex.sub(quantity), 
        quantity,
        PayMethod.PAY_BIB,
        0);
    }

    function currentTime() public view returns(uint) {
        return block.timestamp;
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function tokenURI(uint _nftId) public view override(ERC721A) returns (string memory) {
        require(_exists(_nftId), "This NFT doesn't exist.");
        if(revealed == false) {
            return notRevealedURI;
        }
        
        string memory currentBaseURI = _baseURI();
        return 
            bytes(currentBaseURI).length > 0 
            ? string(abi.encodePacked(currentBaseURI, _nftId.toString(), baseExtension))
            : "";
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setNotRevealURI(string memory _notRevealedURI) external onlyOwner {
        notRevealedURI = _notRevealedURI;
    }

    function _leaf(address _account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account));
    }

    function _isAllowlisted(
        address _account,
        bytes32[] calldata _proof,
        bytes32 _root
    ) internal pure returns (bool) {
        return MerkleProof.verify(_proof, _root, _leaf(_account));
    }

    function getRevision() internal pure override returns (uint256){
        return VERSION;
    }
}