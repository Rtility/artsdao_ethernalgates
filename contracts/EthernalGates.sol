pragma solidity 0.8.11;

/// @author Hammad Ghazi
contract EthernalGates is ERC721A, Ownable {
    using MerkleProof for bytes32[];

    enum SALE_STATUS {
        OFF,
        INVESTOR,
        VIP,
        WL,
        PUBLIC
    }

    SALE_STATUS public saleStatus;

    string baseTokenURI;

    // Max Supply of Ethernal Gates
    uint256 public constant MAX_SUPPLY = 6000;

    // Holds max number of NFTs that can be minted at the moment
    uint256 public currentSupply = 2000;

    uint256 public presalePrice = 0.49 ether;
    uint256 public publicPrice = 0.59 ether;

    bytes32 public merkleRoot;

    // To store NFTs a particular address has minted in each whitelist phase
    mapping(address => uint256) public investorMintCount;
    mapping(address => uint256) public vipMintCount;
    mapping(address => uint256) public wlMintCount;

    constructor(string memory baseURI) ERC721A("Ethernal Gates", "Ethernal Gates") {
        setBaseURI(baseURI);
    }

    modifier soldOut(uint256 _count) {
        require(
            totalSupply() + _count <= currentSupply,
            "Transaction will exceed maximum available supply of Ethernal Gates"
        );
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

    function changePresalePrice(uint256 _presalePrice) external onlyOwner {
        presalePrice = _presalePrice;
    }

    function changePublicPrice(uint256 _publicPrice) external onlyOwner {
        publicPrice = _publicPrice;
    }

    // To increase the supply, can't exceed 6000
    function increaseSupply(uint256 _increaseBy) external onlyOwner {
        require(currentSupply + _increaseBy <= MAX_SUPPLY, "Cannot increase supply by more than 6000");
        currentSupply += _increaseBy;
    }

    function withdraw() external onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    // Set some Ethernal Gates aside
    function reserveEthernalGates(uint256 _count) external onlyOwner soldOut(_count) {
        mint(msg.sender, _count);
    }

    function airdrop(address[] memory _addresses, uint256 _count)
        external
        onlyOwner
        soldOut(_count * _addresses.length)
    {
        require(_addresses.length > 0, "No address found for airdrop");
        for (uint256 i; i < _addresses.length; i++) {
            require(_addresses[i] != address(0), "Can't airdrop to zero address");
            mint(_addresses[i], _count);
        }
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    // Getter functions

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function _startTokenId() internal view virtual override returns (uint256) {
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
        uint256 _count
    ) external payable soldOut(_count) {
        require(merkleRoot != 0, "No address is eligible for presale minting yet");
        require(saleStatus != SALE_STATUS.OFF || saleStatus != SALE_STATUS.PUBLIC, "Presale sale not started");
        require(
            MerkleProof.verify(_proof, merkleRoot, keccak256(abi.encodePacked(msg.sender, _allowedCount))),
            "Address not eligible for presale mint"
        );

        require(_count <= _allowedCount, "Mint count exceeds allowed mint count");
        require(msg.value >= presalePrice * _count, "Incorrect ether sent with this transaction");
        if (saleStatus == SALE_STATUS.INVESTOR) {
            require(
                _allowedCount >= investorMintCount[msg.sender] + _count,
                "Transaction will exceed maximum NFTs allowed to mint in investor sale"
            );

            investorMintCount[msg.sender] += _count;
        } else if (saleStatus == SALE_STATUS.VIP) {
            require(
                _allowedCount >= vipMintCount[msg.sender] + _count,
                "Transaction will exceed maximum NFTs allowed to mint in vip sale"
            );
            vipMintCount[msg.sender] += _count;
        } else {
            require(
                _allowedCount >= wlMintCount[msg.sender] + _count,
                "Transaction will exceed maximum NFTs allowed to mint in presale"
            );

            wlMintCount[msg.sender] += _count;
        }

        mint(msg.sender, _count);
    }

    // Public mint

    function publicMint(uint256 _count) external payable soldOut(_count) {
        require(saleStatus == SALE_STATUS.PUBLIC, "Public sale is not started");
        require(msg.value >= publicPrice * _count, "Incorrect ether sent with this transaction");
        mint(msg.sender, _count);
    }

    function mint(address _addr, uint256 quantity) private {
        _safeMint(_addr, quantity);
    }
}
