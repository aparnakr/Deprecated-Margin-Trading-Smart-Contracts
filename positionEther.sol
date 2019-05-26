pragma solidity ^0.5.2;
import {CErc20, ComptrollerInterface,  CToken} from "./CERC20.sol";
import {CEther} from "./CEther.sol";
import {UniswapExchangeInterface} from "./uniswap.sol";
import {ERC20Interface} from "./ERC20.sol";


contract positionEther {
    // the user's address
    address payable public ownerAddress = 0x61f6c99C42d1e823852d4f82057A8B77fbD08D48;
    string public tradeType;
    string public asset = "ETH";
    uint public err1 = 0;
    uint public err2 = 0;

    CEther cETH = CEther (0xd6801a1DfFCd0a410336Ef88DeF4320D6DF1883e);

    address private factoryAddress;

    UniswapExchangeInterface tokenExchange = UniswapExchangeInterface(0xaF51BaAA766b65E8B3Ee0C2c33186325ED01eBD5);
    ERC20Interface token = ERC20Interface (0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa);
    CErc20 cToken = CErc20(0x2ACC448d73e8D53076731fEA2EF3fc38214d0A7d);

    uint256 ETHbalance = 0;
    uint256 public amtShorted;
    uint256 private borrowBalance;
    uint256 private supplyBalance;
    uint256 private collateralToSupply;

    function () external payable {
    }

    // This function transfers in the collateral
    function transferInCollateral(uint256 collateralAmt) public {
        require(msg.sender == ownerAddress);
        require(collateralAmt > 0);

        // TODO: ensure that approve happens in javascript before this is even called
        token.transferFrom(msg.sender, address(this), collateralAmt);

    }


    // The transferIn of Eth happens in msg.value
    function mintETH(uint256 amt) private {
        require(amt > 0);
        cETH.mint.value(amt);
    }

    // This function mints a new compound cCollateral token
    function mintCollateral(uint256 amt) private {
        require(amt > 0);
        token.approve(address(cToken), amt); // approve the transfer
        assert(cToken.mint(amt) == 0); // mint the cTokens and assert there is no error
    }

    function borrow(uint256 amt, string memory _tradeType) public {
        require(amt > 0);
        //TODO: remeber to change comptroller address for mainnet
        ComptrollerInterface troll = ComptrollerInterface(0x8d2A2836D44D6735a2F783E6418caEDb86DA58d8);
        address[] memory ct = new address[](2);
        ct[0] = address(cETH);
        ct[1] = address(cToken);
        uint[] memory errors = troll.enterMarkets(ct);
        err1 = errors[0];
        err2 = errors[1];
        require(errors[0] == 0);
        // if (keccak256(abi.encodePacked(_tradeType)) == keccak256(abi.encodePacked("l"))) {
        //     // borrow the token if long position
        //     uint error = cToken.borrow(amt);
        //     assert(error == 0);
        // } else {
        //     // borrow the ETH if short position
        //     uint error = cETH.borrow(amt);
        //     assert(error == 0);
        // }
    }

    function swapCollateraltoEthOpenLong(uint256 amt) private {
        require(amt > 0);
      token.approve(address(tokenExchange), 1000000000000000000000000000000000000000);
      tokenExchange.tokenToEthTransferInput(amt, 1, 16517531290, ownerAddress);
    }

    function swapEthToTokenOpenLong(uint256 amt) private {
        require(amt > 0);
        tokenExchange.ethToTokenTransferInput.value(amt)(1, 16517531290, ownerAddress);
    }

    function leverage(uint256 amtToLeverage, uint256 tokenAmt) public {
        require(msg.sender == ownerAddress);
        ETHbalance += amtToLeverage;
        mintETH(amtToLeverage);
        borrow(tokenAmt, "l");
        swapCollateraltoEthOpenLong(tokenAmt);
    }

    function short(uint256 colAmt, uint256 amtToShort) public {
         require(msg.sender == ownerAddress);
         transferInCollateral(colAmt);
         mintCollateral(colAmt);
         borrow(amtToShort, "s");
         swapEthToTokenOpenLong(amtToShort);
    }

    function determineTradeType(string memory _tradeType) private {
        // Ensure this is an 'l' or an 's'
        if (keccak256(abi.encodePacked(_tradeType)) != keccak256(abi.encodePacked(tradeType))) {
            calcBorrowBal();
            require(borrowBalance == 0);
            tradeType = _tradeType;
        }
    }

    function openPosition (uint256 collateralAmt, uint256 assetAmt, string memory _tradeType) public payable{
        determineTradeType(_tradeType);
        if (keccak256(abi.encodePacked(_tradeType)) == keccak256(abi.encodePacked("l"))) {
            require(msg.value == collateralAmt);
            leverage(msg.value, assetAmt);

        } else if (keccak256(abi.encodePacked(_tradeType)) == keccak256(abi.encodePacked("s"))){
            short(collateralAmt, assetAmt);
        }

    }


    function swapCollateraltoEthCloseShort(uint256 amt) public {
        require(amt > 0);
      token.approve(address(tokenExchange), 1000000000000000000000000000000000000000);
      tokenExchange.tokenToEthSwapInput(amt, 1, 16517531290);
    }

    function swapEthToTokenCloseShort(uint256 amt) public {
        require(amt > 0);
        tokenExchange.ethToTokenSwapInput.value(amt)(1, 16517531290);
    }

        // This functiom calculates the borrow balance of the token (including interest) from compound
    function calcBorrowBal() private returns (uint256) {
        if (keccak256(abi.encodePacked(tradeType)) == keccak256(abi.encodePacked("s"))) {
            borrowBalance = cETH.borrowBalanceCurrent(address(this));
        } else {
            borrowBalance = cToken.borrowBalanceCurrent(address(this));
        }
        return borrowBalance;
    }

    // This functiom calculates the supplyBalance balance of the collateral (including interest) from compound
    function calcSupplyBal() private returns (uint256){
        if (keccak256(abi.encodePacked(tradeType)) == keccak256(abi.encodePacked("s"))) {
            supplyBalance = cToken.balanceOf(address(this)) * cToken.exchangeRateCurrent() / (10**18);
        } else {
            supplyBalance = cETH.balanceOf(address(this)) * cETH.exchangeRateCurrent() / (10**18);
        }

        return supplyBalance;
    }

    function getSupplyBalance() public view returns (uint256) {
         if (keccak256(abi.encodePacked(tradeType)) == keccak256(abi.encodePacked("s"))) {
             return cToken.balanceOf(address(this)) * cToken.exchangeRateStored() / (10**18);
         } else {
             return cETH.balanceOf(address(this)) * cETH.exchangeRateStored() / (10**18);
         }
    }

    function getBorrowBalance() public view returns (uint256) {
        if (keccak256(abi.encodePacked(tradeType)) == keccak256(abi.encodePacked("s"))) {
            return cETH.borrowBalanceStored(address(this));
        } else {
            return cToken.borrowBalanceStored(address(this));
        }
    }

     // This function calculates the amount of collateralToSupply to close the entire position.
    function calcCollateralToSupply() private returns (uint256) {
        calcBorrowBal();
        if (borrowBalance > 0) {
            if (keccak256(abi.encodePacked(tradeType)) == keccak256(abi.encodePacked("s"))) {
                collateralToSupply = tokenExchange.getTokenToEthOutputPrice(borrowBalance);
            } else {
                collateralToSupply = tokenExchange.getEthToTokenOutputPrice(borrowBalance);
            }
        }

        return collateralToSupply;
    }

     // This function repays the borrowed token to compound
    function repayBorrowToken(uint256 borrowAmt) private {
        require(borrowAmt > 0);
        if (keccak256(abi.encodePacked(tradeType)) == keccak256(abi.encodePacked("s"))) {
            cETH.repayBorrow.value(borrowAmt);
        } else {
            token.approve(address(cToken), 1000000000000000000000000000000000000000);
            require(cToken.repayBorrow(borrowAmt) == 0);
        }
    }

    // This function gets back the supplied collateral from compound
    function redeemUnderlyingCollateral(uint256 collateralAmt) private {
         if (keccak256(abi.encodePacked(tradeType)) == keccak256(abi.encodePacked("s"))) {
            require(cToken.redeemUnderlying(collateralAmt) == 0);
         } else {
            require(cETH.redeemUnderlying(collateralAmt) == 0);
         }
    }

    // This function sends the remaining collateral back to the user
    function TransferCollateralOut (uint256 collateralAmt) private {
        token.approve(ownerAddress, collateralAmt);
        token.transfer(ownerAddress, collateralAmt);
    }

     // This function sends the remaining intermediate tokens as fees to the factory contract
    function transferRemaining () private {
        uint256 tokenBal = token.balanceOf(address(this));
        token.approve(factoryAddress, tokenBal);
        token.transfer(factoryAddress, tokenBal);
        ownerAddress.transfer(address(this).balance);
    }

    // // This function closes the entire position.
    // function closeEntirePosition (uint256 collateralAmt) public {
    //     require(msg.sender == ownerAddress);
    //     calcCollateralToSupply();
    //     if (borrowBalance > 0) {
    //     require(collateralAmt >= collateralToSupply);
    //     transferInCollateral(collateralAmt);
    //     tokenBalance = swapCollateralToToken(collateralAmt);
    //     require(tokenBalance >= borrowBalance);
    //     repayBorrowToken(borrowBalance);
    //     calcSupplyBal();
    //     redeemUnderlyingCollateral(supplyBalance);
    //     TransferCollateralOut(supplyBalance);
    //     amtShorted -= borrowBalance;
    //     transferRemaining();
    //     }
    // }

    //  // This function calculates the amount of collateralToSupply to close some part of the position.
    // function calcCollateralToSupply(uint256 amtToClose) private returns (uint256) {
    //     calcBorrowBal();
    //     if (borrowBalance > 0 && amtToClose <= borrowBalance) {
    //     uint256 ethToSupply = tokenExchange.getEthToTokenOutputPrice(amtToClose);
    //     collateralToSupply = collateralExchange.getTokenToEthOutputPrice(ethToSupply);
    //     }
    //     return collateralToSupply;

    // }

    // function getCollateralToSupply(uint256 amtToClose) public view returns (uint256){
    //     uint256 bBal = getBorrowBalance();
    //     uint256 colToSupply = 0;
    //     if (bBal > 0 && amtToClose <= bBal) {
    //         uint256 ethToSupply = tokenExchange.getEthToTokenOutputPrice(amtToClose);
    //         colToSupply = collateralExchange.getTokenToEthOutputPrice(ethToSupply);
    //     }
    //     return colToSupply;
    // }

    // function getCollateralToSupplyEntire() public view returns (uint256) {
    //     uint256 bBal = getBorrowBalance();
    //     uint256 colToSupply = 0;
    //     if (bBal > 0) {
    //     uint256 ethToSupply = tokenExchange.getEthToTokenOutputPrice(bBal);
    //     colToSupply = collateralExchange.getTokenToEthOutputPrice(ethToSupply);
    //     }
    //     return colToSupply;

    // }

    //  // This function closes some part of the position.
    // function closePosition(uint256 collateralAmt, uint256 repayAmt) public {
    //     require(msg.sender == ownerAddress);
    //     calcCollateralToSupply(repayAmt);
    //     if (borrowBalance > 0) {
    //     require(collateralAmt >= collateralToSupply);
    //     transferInCollateral(collateralAmt);
    //     tokenBalance = swapCollateralToToken(collateralAmt);
    //     require(tokenBalance >= repayAmt);
    //     repayBorrowToken(repayAmt);
    //     calcSupplyBal();
    //     uint256 amtToWithdraw = (repayAmt * supplyBalance)/ borrowBalance;
    //     redeemUnderlyingCollateral(amtToWithdraw);
    //     TransferCollateralOut(amtToWithdraw);
    //     amtShorted -= repayAmt;
    //     }
    // }

    //  // This function lets the user top up collateral.
    // function addCollateral(uint256 collateralAmt) public {
    //     require(msg.sender == ownerAddress);
    //     transferInCollateral(collateralAmt);
    //     mintCollateral(collateralAmt);
    // }


}