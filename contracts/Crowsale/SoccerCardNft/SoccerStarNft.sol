// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721A.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IERC20MintableBurnable is IERC20 {
    function mint(address, uint256) external;

    function burnFrom(address, uint256) external;
}

interface IERC721MintableBurnable is IERC721 {
    function safeMint(address, uint256) external;

    function burn(uint256) external;
}

contract SoccerStarNft is ERC721A, Ownable, Initializable {
    using Strings for uint;
    uint256 public constant maxMintSupply = 29930;
    uint256 public mintPresalePrice;
    uint256 public mintSale1Price;
    uint256 public mintSale2Price;
    uint256 public mintSale3Price;
    uint256 public mintSale4Price;
    uint256 public mintSale5Price;

    //URI of the NFTs when revealed
    string public baseURI;
    //URI of the NFTs when not revealed
    string public notRevealedURI;
    //The extension of the file containing the Metadatas of the NFTs
    string public baseExtension = ".json";

    //Are the NFTs revealed yet ?
    bool public revealed = false;
    IERC20MintableBurnable public paymentToken;

    uint private constant MAX_PRESALE = 4800;
    uint private constant MAX_PUBLIC_ROUND1_NORMAL = 1300;
    uint private constant MAX_PUBLIC_ROUND1_SUPERS = 460;
    uint private constant MAX_PUBLIC_ROUND1_LEGEND = 160;
    uint private constant MAX_PUBLIC_ROUND2_NORMAL = 1950;
    uint private constant MAX_PUBLIC_ROUND2_SUPERS = 690;
    uint private constant MAX_PUBLIC_ROUND2_LEGEND = 240;
    uint private constant MAX_PUBLIC_ROUND3_NORMAL = 2600;
    uint private constant MAX_PUBLIC_ROUND3_SUPERS = 920;
    uint private constant MAX_PUBLIC_ROUND3_LEGEND = 320;
    uint private constant MAX_PUBLIC_ROUND4_NORMAL = 3250;
    uint private constant MAX_PUBLIC_ROUND4_SUPERS = 1150;
    uint private constant MAX_PUBLIC_ROUND4_LEGEND = 400;
    uint private constant MAX_PUBLIC_ROUND5_NORMAL = 3900;
    uint private constant MAX_PUBLIC_ROUND5_SUPERS = 1380;
    uint private constant MAX_PUBLIC_ROUND5_LEGEND = 480;

    uint256 private    preSaleStartTime;
    uint256 private    saleStartTimeRound1;
    uint256 private    saleStartTimeRound2;
    uint256 private    saleStartTimeRound3;
    uint256 private    saleStartTimeRound4;
    uint256 private    saleStartTimeRound5;
    uint256 private    revealTime;

    uint256 private    preSaleEndTime;
    uint256 private    saleEndTimeRound1;
    uint256 private    saleEndTimeRound2;
    uint256 private    saleEndTimeRound3;
    uint256 private    saleEndTimeRound4;
    uint256 private    saleEndTimeRound5;

    address public deadwallet = 0x0000000000000000000000000000000000000000;//将代币打进这个地址就是销毁
    //Keep a track of the number of tokens per address
    mapping(address => uint) nftsPerWallet;

    // _paused is used to pause the contract in case of an emergency
    bool public _paused;

    enum Step {
        preSaleMint,
        publicSaleMintRound1,
        publicSaleMintRound2,
        publicSaleMintRound3,
        publicSaleMintRound4,
        publicSaleMintRound5,
        Reveal
    }

    Step public sellingStep;
    Step constant defaultStep = Step.preSaleMint;

    enum BlindBoxesType {
        presale,
        normal,
        supers,
        legend
    }
    BlindBoxesType public blindBoxes;
    BlindBoxesType constant defaultType = BlindBoxesType.presale;

     struct SoccerStar {
        string name;
        string country;
        string position;
        uint256 starLevel;//0=1star, 1=2star, 2=3star, 3=4star
        uint256 gradient;//T0=0, T1=1, T2=2, T3=3
    }

    SoccerStar[] public soccerStars;

    modifier onlyWhenNotPaused {
        require(!_paused, "Contract currently paused");
        
        _;
    }

    // Sale Status
    bool public publicSaleActive;
    bool public presaleActive;
    uint256 public refundEndTime;

    address public refundAddress;
    uint256 public remainingMint;
    uint256 public alreadyMint;
    uint256 public maxPresaleUserMintAmount = 3;
    uint256 public maxPubicsaleUserMintAmount = 10;
    bytes32 public merkleRoot;

    mapping(uint256 => bool) public hasRefunded; // users can search if the NFT has been refunded
    mapping(uint256 => bool) public isOwnerMint; // if the NFT was freely minted by owner
    mapping(uint256 => SoccerStar) public cardProperty;
    mapping(address => SoccerStar[]) public userCardWallet;

    event UpdatesSaleStep(address newAddress, BlindBoxesType blindBoxes, uint256 tokenId, uint256 quantity);

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function initialize(string memory _theBaseURI, string memory _notRevealedURI, bytes32 _merkleRoot) initializer public {
           merkleRoot = _merkleRoot;
           baseURI = _theBaseURI;
           notRevealedURI = _notRevealedURI;
    }

    constructor() ERC721A("SoccerStarNft", "SS") {
        refundAddress = msg.sender;
        alreadyMint = totalSupply();
    }

    /**
    * @dev setPaused makes the contract paused or unpaused
     */
    function setPaused(bool val) public onlyOwner {
        _paused = val;
    }

    function setMaxPresaleUserMintAmount(uint256 val) public onlyOwner {
        maxPresaleUserMintAmount = val;
    }

    function setMaxPubicsaleUserMintAmount(uint256 val) public onlyOwner {
        maxPubicsaleUserMintAmount = val;
    }

    function setSaleTime(uint _startTime, uint _endTime, uint _revealTime, uint round) external onlyOwner {

         if (round == 1) {
           preSaleStartTime = _startTime;
            preSaleEndTime = _endTime;
            revealTime = _revealTime;
        } else if (round == 2) {      
           saleStartTimeRound1 = _startTime;
           saleEndTimeRound1 = _endTime;
           revealTime = _revealTime;
        } else if (round == 3){     
           saleStartTimeRound2 = _startTime;
           saleEndTimeRound2 = _endTime;
           revealTime = _revealTime;
        } else if (round == 4){
           saleStartTimeRound3 = _startTime;
           saleEndTimeRound3 = _endTime;
           revealTime = _revealTime;
        } else if (round == 5) {
            saleStartTimeRound4 = _startTime;
            saleEndTimeRound4 = _endTime;
          revealTime = _revealTime;
        } else if (round == 6){     
           saleStartTimeRound5 = _startTime;
           saleEndTimeRound5 = _endTime;
           revealTime = _revealTime;
        }
        
    }

    function setMintPrePrice(uint256 _mintPrice) public onlyOwner {
        mintPresalePrice = _mintPrice;
    }

    function setMintSalePrice(uint256 _mintPrice, BlindBoxesType _blindBoxes,uint round) public onlyOwner {

        if (round == 1) {
           if (_blindBoxes == BlindBoxesType.normal) {

            mintSale1Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.supers) {
           
            mintSale1Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.legend){
            
            mintSale1Price = _mintPrice;
        }
        } else if (round == 2) {      
           if (_blindBoxes == BlindBoxesType.normal) {

            mintSale2Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.supers) {
           
            mintSale2Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.legend){
            
            mintSale2Price = _mintPrice;
        }
        } else if (round == 3){     
           if (_blindBoxes == BlindBoxesType.normal) {

            mintSale3Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.supers) {
           
            mintSale3Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.legend){
            
            mintSale3Price = _mintPrice;
        }
        } else if (round == 4){
           if (_blindBoxes == BlindBoxesType.normal) {

            mintSale4Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.supers) {
           
            mintSale4Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.legend){
            
            mintSale4Price = _mintPrice;
        }
        } else if (round == 5) {
           if (_blindBoxes == BlindBoxesType.normal) {

            mintSale4Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.supers) {
           
             mintSale4Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.legend){
            
            mintSale4Price = _mintPrice;
        }
        }
         
    }

     /**
    * @notice Allows to set the revealed variable to true
    **/
    function reveal() external onlyOwner{

        // require(currentTime() >= revealTime, "Whitelist reveal not start");
        revealed = true;
    }

    function getCardProperty(uint256 tokenId) public view override
    returns(SoccerStar memory){
        return cardProperty[tokenId];
    }


   function updateReveal(uint[] memory tokenIds, SoccerStar[] memory _soccerStars)
        external
        onlyOwner
    {
        require(tokenIds.length == _soccerStars.length, "NEED_SAME_LENGTH");
        for(uint i = 0; i < _soccerStars.length; i++){
            require(cardProperty[tokenIds[i]].starLevel == 0, "TOKEN_REVEALED");
            cardProperty[tokenIds[i]] = _soccerStars[i];
        }
    }


    //计算剩余mint的数量
    function caculatePreRemaining() view public returns (uint256) {
            return MAX_PRESALE - totalSupply();
    }

    function caculateRound1NormalRemaining() view public returns (uint256) {
            return MAX_PUBLIC_ROUND1_NORMAL - totalSupply();
    }

    function getUserCardWallet(address _user) public returns (SoccerStar[] memory) {
        return userCardWallet[_user];
    }

    function preSaleMint(uint256 quantity, bytes32[] calldata proof)
        external
        payable
        onlyWhenNotPaused
        callerIsUser
    {
        require(presaleActive, "Presale is not active");
        require(msg.value >= quantity * mintPresalePrice, "Not enough eth sent");
        require(currentTime() >= preSaleStartTime, "Whitelist Sale has not started yet");
        require(currentTime() < preSaleEndTime, "Whitelist Sale is finished");
        require(sellingStep == Step.preSaleMint, "Whitelist sale is not activated");
        require(
            _isAllowlisted(msg.sender, proof, merkleRoot),
            "Not on allow list"
        );
        require(
            _numberMinted(msg.sender) + quantity <= maxPresaleUserMintAmount,
            "Max Presale User Mint amount"
        );
        require(_totalMinted() + quantity <= MAX_PRESALE, "Max PRESALE mint supply");

        _safeMint(msg.sender, quantity);

        emit UpdatesSaleStep(msg.sender, BlindBoxesType.presale, _currentIndex - quantity, quantity);

        //_currentIndex - quantity is tokenid for

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        // EVENT：sender,presale,_currentIndex - quantity,quantitty，ramdomseed
         paymentToken.burnFrom(deadwallet, quantity * mintPresalePrice);
    }


    function publicSaleMint(BlindBoxesType _blindBoxes, uint256 quantity, uint round) external payable onlyWhenNotPaused callerIsUser {
        require(publicSaleActive, "Public sale is not active");

         if (round == 1) {
        require(msg.value >= quantity * mintSale1Price, "Not enough eth sent");
        require(currentTime() >= saleStartTimeRound1, "public Sale round1 has not started yet");
        require(currentTime() < saleEndTimeRound1, "public Sale round1 Sale is finished");
        require(sellingStep == Step.publicSaleMintRound1, "publicSaleMintRound1 sale is not activated");
        require(
            _numberMinted(msg.sender) + quantity <= maxPubicsaleUserMintAmount,
            "Over mint limit"
        );
        
        if (_blindBoxes == BlindBoxesType.normal) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND1_NORMAL, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.supers) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND1_SUPERS,"Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.legend){
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND1_LEGEND, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        }

        emit UpdatesSaleStep(msg.sender, _blindBoxes, _currentIndex - quantity, quantity);

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        paymentToken.burnFrom(deadwallet, quantity * mintSale1Price);
            
        } else if (round == 2) {
              require(msg.value >= quantity * mintSale2Price, "Not enough eth sent");
        require(currentTime() >= saleStartTimeRound2, "public Sale round2 has not started yet");
        require(currentTime() < saleEndTimeRound2, "public Sale round2 Sale is finished");
        require(sellingStep == Step.publicSaleMintRound2, "publicSaleMintRound2 sale is not activated");
        require(
            _numberMinted(msg.sender) + quantity <= maxPubicsaleUserMintAmount,
            "Over mint limit"
        );

         if (_blindBoxes == BlindBoxesType.normal) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND2_NORMAL, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.supers) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND2_SUPERS,"Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.legend){
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND2_LEGEND, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        }

        emit UpdatesSaleStep(msg.sender, _blindBoxes, _currentIndex - quantity, quantity);

          for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        paymentToken.burnFrom(deadwallet, quantity * mintSale2Price);

           
        } else if (round == 3){
        require(msg.value >= quantity * mintSale3Price, "Not enough eth sent");
        require(currentTime() >= saleStartTimeRound3, "public Sale round1 has not started yet");
        require(currentTime() < saleEndTimeRound3, "public Sale round1 Sale is finished");
        require(sellingStep == Step.publicSaleMintRound3, "publicSaleMintRound1 sale is not activated");
        require(
            _numberMinted(msg.sender) + quantity <= maxPubicsaleUserMintAmount,
            "Over mint limit"
        );
        
        if (_blindBoxes == BlindBoxesType.normal) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND1_NORMAL, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.supers) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND1_SUPERS,"Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.legend){
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND1_LEGEND, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        }

        emit UpdatesSaleStep(msg.sender, _blindBoxes, _currentIndex - quantity, quantity);

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        paymentToken.burnFrom(deadwallet, quantity * mintSale3Price);
            
        } else if (round == 4) {
             require(msg.value >= quantity * mintSale4Price, "Not enough eth sent");
        require(currentTime() >= saleStartTimeRound4, "public Sale round4 has not started yet");
        require(currentTime() < saleEndTimeRound4, "public Sale round4 Sale is finished");
        require(sellingStep == Step.publicSaleMintRound4, "publicSaleMintRound4 sale is not activated");
        require(
            _numberMinted(msg.sender) + quantity <= maxPubicsaleUserMintAmount,
            "Over mint limit"
        );

        if (_blindBoxes == BlindBoxesType.normal) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND4_NORMAL, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.supers) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND4_SUPERS,"Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.legend){
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND4_LEGEND, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        }

        emit UpdatesSaleStep(msg.sender, _blindBoxes, _currentIndex - quantity, quantity);

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        paymentToken.burnFrom(deadwallet, quantity * mintSale4Price);


        } else if (round == 5) {
            require(msg.value >= quantity * mintSale5Price, "Not enough eth sent");
        require(currentTime() >= saleStartTimeRound5, "public Sale round5 has not started yet");
        require(currentTime() < saleEndTimeRound5, "public Sale round5 Sale is finished");
        require(sellingStep == Step.publicSaleMintRound5, "publicSaleMintRound5 sale is not activated");
        require(
            _numberMinted(msg.sender) + quantity <= maxPubicsaleUserMintAmount,
            "Over mint limit"
        );

        if (_blindBoxes == BlindBoxesType.normal) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND5_NORMAL, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.supers) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND5_SUPERS,"Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.legend){
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND5_LEGEND, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        }

        emit UpdatesSaleStep(msg.sender, _blindBoxes, _currentIndex - quantity, quantity);
        
        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        paymentToken.burnFrom(deadwallet, quantity * mintSale5Price);
        
         }

     }

    function ownerMint(uint256 quantity) external onlyOwner onlyWhenNotPaused {
        require(
            _totalMinted() + quantity <= maxMintSupply,
            "Max mint supply reached"
        );
         _safeMint(msg.sender, quantity);

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            isOwnerMint[i] = true;
        }
    }

    function setStep(uint _step) external onlyOwner {
        sellingStep = Step(_step);
    }
// 需要识别用户付款但没有收到NFT的情况，自动回退Mint失败资金。
    function refund(uint256[] calldata tokenIds) public onlyOwner {

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(msg.sender == ownerOf(tokenId), "Not token owner");
            require(!hasRefunded[tokenId], "Already refunded");
            require(!isOwnerMint[tokenId], "Freely minted NFTs cannot be refunded");
            hasRefunded[tokenId] = true;
            transferFrom(msg.sender, refundAddress, tokenId);
        }

        uint256 refundAmount = tokenIds.length * mintPresalePrice;
        Address.sendValue(payable(msg.sender), refundAmount);
    }

    function getRefundGuaranteeEndTime() public view returns (uint256) {
        return refundEndTime;
    }

    function currentTime() internal view returns(uint) {
        return block.timestamp;
    }

    function withdraw() external onlyOwner {
        require(block.timestamp > refundEndTime, "Refund period not over");
        uint256 balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
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

    function setRefundAddress(address _refundAddress) external onlyOwner {
        refundAddress = _refundAddress;
    }

    function setMerkleRoot(bytes32 _root) external onlyOwner {
        merkleRoot = _root;
    }

    function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

    function setNotRevealURI(string memory _notRevealedURI) external onlyOwner {
        notRevealedURI = _notRevealedURI;
    }

    function togglePresaleStatus() external onlyOwner {
        presaleActive = !presaleActive;
    }

    function togglePublicSaleStatus() external onlyOwner {
        publicSaleActive = !publicSaleActive;
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
}