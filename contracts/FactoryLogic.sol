pragma solidity ^0.5.8;
import {PositionContract} from "./PositionContract.sol";
import {FactoryStorage} from "./FactoryStorage.sol";
//import {PositionETHContract} from "./PositionETHContract.sol"

/**
 * @title Opyns's FactoryLogic Contract
 * @notice Deploys PositionContract Instances
 * @author Opyn, Aparna Krishnan and Zubin Koticha
 */
contract FactoryLogic {

    /**
    * @notice FactoryStorage contract that instantiated this contract.
    */
    FactoryStorage public factoryStorageContract;

    /**
     * @notice Constructs a new FactoryLogic
     * @param factoryStorageContractAddress The address of the FactoryStorage contract that instantiated this contract.
     */
    constructor(address factoryStorageContractAddress) public {
        factoryStorageContract = FactoryStorage(factoryStorageContractAddress);
    }

    /*** User Interface ***/

    /**
    * @notice User creates a new Position Contract.
    * @param ticker Type: string memory. The ticker symbol of the position contract to create.
    * @param isLeverage Type: bool. True if the first position to opened is a leveraged one, false if a short position.
    */
    //TODO: make ETH work for below
    function openPositionContract(string memory ticker, bool isLeverage) public {
        address positionContract = factoryStorageContract.positionContracts(ticker,msg.sender);

        require(positionContract == address(0x0));
        //TODO: this flow below is redundant
//        if (ticker != 'ETH') {
            if (isLeverage) {
                PositionContract leverageContract = new PositionContract(
                    msg.sender,
                    ticker,
                    //TODO: ensure the following are correct
                    factoryStorageContract.tokenAddresses(ticker),
                    factoryStorageContract.ctokenAddresses(ticker),
                    factoryStorageContract.exchangeAddresses(ticker),
                    factoryStorageContract.tokenAddresses('DAI'),
                    factoryStorageContract.ctokenAddresses('DAI'),
                    factoryStorageContract.exchangeAddresses('DAI'),
                    'l'
                );
                //TODO: add user if they aren't in FactoryStorage
                factoryStorageContract.addNewPositionContract(ticker, msg.sender, address(leverageContract));
            } else {
                PositionContract shortContract = new PositionContract(
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
            factoryStorageContract.addNewPositionContract(ticker, msg.sender, address(shortContract));
            }
//        } else {
//            if (isLeverage) {
//                PositionETHContract leverageContract = new PositionContract(
//                    msg.sender,
//                    factoryStorageContract.ctokenAddresses(ticker),
//                    factoryStorageContract.tokenAddresses('DAI'),
//                    factoryStorageContract.ctokenAddresses('DAI'),
//                    factoryStorageContract.exchangeAddresses('DAI'),
//                    'l'
//                );
//                //TODO: add user if they aren't in FactoryStorage
//                factoryStorageContract.addNewPositionContract(ticker, msg.sender, address(leverageContract));
//            } else {
//                PositionETHContract shortContract = new PositionETHContract(
//                    msg.sender,
//                //TODO: ensure the following are correct
//                    factoryStorageContract.tokenAddresses('DAI'),
//                    factoryStorageContract.ctokenAddresses('DAI'),
//                    factoryStorageContract.exchangeAddresses('DAI'),
//                    factoryStorageContract.ctokenAddresses(ticker),
//                    's'
//                );
//                //TODO: add user if they aren't in FactoryStorage
//                factoryStorageContract.addNewPositionContract(ticker, msg.sender, address(shortContract));
//            }
//        }
    }
}