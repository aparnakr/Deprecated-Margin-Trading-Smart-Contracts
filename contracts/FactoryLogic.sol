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
                    //TODO: ensure the following are correct
                    factoryStorageContract.tokenAddresses('DAI'),
                    factoryStorageContract.ctokenAddresses('DAI'),
                    factoryStorageContract.exchangeAddresses('DAI'),
                    factoryStorageContract.tokenAddresses(ticker),
                    factoryStorageContract.ctokenAddresses(ticker),
                    factoryStorageContract.exchangeAddresses(ticker),
                    'l'
                );
                //TODO: add user if they aren't in FactoryStorage
                factoryStorageContract.addNewPositionContract(ticker, msg.sender, address(s));
            } else {
                PositionContract s = new PositionContract(
                    msg.sender,
                    ticker,
                    //TODO: ensure the following are correct
                    factoryStorageContract.tokenAddresses('DAI'),
                    factoryStorageContract.ctokenAddresses('DAI'),
                    factoryStorageContract.exchangeAddresses('DAI'),
                    factoryStorageContract.tokenAddresses(ticker),
                    factoryStorageContract.ctokenAddresses(ticker),
                    factoryStorageContract.exchangeAddresses(ticker),
                    's'
                );
                //TODO: add user if they aren't in FactoryStorage
            factoryStorageContract.addNewPositionContract(ticker, msg.sender, address(s));
            }
        }
    }

//    function openETHContract(bool isLeverage) public {
//        if(ETH[msg.sender] == address(0x0)) {
//            positionContract s = new positionContract(msg.sender, "ETH", tokenAddresses[0], ctokenAddresses[0], tokenExchangeAddresses[0], tokenAddresses[2],  ctokenAddresses[2], tokenExchangeAddresses[2], "s");
//            ETH[msg.sender] = address(s);
//        }
//    }
}