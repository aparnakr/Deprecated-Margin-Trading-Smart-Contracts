pragma solidity ^0.5.8;

/**
 * @title Opyns's FactoryStorage Contract
 * @notice Stores contract, user, exchange, and token data. Deploys FactoryLogic.
 * @author Opyn, Aparna Krishnan and Zubin Koticha
 */
contract FactoryStorage {

    //TODO: add more events

    event NewPositionContract(
        address userAddress,
        address newPositionContractAddress,
        address factoryLogicAddress
    );

    event NewTokenAddedToPositionContract(
        string ticker,
        address tokenAddr,
        address cTokenAddr,
        address exchangeAddr
    );

    event UserAdded(
        address userAddr
    );

    event TickerAdded(
        string ticker
    );

    event FactoryLogicChanged(
        address factoryLogicAddr
    );

    //maybe the name positionContractAddresses is better?!
    //ticker => userAddr => positionContractAddr
    //e.g. ticker = 'REP'
    mapping (string => mapping (address => address)) public positionContracts;

    /**
    * @notice the following give the ERC20 token address, ctoken, and Uniswap Exchange for a given token ticker symbol.
    * e.g tokenAddresses('REP') => 0x1a...
    * e.g ctokenAddresses('REP') => 0x51...
    * e.g exchangeAddresses('REP') => 0x9a...
    */
    mapping (string => address) public tokenAddresses;
    mapping (string => address) public ctokenAddresses;
    mapping (string => address) public exchangeAddresses;

    //TODO: think about - using CarefulMath for uint;

    address public factoryLogicAddress;

    /**
    * @notice The array of owners with write privileges.
    */
    address[3] public ownerAddresses;

    /**
    * @notice The array of all users with contracts.
    */
    address[] public userAddresses;
    string[] public tickers;

    /**
    * @notice These mappings act as sets to see if a key is in string[] public tokens or address[] public userAddresses
    */
    mapping (address => bool) public userAddressesSet;
    mapping (address => bool) public tickerSet;

    /**
    * @notice Constructs a new FactoryStorage
    * @param owner1 The second owner (after msg.sender)
    * @param owner2 The third owner (after msg.sender)
    */
    constructor(address owner1, address owner2) public {
        //TODO: deal with keys and ownership
        ownerAddresses[0] = msg.sender;
        ownerAddresses[1] = owner1;
        ownerAddresses[2] = owner2;

        tickers = ['DAI','ZRX','BAT','ETH'];
        tickerSet['DAI'] = true;
        tickerSet['ZRX'] = true;
        tickerSet['BAT'] = true;
        tickerSet['ETH'] = true;

        //TODO: ensure all the following are accurate for mainnet.
        tokenAddresses['DAI'] = 0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa;
        tokenAddresses['BAT'] = 0xbF7A7169562078c96f0eC1A8aFD6aE50f12e5A99;
        tokenAddresses['ZRX'] = 0xddea378A6dDC8AfeC82C36E9b0078826bf9e68B6;
        tokenAddresses['REP'] = 0x6e894660985207feb7cf89Faf048998c71E8EE89;

        ctokenAddresses['DAI'] = 0x2ACC448d73e8D53076731fEA2EF3fc38214d0A7d;
        ctokenAddresses['BAT'] = 0x1Cae2a350AF04cD2525Aee6Cc8397e03f50C1Af4;
        ctokenAddresses['ZRX'] = 0x961aA80B6B44D445387Aa8395c4c6C1a473F4ffD;
        ctokenAddresses['REP'] = 0x1c8F7Aca3564c02d1Bf58EbA8571b6fdAfe91f44;
        ctokenAddresses['ETH'] = 0xbED6D9490a7CD81fF0F06f29189160a9641a358F;

        exchangeAddresses['DAI'] = 0xaF51BaAA766b65E8B3Ee0C2c33186325ED01eBD5;
        exchangeAddresses['BAT'] = 0x5cEDbFc1C6041Df417173Aa552040D79f09d631c;
        exchangeAddresses['ZRX'] = 0x4dCF4017ffbffABB4F8f8378d6c53286590d4625;
        exchangeAddresses['REP'] = 0x67B67cb021a956D1956884B99cE2FB7dc835a080;
    }

    /**
    * @notice Sets a FactoryLogic contract that this contract interacts with, this clause is responsibility for upgradeability.
    * @param newAddress the address of the new FactoryLogic contract
    */
    function setFactoryLogicAddress(address newAddress) public {
        require(factoryLogicAddress == msg.sender|| ownerAddresses[0] == msg.sender || ownerAddresses[1] == msg.sender || ownerAddresses[2] == msg.sender);
        //TODO: better security practices required than the above
        factoryLogicAddress = newAddress;
        emit FactoryLogicChanged(newAddress);
    }

    /**
    * @notice Adds a new user to the userAddresses array.
    * @param newAddress the address of the new user
    */
    function addUser(address newAddress) public {
        require(factoryLogicAddress == msg.sender|| ownerAddresses[0] == msg.sender || ownerAddresses[1] == msg.sender || ownerAddresses[2] == msg.sender);
        //TODO: ensure that this is how it works.
        if (!userAddressesSet(newAddress)) {
            userAddresses.push(newAddress);
            userAddressesSet(userAddressesSet) = true;
            emit UserAdded(userAddr);
        }
    }

    /**
   * @notice Adds a new token to the tokens array.
   * @param ticker ticker symbol of the new token
   */
    function addTicker(string memory ticker) public {
        require(factoryLogicAddress == msg.sender|| ownerAddresses[0] == msg.sender || ownerAddresses[1] == msg.sender || ownerAddresses[2] == msg.sender);
        //TODO: ensure that this is how it works.
        if (!tickerSet(ticker)) {
            tickers.push(ticker);
            tickerSet(ticker) = true;
            emit TickerAdded(ticker);
        }
    }

    /**
    * @notice Sets the newAddress of a ticker in the tokenAddresses array.
    * @param ticker string ticker symbol of the new token being added
    * @param newAddress the new address of the token
    */
    function updateTokenAddress(string memory ticker, address newAddress) public {
        require(factoryLogicAddress == msg.sender|| ownerAddresses[0] == msg.sender || ownerAddresses[1] == msg.sender || ownerAddresses[2] == msg.sender);
        tokenAddresses[ticker] = newAddress;
    }

    /**
    * @notice Sets the newAddress of a ticker in the ctokenAddresses array.
    * @param newAddress the address of the ctoken
    */
    function updatecTokenAddress(string memory ticker, address newAddress) public {
        require(factoryLogicAddress == msg.sender|| ownerAddresses[0] == msg.sender || ownerAddresses[1] == msg.sender || ownerAddresses[2] == msg.sender);
        ctokenAddresses[ticker] = newAddress;
    }

    /**
    * @notice Sets the newAddress of a position contract, this clause is responsibility for upgradeability.
    * @param newAddress the address of the new FactoryLogic contract
    */
    function updateExchangeAddress(string memory ticker, address newAddress) public {
        require(factoryLogicAddress == msg.sender|| ownerAddresses[0] == msg.sender || ownerAddresses[1] == msg.sender || ownerAddresses[2] == msg.sender);
        exchangeAddresses[ticker] = newAddress;
    }

    //  TODO: proper solidity style for following function
    /**
    * @notice Sets the newAddress of a position contract, this clause is responsibility for upgradeability.
    * @param ticker the ticker symbol for this new token
    * @param tokenAddr the address of the token
    * @param cTokenAddr the address of the cToken
    * @param exchangeAddr the address of the particular DEX pair
    */
    function addNewTokenToPositionContracts(string memory ticker, address tokenAddr, address cTokenAddr, address exchangeAddr) public {
        require(factoryLogicAddress == msg.sender|| ownerAddresses[0] == msg.sender || ownerAddresses[1] == msg.sender || ownerAddresses[2] == msg.sender);
        //TODO: do we want to first ensure ticker not already there?!
        tokenAddresses[ticker] = tokenAddr;
        ctokenAddresses[ticker] = cTokenAddr;
        exchangeAddresses[ticker] = exchangeAddr;
        emit NewTokenAddedToPositionContract(ticker, tokenAddr, cTokenAddr, exchangeAddr);
    }

    /**
    * @notice Sets the newAddress of a position contract, this clause is responsibility for upgradeability.
    * @param ticker the ticker symbol that this PositionContract corresponds to
    * @param userAddress the address of the user creating this PositionContract
    * @param newContractAddress the address of the new position contract
    */
    function addNewPositionContract(string memory ticker, address userAddress, address newContractAddress) public {
        //TODO: ensure userAddress has been added and ticker is valid.
        require(factoryLogicAddress == msg.sender);
        positionContracts[ticker][userAddress] = newContractAddress;
        addUser(userAddress);
        //TODO: shouldn't the following event include the ticker?
        emit NewPositionContract(userAddress, newContractAddress, msg.sender);
    }
}