pragma solidity ^0.5.2;

contract FactoryStorage {

//    struct Trade? {
//        address exchangeContract?;
//        address xyz;
//    }
//TODO: think about - using SafeMath for uint;
//TODO: add events
//uint256 public constant DECIMALS = 18;

    address public factoryLogicAddress;

    //TODO: is the following how you declare arrays properly?
    address[3] public ownerAddresses;

    address[] public userAddresses;

    function FactoryStorage(address owner1, address owner2) {
        ownerAddresses[0] = msg.sender;
        ownerAddresses[1] = owner1;
        ownerAddresses[2] = owner2;
    }

    mapping (uint => address) public tokenAddresses;
    //TODO: figure out camelcase for the following
    mapping (uint => address) public ctokenAddresses;
    mapping (uint => address) public exchangeAddresses;

    //TODO: write explainer on the following mapping
    mapping(bytes32 => mapping (address => address)) public positionContractAddresses;

    // userAddr => shortRepAddr
    mapping (address => address) public REP;
    mapping (address => address) public ZRX;

    function setFactoryLogicAddress(address newAddress) public {
        require(ownerAddresses[0] == msg.sender || ownerAddresses[1] == msg.sender || ownerAddresses[2] == msg.sender);
        //TODO: better security practices required than the above
        factoryLogicAddress = newAddress;
    }

//    // returns "REP1, "REP2 ..."
//    function getPositionNames () {}
//
//    // All the Set and Add functions can only be called by the factory logic? contract
//    function updateUserAddress(i, val){}

    function addUser(address newAddress) public {
        require(factoryLogicAddress == msg.sender);
        //TODO: ensure push actually works
        userAddresses.push(newAddress);
    }

    function addTokenAddress(address newAddress) {
        require(factoryLogicAddress == msg.sender);
        tokenAddresses.push(newAddress);
    }

    function updateTokenAddress(uint256 index, address newAddress) {
        require(factoryLogicAddress == msg.sender);
        tokenAddresses[index] = newAddress;
    }

    function addcTokenAddress(address newAddress) {
        require(factoryLogicAddress == msg.sender);
        ctokenAddresses.push(newAddress);
    }

    function updateTokenAddress(uint256 index, address newAddress) {
        require(factoryLogicAddress == msg.sender);
        ctokenAddresses[index] = newAddress;
    }

    function addExchangeAddress(address newAddress) {
        require(factoryLogicAddress == msg.sender);
        exchangeAddresses.push(newAddress);
    }

    function updateExchangeAddress(uint256 index, address newAddress) {
        require(factoryLogicAddress == msg.sender);
        exchangeAddresses[index] = newAddress;
    }

//    function addPositionName(newKey) {
//        require(factoryLogicAddress == msg.sender);
//        exchangeAddresses[index] = newAddress;
//    }

    function addNewTokenToPositionContracts (tokenAddr, cTokenAddr, exchangeAddr, positionKey) {
    // if it doesn't exist, addTokenAddr, addcTokenAddr, addExchangeAddr, addPositionName
    }

    function addNewPositionContract(positionIndex, userAddress, contractAddress){
    // ensure position key Exists first at that index
    }
}