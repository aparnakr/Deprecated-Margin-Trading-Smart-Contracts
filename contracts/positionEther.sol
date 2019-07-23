pragma solidity 0.5.8;
import {CErc20, ComptrollerInterface,  CToken} from "./lib/CErc20.sol";
import {CEther} from "./lib/CEther.sol";
import {UniswapExchangeInterface} from "./lib/uniswap.sol";
import {ERC20Interface} from "./lib/ERC20.sol";
import {Comptroller} from "./lib/Comptroller.sol";


/**
 * @title Opyns's PositionETHContract Contract
 * @notice Enables Short and Long Positions on ETH
 * @author Opyn, Aparna Krishnan and Zubin Koticha
 */

/**
* @notice Price Oracle to get the current DAI and ETH prices
*/
interface V1PriceOracleInterface {
    function assetPrices(address asset) external view returns (uint);
}

interface KyberProxyInterface {
    function swapEtherToToken(ERC20Interface token, uint minConversionRate) external payable returns(uint);
    function swapTokenToEther(ERC20Interface token, uint srcAmount, uint minConversionRate) external returns(uint);
    function trade(ERC20Interface src, uint srcAmount, ERC20Interface dest, address destAddress, uint maxDestAmount, uint minConversionRate, address walletId) external payable returns(uint);
    function getExpectedRate(ERC20Interface src, ERC20Interface dest, uint srcQty) external view returns(uint expectedRate, uint slippageRate);

}

contract PositionETHContract {
    // the user's address
    address payable public ownerAddress;
    address kncPayoutAddr = 0x087aC7736469716D73498e479E09119A02D7A59D;
    // Is the contract a short or long contract
    bool public isLeverage;
    string public asset = "ETH";
    // Size of position opened
    uint256 public positionSize;
    // Amount of collateral that can be borrowed for each dollar of position supplied.
    uint256 public leverageIntensity;

    CEther cETH;
    // Address of the Contract which deployed this.
    address payable private factoryLogicAddress;

    KyberProxyInterface tokenExchange;
    ERC20Interface token;
    ERC20Interface eth;
    CErc20 cToken;

    uint256 private borrowBalance;
    uint256 private supplyBalance;

    Comptroller troll;

    /**
     * @notice Constructs a new Position Contract
     * @param _ownerAddr is the address of the owner who can call functions on the contract.
     * @param _cethAddr is the address of the cETH contract
     * @param _tokenExchangeAddr is the address of the Dai Exchange address on Uniswap
     * @param _tokenAddr is the address of Dai token
     * @param _cTokenAddr is the address of cDai
     * @param _isLeverage specifies if the contract is a short or long contract
     */
    constructor (address payable _ownerAddr,
                address payable _cethAddr,
                address _tokenExchangeAddr,
                address _tokenAddr,
                address _cTokenAddr,
                bool _isLeverage) public {

        factoryLogicAddress = msg.sender;
        ownerAddress = _ownerAddr;
        isLeverage = _isLeverage;
        positionSize = 0;
        leverageIntensity = 0;

        cETH = CEther(_cethAddr);
        tokenExchange = KyberProxyInterface(_tokenExchangeAddr);
        token = ERC20Interface(_tokenAddr);
        cToken = CErc20(_cTokenAddr);
        eth = ERC20Interface(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

        // Mainnet
        troll = Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
        // Rinkeby
        // Comptroller troll = Comptroller(0xb081cf57B1e422B3E627544Ec95992CBe8Eaf9cb);

    }

    /**
     * @notice Fallback function to make the contract payable.
     */
    function () external payable {
    }

    /**
     * @notice Function to transfer in the collateral (in the simple case Dai)
     * @param collateralAmt is the number of collateral tokens being transferred in.
     */
    function transferInCollateral(uint256 collateralAmt) private {
        require(collateralAmt > 0);

        // TODO: ensure that approve happens in javascript before this is even called
        token.transferFrom(msg.sender, address(this), collateralAmt);

    }

    /**
     * @notice Function to transfer in ETH.
     * @param amt is the amount of ETH tokens being transferred in.
     */
    function mintETH(uint256 amt) private {
        require(amt > 0);
        cETH.mint.value(amt)();
    }

    /**
     * @notice This function mints a new compound cCollateral token.
     * @param amt is the amount of underlying tokens being used to mint corresponding cTokens.
     */
    function mintCollateral(uint256 amt) private {
        require(amt > 0);
        token.approve(address(cToken), amt); // approve the transfer
        assert(cToken.mint(amt) == 0); // mint the cTokens and assert there is no error
    }


    function borrow(uint256 amt, bool isLeverage) private {
        require(amt >= 0);
        //TODO: remeber to change comptroller address for mainnet
        address[] memory ct = new address[](2);
        ct[0] = address(cETH);
        ct[1] = address(cToken);
        uint[] memory errors = troll.enterMarkets(ct);
        require(errors[0] == 0);
        require(errors[1] == 0);
        if (isLeverage) {
            // borrow the token if long position
            uint error = cToken.borrow(amt);
            assert(error == 0);
        } else {
            // borrow the ETH if short position
            uint error = cETH.borrow(amt);
            assert(error == 0);
        }
    }

    function swapTokentoEth(uint256 amt) private returns (uint) {
        require(amt >= 0);
        (uint minConversionRate, uint slippageRate) = tokenExchange.getExpectedRate(token, eth, amt);
        token.approve(address(tokenExchange), 1000000000000000000000000000000000000000);
        return tokenExchange.trade(token, amt, eth, address(this), 2**255, 0, kncPayoutAddr);
    }

    function swapEthToToken(uint256 amt) private returns (uint) {
        require(amt >= 0);
        (uint minConversionRate, uint slippageRate) = tokenExchange.getExpectedRate(eth, token, amt);
       return tokenExchange.trade.value(amt)(eth, amt, token, address(this), 2**255, 0, kncPayoutAddr);
    }

    function transferOutTokens(uint256 amt) private {
        token.approve(ownerAddress, amt);
        token.transfer(ownerAddress, amt);
    }

    function short(uint256 colAmt, uint256 amtToShort) private {
         transferInCollateral(colAmt);
         mintCollateral(colAmt);
         borrow(amtToShort, false);
         uint numTokens = swapEthToToken(amtToShort);
         transferOutTokens(numTokens);
    }

    function determineTradeType(bool _isLeverage) private {
        // Ensure this is an 'l' or an 's'
        if (isLeverage != _isLeverage) {
            calcBorrowBal();
            require(borrowBalance == 0);
            isLeverage = _isLeverage;
        }
    }

    function transferFees () private {
        if(isLeverage) {
            factoryLogicAddress.transfer(address(this).balance);
        } else {
            uint256 tokenBal = token.balanceOf(address(this));
            token.approve(factoryLogicAddress, tokenBal);
            token.transfer(factoryLogicAddress, tokenBal);
        }
    }

    function determineLeverageAmount(uint256 _leverageIntensity) private{
        if(isLeverage) {
            if (leverageIntensity == 0){
                leverageIntensity = _leverageIntensity;
            } else {
                require(leverageIntensity == _leverageIntensity);
            }
        }
    }

    function openPosition (uint256 collateralAmt, uint256 borrowAmt, bool _isLeverage) public payable{
        require(msg.sender == ownerAddress || msg.sender == factoryLogicAddress);
        determineTradeType(_isLeverage);
        determineLeverageAmount(130);

        if (!_isLeverage) {
            short((1000 * collateralAmt)/1006, borrowAmt);
            positionSize += borrowAmt;
        }
        transferFees();

    }

        /**
  * @notice Loops the open position to enable leveraged positions.
  * @param collateralAmt the amount of collateral in 10^18 units that the user supplies
  * @param ratio is the amount of token to be borrowed scaled by 100. ratio 6 means 0.6 is the collateralFactor.
  * @param leverageIntensity is the leverageIntensity scaled by 100. 2x leverage = 200 leverageIntensity.
  */
    function looping(uint256 collateralAmt, uint256 ratio, uint leverageIntensity) public payable{
        determineTradeType(true);
        require(msg.sender == ownerAddress || msg.sender == factoryLogicAddress);
        uint loopLimit = 20;
        require(collateralAmt <= msg.value);

        determineLeverageAmount(leverageIntensity);
        uint256 borrowAmt = 100001;
        uint i = 0;
        uint256 priceAmtCollateral;
        uint256 amtToBeSupplied = (leverageIntensity * collateralAmt)/100;
        positionSize += collateralAmt;
        collateralAmt = (1000 * collateralAmt) / 1006;
        uint256 amtSupplied = collateralAmt;

        factoryLogicAddress.transfer(address(this).balance - collateralAmt);

      while(i < loopLimit && collateralAmt > 10000 && borrowAmt > 10000 && amtSupplied < amtToBeSupplied) {
            mintETH(collateralAmt);
            // TODO: change for mainnet
            // Calculate the amount to be borrowed
            V1PriceOracleInterface priceContract = V1PriceOracleInterface(0x02557a5E05DeFeFFD4cAe6D83eA3d173B272c904);
            // V1PriceOracleInterface priceContract = V1PriceOracleInterface(0x5dEA9621f23e79003eCC294b4cc1e4c9362dFECc);
            priceAmtCollateral = priceContract.assetPrices(address(token));
            borrowAmt = (ratio * collateralAmt * (10 ** 18)) / (100 * priceAmtCollateral);
            if (borrowAmt > 10000) {
                // Borrow, Swap and add to the position size
                borrow(borrowAmt, true);
                swapTokentoEth(borrowAmt);
            }
            collateralAmt = address(this).balance;
            amtSupplied += collateralAmt;
            i++;
      }

      mintETH(address(this).balance);
    }

    function getPriceToken() public view returns (uint){
        V1PriceOracleInterface priceContract = V1PriceOracleInterface(0x02557a5E05DeFeFFD4cAe6D83eA3d173B272c904);
        uint priceAmtCollateral = priceContract.assetPrices(address(token));
        return priceAmtCollateral;
    }

    // This functiom calculates the borrow balance of the token (including interest) from compound
    function calcBorrowBal() private returns (uint256) {
        if (!isLeverage) {
            borrowBalance = cETH.borrowBalanceCurrent(address(this));
        } else {
            borrowBalance = cToken.borrowBalanceCurrent(address(this));
        }
        return borrowBalance;
    }

    function getAccountLiquidity() public view returns (uint, uint, uint) {
        return troll.getAccountLiquidity(address(this));
    }

    // This functiom calculates the supplyBalance balance of the collateral (including interest) from compound
    function getSupplyBalance() public view returns (uint256) {
         if (!isLeverage) {
             return cToken.balanceOf(address(this)) * cToken.exchangeRateStored();
         } else {
             return cETH.balanceOf(address(this)) * cETH.exchangeRateStored();
         }
    }

    // This functiom calculates the supplyBalance balance of the collateral (including interest) from compound
    function calcSupplyBalance() private view returns (uint256) {
        if(!isLeverage){
            return cToken.balanceOf(address(this)) ;
        } else {
            return cETH.balanceOf(address(this));
        }
    }

    function getBorrowBalance() public view returns (uint256) {
        if (!isLeverage) {
            return cETH.borrowBalanceStored(address(this));
        } else {
            return cToken.borrowBalanceStored(address(this));
        }
    }

    function getSupplyBorrowRatio() public view returns (uint256) {
        uint256 ratio = getSupplyBalance() / getBorrowBalance();
        return ratio;
    }

     // This function calculates the amount of collateralToSupply to close the entire position.
    function getCollateralToSupply(uint256 repayAmt) public view returns (uint256) {
        uint256 bBal = getBorrowBalance();
        uint256 colToSupply = 0;
        if (bBal > 0 && repayAmt <= bBal) {
            if (!isLeverage) {
                (uint amtETH, uint slippageRate) = tokenExchange.getExpectedRate(token, eth, 1000000000000000000);
                // How much colToSupply to get repayAmt of ETH?
                // 1000: amtETH :: ? : repayAmt
                colToSupply = 1000000000000000000 * repayAmt / amtETH;
            } else {
                (uint amtToken, uint slippageRate) = tokenExchange.getExpectedRate(eth, token, 1000000000000000000);
                // How much colToSupply to get repayAmt of token?
                // 1: amtToken :: ? : repayAmt
                colToSupply = 1000000000000000000 * repayAmt / amtToken;
            }
        }

        return colToSupply;
    }

    function repayBorrowToken(int256 borrowAmt) private {
        if (!isLeverage) {
            cETH.repayBorrow.value(uint256(borrowAmt))();
        } else {
            token.approve(address(cToken), 1000000000000000000000000000000000000000);
            require(cToken.repayBorrow(uint256(borrowAmt)) == 0);
        }
    }

    // This function gets back the supplied collateral from compound
    function redeemCollateral(uint256 collateralAmt) private {
         if (!isLeverage) {
            require(cToken.redeem(collateralAmt) == 0);
         } else {
            require(cETH.redeem(collateralAmt) == 0);
         }
    }

    function redeemUnderlyingCollateral(uint256 collateralAmt) private {
        require(isLeverage == true);
        require(cETH.redeemUnderlying(collateralAmt) == 0);
    }

     // This function sends the remaining intermediate tokens as fees to the factory contract
    function transferRemaining () private {
        uint256 tokenBal = token.balanceOf(address(this));
        token.approve(factoryLogicAddress, tokenBal);
        token.transfer(factoryLogicAddress, tokenBal);
        ownerAddress.transfer(address(this).balance);
    }

    function closeShort(uint256 collateralAmt, uint128 repayAmt, uint256 withdrawAmt, uint256 amtClosed) private {
        transferInCollateral(collateralAmt);
        uint256 tokenBalance = swapTokentoEth(collateralAmt);
            if (positionSize == amtClosed) {
                require(tokenBalance >= borrowBalance);
                repayBorrowToken(int256(calcBorrowBal()));
                redeemCollateral(calcSupplyBalance());
                transferOutTokens(token.balanceOf(address(this)));
                transferRemaining ();
                positionSize -= amtClosed;
            } else {
                require(repayAmt > 0);
                require(tokenBalance >= repayAmt);
                repayBorrowToken(int256(repayAmt));
                redeemCollateral(withdrawAmt/cToken.exchangeRateStored());
                transferOutTokens(token.balanceOf(address(this)));
                transferRemaining ();
                require(amtClosed <= positionSize);
                positionSize -= amtClosed;
            }
    }

     // This function closes some part of the position.
    function closePosition(uint256 collateralAmt, uint128 repayAmt, uint256 withdrawAmt, uint256 amtClosed) public  payable{
        require(msg.sender == ownerAddress);
        borrowBalance = calcBorrowBal();
        if(borrowBalance > 0) {
            if(!isLeverage) {
                closeShort(collateralAmt, repayAmt, withdrawAmt, amtClosed);
            }
        }
    }


    function closeLooping(uint256 positionSizeToClose, uint256 ratio, uint256 amtTransferredIn) public payable {
        require(msg.sender == ownerAddress);
        require(amtTransferredIn == msg.value);
        // don't let someone close a position if they are about to get liquidated
        (uint error, uint liquidity, uint shortfall) = getAccountLiquidity();
        require(liquidity  > 0);

        if (positionSizeToClose == positionSize) {

            uint256 borrowBalance = calcBorrowBal();
            if(borrowBalance > 0) {

                uint256 collateralAmt = address(this).balance;
                uint256 tokenBalance = swapEthToToken(collateralAmt);
                uint i = 0;

                while (i < 21 && tokenBalance > 0 && collateralAmt > 0) {
                    if(tokenBalance < borrowBalance) {
                        repayBorrowToken(int256(tokenBalance));
                        uint256 amtToRedeem = (100 * collateralAmt) / ratio ;
                        redeemUnderlyingCollateral(amtToRedeem);

                        borrowBalance = calcBorrowBal();
                        collateralAmt = address(this).balance;
                        tokenBalance = swapEthToToken(collateralAmt);
                    } else {
                        repayBorrowToken(int256(calcBorrowBal()));
                        redeemCollateral(calcSupplyBalance());
                        positionSize = 0;
                        tokenBalance = 0;
                        swapTokentoEth(token.balanceOf(address(this)));
                    }

                    i++;
                }

                ownerAddress.transfer(address(this).balance);

            }

        } else {
            uint256 borrowBalance = calcBorrowBal();
            uint256 borrowAmtToPayBack = (borrowBalance * positionSizeToClose) / positionSize;
            uint256 supplyAmtToWithdraw = (getSupplyBalance() * positionSizeToClose) / (positionSize * (10 ** 18));
            if(borrowAmtToPayBack > 0) {

                uint256 collateralAmt = address(this).balance;
                uint256 tokenBalance = swapEthToToken(collateralAmt);
                uint i = 0;

                while (i < 20 && tokenBalance > 0 && borrowAmtToPayBack > 0) {
                    if(tokenBalance < borrowAmtToPayBack) {
                        repayBorrowToken(int256(tokenBalance));
                        uint256 amtToRedeem = (100 * collateralAmt) / ratio ;
                        redeemUnderlyingCollateral(amtToRedeem);

                        borrowAmtToPayBack -= tokenBalance;
                        supplyAmtToWithdraw -= amtToRedeem;
                        collateralAmt = address(this).balance;
                        tokenBalance = swapEthToToken(collateralAmt);
                    } else {
                        repayBorrowToken(int256(borrowAmtToPayBack));
                        redeemUnderlyingCollateral(supplyAmtToWithdraw);
                        positionSize -= (positionSize * calcBorrowBal())/ borrowBalance;
                        tokenBalance = 0;
                        swapTokentoEth(token.balanceOf(address(this)));

                    }

                    i++;
                }

                ownerAddress.transfer(address(this).balance);

            }
        }
    }

     // This function lets the user top up collateral.
    function addCollateral(uint256 collateralAmt) public payable{
        require(msg.sender == ownerAddress);
        if(isLeverage) {
            require(msg.value == collateralAmt);
            mintETH(collateralAmt);
        } else {
            transferInCollateral(collateralAmt);
            mintCollateral(collateralAmt);
        }
    }


}
