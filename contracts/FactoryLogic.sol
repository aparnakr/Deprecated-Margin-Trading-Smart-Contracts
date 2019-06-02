pragma solidity ^0.5.8;
import {PositionContract} from "./PositionContract.sol";
import {FactoryStorage} from "./FactoryStorage.sol";

contract FactoryLogic {

    FactoryStorage public factoryStorageContract;

    //TODO: change the constructor for future versions.
    constructor(address factoryStorageContractAddress) public {
        factoryStorageContract = FactoryStorage(factoryStorageContractAddress);
    }

    function openERC20Contract(string memory ticker, bool isLeverage) public {
        //(get the proper mapping!)
        address positionContract = factoryStorageContract.positionContracts(ticker,msg.sender);
        //TODO: should be require not if statement so there's no wasted gas, right?

        if (positionContract == address(0x0)) {
            //TODO: this flow below is redundant
            if (isLeverage) {
                PositionContract s = new PositionContract(
                    msg.sender,
                    ticker,
                    factoryStorageContract.tokenAddresses(0),
                    factoryStorageContract.ctokenAddresses(0),
                    factoryStorageContract.exchangeAddresses(0),
                    factoryStorageContract.tokenAddresses(3),
                    factoryStorageContract.ctokenAddresses(3),
                    factoryStorageContract.exchangeAddresses(3),
                    'l'
                );
                factoryStorageContract.addNewPositionContract(ticker, msg.sender,address(s));
            } else {
                PositionContract s = new PositionContract(
                    msg.sender,
                    ticker,
                    factoryStorageContract.tokenAddresses(0),
                    factoryStorageContract.ctokenAddresses(0),
                    factoryStorageContract.exchangeAddresses(0),
                    factoryStorageContract.tokenAddresses(3),
                    factoryStorageContract.ctokenAddresses(3),
                    factoryStorageContract.exchangeAddresses(3),
                    's'
                );
                factoryStorageContract.addNewPositionContract(ticker, msg.sender,address(s));
            }
        }
    }

//    function openShortETH() public {
//        if(ETH[msg.sender] == address(0x0)) {
//            positionContract s = new positionContract(msg.sender, "ZRX", tokenAddresses[0], ctokenAddresses[0], tokenExchangeAddresses[0], tokenAddresses[2],  ctokenAddresses[2], tokenExchangeAddresses[2], "s");
//            ETH[msg.sender] = address(s);
//        }
//    }
//
}