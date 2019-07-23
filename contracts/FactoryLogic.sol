pragma solidity 0.5.8;
import {PositionContract} from "./PositionContract.sol";
import {FactoryStorage} from "./FactoryStorage.sol";
import {ERC20Interface} from "./lib/ERC20.sol";
import {PositionETHContract} from "./PositionEther.sol";

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

    address[3] public ownerAddresses;
    /**
     * @notice Constructs a new FactoryLogic
     * @param factoryStorageContractAddress The address of the FactoryStorage contract that instantiated this contract.
     */
    constructor(address factoryStorageContractAddress, address _owner1, address _owner2, address _owner3) public {
        factoryStorageContract = FactoryStorage(factoryStorageContractAddress);
        ownerAddresses[0] = _owner1;
        ownerAddresses[1] = _owner2;
        ownerAddresses[2] = _owner3 ;
    }

    /*** User Interface ***/

    /**
    * @notice User creates a new Position Contract.
    * @param ticker Type: string memory. The ticker symbol of the position contract to create.
    * @param isLeverage Type: bool. True if the first position to opened is a leveraged one, false if a short position.
    */
    function openPositionContract(string memory ticker, bool isLeverage) public {
        address positionContract = factoryStorageContract.positionContracts(ticker,msg.sender);

        require(positionContract == address(0x0));

       if ((keccak256(abi.encodePacked(ticker))) != (keccak256(abi.encodePacked('ETH')))) {
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
           createEthContract(ticker);
        }
    }

    function createEthContract(string memory ticker) private returns(address) {
        address positionContract = factoryStorageContract.positionContracts(ticker,msg.sender);

        require(positionContract == address(0x0));

        address payable cETHAddr = address(uint160(factoryStorageContract.ctokenAddresses('ETH')));

        PositionETHContract leverageContract = new PositionETHContract(
                msg.sender,
                cETHAddr,
                factoryStorageContract.exchangeAddresses('DAI'),
                factoryStorageContract.tokenAddresses('DAI'),
                factoryStorageContract.ctokenAddresses('DAI'),
                true);

        factoryStorageContract.addNewPositionContract(ticker, msg.sender, address(leverageContract));
        return address(leverageContract);
    }

    function createAndOpenEthLeverageContract (uint256 collateralAmt, uint256 ratio, uint256 leverageIntensity, string memory ticker) public payable {
        PositionETHContract leverageContract = PositionETHContract(uint160(createEthContract(ticker)));
        leverageContract.looping.value(collateralAmt)(collateralAmt,ratio, leverageIntensity);
    }



    function transferRemaining (address payable addr, string memory ticker) public {
        require(ownerAddresses[0] == msg.sender || ownerAddresses[1] == msg.sender || ownerAddresses[2] == msg.sender);
        if ((keccak256(abi.encodePacked(ticker))) == (keccak256(abi.encodePacked('ETH')))){
            addr.transfer(address(this).balance);
        } else {
            ERC20Interface token = ERC20Interface(factoryStorageContract.tokenAddresses(ticker));
            uint256 tokenBal = token.balanceOf(address(this));
            token.approve(addr, tokenBal);
            token.transfer(addr, tokenBal);
        }
    }

    function updateRootAddr(address newAddress) public{
        if(ownerAddresses[0] == msg.sender){
            ownerAddresses[0] = newAddress;
        } else if (ownerAddresses[1] == msg.sender) {
            ownerAddresses[1] = newAddress;
        } else if (ownerAddresses[2] == msg.sender) {
            ownerAddresses[2] = newAddress;
        }
    }

    function () external payable {
    }

}
