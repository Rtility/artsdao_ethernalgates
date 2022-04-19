pragma solidity 0.8.11;

error ExceedsMaximumSupply();
error SupplyExceedingMaxSupply();
error TransferFailed();
error CallerIsContract();
error PresaleNotStarted();
error AddressNotEligibleForPresaleMint();
error CountExceedsAllowedMintCount();
error IncorrectEtherSent();
error PublicSaleNotStarted();
error TransactionExceedsMaxNFTsAllowedInPresale();

/// @author Hammad Ghazi
contract EthernalGatesReview is ERC721AQueryable, Ownable {
    using MerkleProof for bytes32[];

    enum SALE_STATUS {
        OFF,
        INVESTOR,
        VIP,
        WL,
        PUBLIC
    }

    SALE_STATUS public saleStatus;

    string private baseTokenURI;

    // Max Supply of Ethernal Gates
    uint256 public constant MAX_SUPPLY = 6000;

    // Holds max number of NFTs that can be minted at the moment
    uint256 public currentSupply = 2000;

    uint256 public presalePrice = 0.49 ether;
    uint256 public publicPrice = 0.59 ether;

    bytes32 public merkleRoot;

    // To store NFTs a particular address has minted in each whitelist phase
    struct MintCounts {
        uint16 investorMintCount;
        uint16 vipMintCount;
        uint16 wlMintCount;
    }

    mapping(address => MintCounts) public mintCounts;

    constructor(string memory baseURI)
        ERC721A("Ethernal Gates", "Ethernal Gates")
    {
        baseTokenURI = baseURI;
    }

    modifier soldOut(uint256 _count) {
        if (_totalMinted() + _count > currentSupply)
            revert ExceedsMaximumSupply();
        _;
    }

    // Admin only functions

    // To update sale status
    function setSaleStatus(SALE_STATUS _status) external onlyOwner {
        saleStatus = _status;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        baseTokenURI = baseURI;
    }

    function changePresalePrice(uint256 _presalePrice) external onlyOwner {
        presalePrice = _presalePrice;
    }

    function changePublicPrice(uint256 _publicPrice) external onlyOwner {
        publicPrice = _publicPrice;
    }

    // To increase the supply, can't exceed 6000
    function increaseSupply(uint256 _increaseBy) external onlyOwner {
        if (currentSupply + _increaseBy > MAX_SUPPLY)
            revert SupplyExceedingMaxSupply();
        unchecked {
            currentSupply += _increaseBy;
        }
    }

    function withdraw() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
    }

    // Set some Ethernal Gates aside
    function reserveEthernalGates(uint256 _count)
        external
        onlyOwner
        soldOut(_count)
    {
        mint(msg.sender, _count);
    }

    function airdrop(address[] memory _addresses, uint256 _count)
        external
        onlyOwner
        soldOut(_count * _addresses.length)
    {
        uint256 stop = _addresses.length;
        for (uint256 i; i != stop; ) {
            _mint(_addresses[i], _count, "", false);
            unchecked {
                i++;
            }
        }
    }

    // Getter functions

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function _startTokenId() internal pure virtual override returns (uint256) {
        return 1;
    }

    //Mint functions

    /**
     * @dev '_allowedCount' represents number of NFTs caller is allowed to mint in presale, and,
     * '_count' indiciates number of NFTs caller wants to mint in the transaction
     */
    function presaleMint(
        bytes32[] calldata _proof,
        uint256 _allowedCount,
        uint16 _count
    ) external payable soldOut(_count) {
        SALE_STATUS saleState = saleStatus;
        MintCounts memory mintCount = mintCounts[msg.sender];
        if (saleState == SALE_STATUS.OFF || saleState == SALE_STATUS.PUBLIC)
            revert PresaleNotStarted();
        if (
            !MerkleProof.verify(
                _proof,
                merkleRoot,
                keccak256(abi.encodePacked(msg.sender, _allowedCount))
            )
        ) revert AddressNotEligibleForPresaleMint();
        if (_count > _allowedCount) revert CountExceedsAllowedMintCount();
        if (msg.value < presalePrice * _count) revert IncorrectEtherSent();
        if (saleState == SALE_STATUS.INVESTOR) {
            if (_allowedCount < mintCount.investorMintCount + _count)
                revert TransactionExceedsMaxNFTsAllowedInPresale();
            mintCount.investorMintCount += _count;
        } else if (saleState == SALE_STATUS.VIP) {
            if (_allowedCount < mintCount.vipMintCount + _count)
                revert TransactionExceedsMaxNFTsAllowedInPresale();
            mintCount.vipMintCount += _count;
        } else {
            if (_allowedCount < mintCount.wlMintCount + _count)
                revert TransactionExceedsMaxNFTsAllowedInPresale();
            mintCount.wlMintCount += _count;
        }
        mintCounts[msg.sender] = mintCount;
        mint(msg.sender, _count);
    }

    // Public mint

    function publicMint(uint256 _count) external payable soldOut(_count) {
        if (saleStatus != SALE_STATUS.PUBLIC) revert PublicSaleNotStarted();
        if (msg.value < publicPrice * _count) revert IncorrectEtherSent();
        mint(msg.sender, _count);
    }

    function mint(address _addr, uint256 quantity) private {
        if (tx.origin != msg.sender) revert CallerIsContract();
        _mint(_addr, quantity, "", false);
    }
}
