pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract preciousItem is Ownable, ERC20, AccessControl, ReentrancyGuard {
    bytes32 public constant admin = keccak256("admin");
    uint256 public maxIncrease; // maximum increase per action incase of mistake or bad actor
    uint8 numDecimals = 18;
    uint256 public balanceReceived;
    uint256 markup;

    AggregatorV3Interface internal priceFeedXauUsd;
    AggregatorV3Interface internal priceFeedETHUSD;

    /**
     * THIS EXAMPLE USES UN-AUDITED CODE.
     * Network: Rinkeby
     * Base: XAU/USD
     * Base Address: 0x81570059A0cb83888f1459Ec66Aad1Ac16730243
     * Quote: Eth/USD
     * Quote Address: 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
     * Decimals: 8
     */

    constructor(uint256 initialSupply, uint256 _markup)
        ERC20("Gold", "GoldDemo")
    {
        //does constructor use storage
        _mint(address(this), initialSupply);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(admin, msg.sender);
        priceFeedXauUsd = AggregatorV3Interface(
            0x81570059A0cb83888f1459Ec66Aad1Ac16730243
        ); //rinkeby
        priceFeedETHUSD = AggregatorV3Interface(
            0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
        );
        markup = _markup; //remember markup is in the order of 18 decimals
    }

    function getDerivedPrice() public view returns (int256) {
        require(
            numDecimals > uint8(0) && numDecimals <= uint8(18),
            "Invalid _decimals"
        );
        int256 decimals = int256(10**uint256(numDecimals));
        (, int256 basePrice, , , ) = priceFeedXauUsd.latestRoundData();
        uint8 baseDecimals = priceFeedXauUsd.decimals();
        basePrice = scalePrice(basePrice, baseDecimals, numDecimals);

        (, int256 quotePrice, , , ) = priceFeedETHUSD.latestRoundData();
        uint8 quoteDecimals = priceFeedETHUSD.decimals();
        quotePrice = scalePrice(quotePrice, quoteDecimals, numDecimals);

        return ((basePrice * decimals) / quotePrice);
    }

    function scalePrice(
        int256 _price,
        uint8 _priceDecimals,
        uint8 _decimals
    ) internal pure returns (int256) {
        if (_priceDecimals < _decimals) {
            return _price * int256(10**uint256(_decimals - _priceDecimals));
        } else if (_priceDecimals > _decimals) {
            return _price / int256(10**uint256(_priceDecimals - _decimals));
        }
        return _price;
    }

    //this is an example denomination, could be kilos etc.. default is a troy ounce.(from the price data)
    function BuyGramOfGold() public payable nonReentrant {
        balanceReceived += msg.value;
        uint256 currentPrice = (uint256(getDerivedPrice()) * 10**10) /
            311034763827; //bodmas? //because 8 decimal result had to adjust to 18
        uint256 adjustedPrice = (currentPrice * markup) / 10**18;
        uint256 ammountToSend = ((msg.value * 10**18) / (adjustedPrice));
        _transfer(address(this), msg.sender, ammountToSend);
        withdrawMoney();
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdrawMoney() private {
        address payable to = payable(owner());
        //to.transfer(getBalance());
        (bool sent, ) = to.call{value: getBalance()}("");
        require(sent, "Failed to send Ether");
    }

    function setMarkup(uint256 _markup) external onlyOwner {
        markup = _markup; //remember markup is in the order of 18 decimals
    }

    function checkUnalocatedGold() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function setAdmin(address _account) external onlyOwner onlyRole(admin) {
        grantRole(admin, _account);
    }

    function removeAdmin(address _account) external onlyOwner onlyRole(admin) {
        revokeRole(admin, _account);
    }

    function renounceAdmin(address _account) external {
        renounceRole(admin, _account);
    }

    function addSupply(uint256 _additionalSupply)
        external
        onlyOwner
        onlyRole(admin)
    {
        _mint(address(this), _additionalSupply);
    }

    function reduceSupply(uint256 _removeSupply)
        external
        onlyOwner
        onlyRole(admin)
    {
        _burn(address(this), _removeSupply);
    }

    function veiwMarkup() external view returns (uint256) {
        return markup;
    }

    function getContract() public view returns (address) {
        return address(this);
    }
}
