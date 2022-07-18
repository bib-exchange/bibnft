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
    uint256 public mintPrice;
    uint256 public refundPeriod;
    bool isReveal;
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

    uint256 public    preSaleStartTime = 1662739200;//9月10日0时0分0秒
    uint256 public    saleStartTimeRound1 = 1663603200;//9月20日0时0分0秒
    uint256 public    saleStartTimeRound2 = 1664208000;//9月27日0时0分0秒
    uint256 public    saleStartTimeRound3 = 1664812800;//10月4日0时0分0秒
    uint256 public    saleStartTimeRound4 = 1665417600;//10月11日0时0分0秒
    uint256 public    saleStartTimeRound5 = 1666022400;//10月18日0时0分0秒

    address public deadwallet = 0x0000000000000000000000000000000000000000;//将代币打进这个地址就是销毁

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
    uint256 public constant maxPresaleUserMintAmount = 2;
    uint256 public constant maxPubicsaleUserMintAmount = 1;
    bytes32 public merkleRoot;

    mapping(uint256 => bool) public hasRefunded; // users can search if the NFT has been refunded
    mapping(uint256 => bool) public isOwnerMint; // if the NFT was freely minted by owner
    mapping(uint256 => SoccerStar) public cardProperty;
    mapping(address => SoccerStar[]) public userCardWallet;

    event UpdatesSaleStep(address newAddress, BlindBoxesType blindBoxes, uint256 tokenId, uint256 quantity);

    string private baseURI;

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function initialize(uint256 _mintPrice,uint256 _refundPeriod,address _paymentToken, bytes32 _merkleRoot) initializer public {
           merkleRoot = _merkleRoot;
           mintPrice = _mintPrice;
           refundPeriod = _refundPeriod;
           paymentToken = IERC20MintableBurnable(_paymentToken);
    }


    constructor() ERC721A("SoccerStarNft", "SS") {
        refundAddress = msg.sender;
        toggleRefundCountdown();
        remainingMint = totalSupply() - _numberMinted(msg.sender);
        alreadyMint = _numberMinted(msg.sender);
    }

    /**
    * @dev setPaused makes the contract paused or unpaused
     */
    function setPaused(bool val) public onlyOwner {
        _paused = val;
    }

    function setPreSaleStartTime(uint _preSaleStartTime) external onlyOwner {
        preSaleStartTime = _preSaleStartTime;
    }

    function setSaleStartTime1(uint _SaleStartTime) external onlyOwner {
        saleStartTimeRound1 = _SaleStartTime;
    }

    function setSaleStartTime2(uint _SaleStartTime) external onlyOwner {
        saleStartTimeRound2 = _SaleStartTime;
    }

    function setSaleStartTime3(uint _SaleStartTime) external onlyOwner {
        saleStartTimeRound3 = _SaleStartTime;
    }

    function setSaleStartTime4(uint _SaleStartTime) external onlyOwner {
        saleStartTimeRound4 = _SaleStartTime;
    }

    function setSaleStartTime5(uint _SaleStartTime) external onlyOwner {
        saleStartTimeRound5 = _SaleStartTime;
    }

    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }

    function reveal(uint256 tokenID, string memory _name,string memory _country,string memory _position, uint256 _starLevel, uint256 _gradient) public onlyOwner {
        
            cardProperty[tokenID] = SoccerStar(_name, _country, _position, _starLevel, _gradient);
    }

    //计算剩余mint的数量
    function caculateRemaining() view public onlyOwner returns (uint256) {
            return totalSupply() - _numberMinted(msg.sender);
    }

    function setRefundPeriod(uint256 _refundPeriod) public onlyOwner {
        refundPeriod = _refundPeriod;
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
        require(currentTime() >= preSaleStartTime, "Whitelist Sale has not started yet");
        require(currentTime() < preSaleStartTime + 1 days, "Whitelist Sale is finished");
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
         paymentToken.burnFrom(deadwallet, quantity * mintPrice);
    }

    function publicSaleMintRound1(BlindBoxesType _blindBoxes, uint256 quantity) external payable onlyWhenNotPaused callerIsUser {
        require(publicSaleActive, "Public sale is not active");
        require(currentTime() >= saleStartTimeRound1, "public Sale round1 has not started yet");
        require(currentTime() < saleStartTimeRound1 + 1 days, "public Sale round1 Sale is finished");
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

        paymentToken.burnFrom(deadwallet, quantity * mintPrice);
    }

    function publicSaleMintRound2(BlindBoxesType _blindBoxes, uint256 quantity) external payable onlyWhenNotPaused callerIsUser {
        require(publicSaleActive, "Public sale is not active");
        require(msg.value >= quantity * mintPrice, "Not enough eth sent");
        require(currentTime() >= saleStartTimeRound2, "public Sale round2 has not started yet");
        require(currentTime() < saleStartTimeRound2 + 1 days, "public Sale round2 Sale is finished");
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

        paymentToken.burnFrom(deadwallet, quantity * mintPrice);
       
    }

    function publicSaleMintRound3(BlindBoxesType _blindBoxes, uint256 quantity) external payable onlyWhenNotPaused callerIsUser {
        require(publicSaleActive, "Public sale is not active");
        require(currentTime() >= saleStartTimeRound3, "public Sale round3 has not started yet");
        require(currentTime() < saleStartTimeRound3 + 1 days, "public Sale round3 Sale is finished");
        require(sellingStep == Step.publicSaleMintRound3, "publicSaleMintRound3 sale is not activated");
        require(
            _numberMinted(msg.sender) + quantity <= maxPubicsaleUserMintAmount,
            "Over mint limit"
        );
        require(
            _totalMinted() + quantity <= maxMintSupply,
            "Max mint supply reached"
        );

        if (_blindBoxes == BlindBoxesType.normal) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND3_NORMAL, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.supers) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND3_SUPERS,"Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.legend){
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND3_LEGEND, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        }

        emit UpdatesSaleStep(msg.sender, _blindBoxes, _currentIndex - quantity, quantity);

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        paymentToken.burnFrom(deadwallet, quantity * mintPrice);
    }


    function publicSaleMintRound4(BlindBoxesType _blindBoxes, uint256 quantity) external payable onlyWhenNotPaused callerIsUser {
        require(publicSaleActive, "Public sale is not active");
        require(currentTime() >= saleStartTimeRound4, "public Sale round4 has not started yet");
        require(currentTime() < saleStartTimeRound4 + 1 days, "public Sale round4 Sale is finished");
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

        paymentToken.burnFrom(deadwallet, quantity * mintPrice);
    }

    function publicSaleMintRound5(BlindBoxesType _blindBoxes, uint256 quantity) external payable onlyWhenNotPaused callerIsUser {
        require(publicSaleActive, "Public sale is not active");
        require(currentTime() >= saleStartTimeRound5, "public Sale round5 has not started yet");
        require(currentTime() < saleStartTimeRound5 + 1 days, "public Sale round5 Sale is finished");
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

        paymentToken.burnFrom(deadwallet, quantity * mintPrice);
    }

    function ownerMint(uint256 quantity) external onlyOwner onlyWhenNotPaused {
        require(
            _totalMinted() + quantity <= maxMintSupply,
            "Max mint supply reached"
        );
        _safeMint(msg.sender, quantity);

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        paymentToken.burnFrom(deadwallet, quantity * mintPrice);

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            isOwnerMint[i] = true;
        }
    }

    function setStep(uint _step) external onlyOwner {
        sellingStep = Step(_step);
    }

    function refund(uint256[] calldata tokenIds) external {
        require(isRefundGuaranteeActive(), "Refund expired");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(msg.sender == ownerOf(tokenId), "Not token owner");
            require(!hasRefunded[tokenId], "Already refunded");
            require(!isOwnerMint[tokenId], "Freely minted NFTs cannot be refunded");
            hasRefunded[tokenId] = true;
            transferFrom(msg.sender, refundAddress, tokenId);
        }

        uint256 refundAmount = tokenIds.length * mintPrice;
        Address.sendValue(payable(msg.sender), refundAmount);
    }

    function getRefundGuaranteeEndTime() public view returns (uint256) {
        return refundEndTime;
    }

    function isRefundGuaranteeActive() public view returns (bool) {
        return (block.timestamp <= refundEndTime);
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


    function tokenURI(uint _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "URI query for nonexistent token");

        return string(abi.encodePacked(baseURI, _tokenId.toString(), ".json"));
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

    function toggleRefundCountdown() public onlyOwner {
        refundEndTime = block.timestamp + refundPeriod;
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