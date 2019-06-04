pragma solidity ^0.5.8;
import {PositionContract} from "./PositionContract.sol";
import {FactoryStorage} from "./FactoryStorage.sol";

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
    function openERC20Contract(string memory ticker, bool isLeverage) public {
        address positionContract = factoryStorageContract.positionContracts(ticker,msg.sender);

        require(positionContract == address(0x0));
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

//    function openETHContract(bool isLeverage) public {
//        if(ETH[msg.sender] == address(0x0)) {
//            positionContract s = new positionContract(msg.sender, "ETH", tokenAddresses[0], ctokenAddresses[0], tokenExchangeAddresses[0], tokenAddresses[2],  ctokenAddresses[2], tokenExchangeAddresses[2], "s");
//            ETH[msg.sender] = address(s);
//        }
//    }
}