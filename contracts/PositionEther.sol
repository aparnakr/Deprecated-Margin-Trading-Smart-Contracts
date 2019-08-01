pragma solidity 0.5.8;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import {CErc20, ComptrollerInterface,  CToken} from "./lib/CErc20.sol";
import {CEther} from "./lib/CEther.sol";
import {UniswapExchangeInterface} from "./lib/uniswap.sol";
import {ERC20Interface} from "./lib/ERC20.sol";
import {Comptroller} from "./lib/Comptroller.sol";


/**
 * @title Opyns's PositionEther Contract
 * @notice Enables Short and long Positions on ETH
 * @author Opyn: Aparna Krishnan, Zubin Koticha, Nadir Akhtar
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


contract PositionEther {
    using SafeMath for uint256;

    // xxx: any reason behind some of these variables being public or private?
    // seems inconsistent

    /// CONSTANTS
    // Kyber payout address
    address private constant KNC_PAYOUT_ADDR = 0x087aC7736469716D73498e479E09119A02D7A59D;
    ERC20Interface private constant ETH = ERC20Interface(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    // Compound contract handling collateral and liquidation
    // See: https://compound.finance/developers#comptroller
    Comptroller private constant TROLL = Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);


    // User's address
    address payable public ownerAddress;
    // Size of position opened
    uint256 public positionSize = 0;
    // Amount of collateral that can be borrowed for each dollar of position supplied
    uint256 public leverageIntensity = 0;
    // True if contract is short, false if long
    // Can only be changed when no positions are open
    bool public isLeverage;

    // xxx: consider setting below to constant since not changing
    // Address of the Contract which deployed this
    address payable private factoryLogicAddress;
    CEther private cETH;

    KyberProxyInterface private tokenExchange;
    ERC20Interface private token;
    CErc20 private cToken;

    uint256 private borrowBalance;
    uint256 private supplyBalance;


    modifier restricted {
        require(
            msg.sender == ownerAddress || msg.sender == factoryLogicAddress,
            "User not allowed to call this function"
        );
        _;
    }

    modifier onlyOwner {
        require(msg.sender == ownerAddress, "Only owner allowed");
        _;
    }

    /**
     * @notice Constructs a new Position Contract
     * @param _ownerAddr is the address of the owner who can call functions on the contract.
     * @param _cethAddr is the address of the cETH contract
     * @param _tokenExchangeAddr is the address of the Dai Exchange address on Uniswap
     * @param _tokenAddr is the address of Dai token
     * @param _cTokenAddr is the address of cDai
     * @param _isLeverage specifies if the contract is a short or long contract
     */
    constructor (
        address payable _ownerAddr,
        // xxx: pretty sure you can take this in as a CEther type, and the same
        // for the rest of the addresses representing contracts
        address payable _cethAddr,
        address _tokenExchangeAddr,
        address _tokenAddr,
        address _cTokenAddr,
        bool _isLeverage
    ) public {
        factoryLogicAddress = msg.sender;
        ownerAddress = _ownerAddr;
        isLeverage = _isLeverage;

        cETH = CEther(_cethAddr);
        tokenExchange = KyberProxyInterface(_tokenExchangeAddr);
        token = ERC20Interface(_tokenAddr);
        cToken = CErc20(_cTokenAddr);
    }

    /**
     * @notice Fallback function to make the contract payable to receive ETH
     * from Kyber or Uniswap.
     */
    function () external payable {}

    function openPosition(
        uint256 collateralAmt,
        uint256 borrowAmt,
        bool _isLeverage
    ) external payable restricted {
        determineTradeType(_isLeverage);
        determineLeverageAmount(130); // xxx: make num constant - short position 1.3x leverage

        if (!_isLeverage) {
            short((1000 * collateralAmt)/1006, borrowAmt); // xxx: move into helper function
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
    function looping(
        uint256 _collateralAmt,
        uint256 _ratio,
        uint256 _leverageIntensity
    ) external payable restricted {
        determineTradeType(true);
        uint256 loopLimit = 20; // xxx: make global
        require(_collateralAmt <= msg.value, "Insufficient funds");

        determineLeverageAmount(_leverageIntensity);
        uint256 borrowAmt = 100001; // xxx: make global
        uint256 i = 0; // xxx: can be uint8
        uint256 priceAmtCollateral;
        uint256 amtToBeSupplied = (_leverageIntensity * _collateralAmt)/100;
        positionSize += _collateralAmt;
        _collateralAmt = (1000 * _collateralAmt) / 1006; // xxx: put fee calculation in helper function -- also avoid assigning to func args
        uint256 amtSupplied = _collateralAmt; // xxx: extraneous variable

        // xxx: manually calculating and transferring fees, circumventing helper func -- fix the helper to handle all cases
        factoryLogicAddress.transfer(address(this).balance - _collateralAmt);

        // xxx: figure out max loop amount
        while (i < loopLimit && _collateralAmt > 10000 && borrowAmt > 10000 && amtSupplied < amtToBeSupplied) {
            mintETH(_collateralAmt);
            // Calculate the amount to be borrowed

            // xxx: should be made global constant
            V1PriceOracleInterface priceContract = V1PriceOracleInterface(0x02557a5E05DeFeFFD4cAe6D83eA3d173B272c904);
            priceAmtCollateral = priceContract.assetPrices(address(token));
            borrowAmt = (_ratio * _collateralAmt * (10 ** 18)) / (100 * priceAmtCollateral); // xxx: move calculations into helper func
            if (borrowAmt > 10000) {
                // Borrow, Swap and add to the position size
                borrow(borrowAmt, true);
                swapTokentoEth(borrowAmt);
            }
            // xxx: move all below into above suite
            _collateralAmt = address(this).balance;
            amtSupplied += _collateralAmt;
            i++;
      }

      mintETH(address(this).balance);
    }

    // This function closes some part of the position.
    function closePosition(
        uint256 collateralAmt,
        uint128 repayAmt, // xxx: why 128 specifically here?
        uint256 withdrawAmt,
        uint256 amtClosed
    ) external payable {
        require(msg.sender == ownerAddress, "Not owner address"); // xxx: why only ownerAddress?
        borrowBalance = calcBorrowBal();
        if(borrowBalance > 0 && !isLeverage) {
            closeShort(collateralAmt, repayAmt, withdrawAmt, amtClosed);
        }
    }

    function closeLooping(
        uint256 positionSizeToClose,
        uint256 ratio,
        uint256 amtTransferredIn
    ) external payable {
        require(msg.sender == ownerAddress, "Not owner address"); // xxx: why only ownerAddress?
        require(
            amtTransferredIn == msg.value,
            "Amount transferred in not equal to msg.value"
        );
        // don't let someone close a position if they are about to get liquidated

        // xxx: unused local variables error and liquidity
        (uint256 error, uint256 liquidity, uint256 shortfall) = getAccountLiquidity();
        require(liquidity > 0, "No liquidity available");

        if (positionSizeToClose == positionSize) {

            // xxx: shadows global variable
            uint256 borrowBalance = calcBorrowBal();
            if(borrowBalance > 0) {

                uint256 collateralAmt = address(this).balance;
                uint256 tokenBalance = swapEthToToken(collateralAmt);
                uint i = 0; // xxx: can be uint8

                // xxx: why is this at most 21? different from 20 elsewhere
                while (i < 21 && tokenBalance > 0 && collateralAmt > 0) {
                    if(tokenBalance < borrowBalance) {
                        repayBorrowToken(int256(tokenBalance));
                        uint256 amtToRedeem = (100 * collateralAmt) / ratio;
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
            // xxx: shadows global variable
            uint256 borrowBalance = calcBorrowBal();
            uint256 borrowAmtToPayBack = (borrowBalance * positionSizeToClose) / positionSize;
            uint256 supplyAmtToWithdraw = (getSupplyBalance() * positionSizeToClose) / (positionSize * (10 ** 18));
            if (borrowAmtToPayBack > 0) {
                uint256 collateralAmt = address(this).balance;
                uint256 tokenBalance = swapEthToToken(collateralAmt);
                uint i = 0; // xxx: can be uint8

                // xxx: 20, not 21
                while (i < 20 && tokenBalance > 0 && borrowAmtToPayBack > 0) {
                    if(tokenBalance < borrowAmtToPayBack) {
                        repayBorrowToken(int256(tokenBalance));
                        uint256 amtToRedeem = (100 * collateralAmt) / ratio;
                        redeemUnderlyingCollateral(amtToRedeem);

                        borrowAmtToPayBack -= tokenBalance;
                        supplyAmtToWithdraw -= amtToRedeem;
                        collateralAmt = address(this).balance;
                        tokenBalance = swapEthToToken(collateralAmt);
                    } else {
                        // xxx: check cast
                        repayBorrowToken(int256(borrowAmtToPayBack));
                        redeemUnderlyingCollateral(supplyAmtToWithdraw);
                        positionSize -= (positionSize * calcBorrowBal()) / borrowBalance;
                        tokenBalance = 0; // xxx: make sure setting to zero is ok
                        swapTokentoEth(token.balanceOf(address(this)));

                    }

                    i++;
                }

                ownerAddress.transfer(address(this).balance);
            }
        }
    }

    // This function lets the user top up collateral.
    function addCollateral(uint256 collateralAmt) external payable onlyOwner {
        if(isLeverage) {
            // xxx: why do you need an input value of collateralAmt? Why not use msg.value directly?
            require(
                msg.value == collateralAmt,
                "collateralAmt not equal to msg.value"
            );

            mintETH(collateralAmt);
        } else {
            // xxx: big worry: why is there no require statement here, like the one above?
            transferInCollateral(collateralAmt);
            mintCollateral(collateralAmt);
        }
    }

    // This function calculates the amount of collateralToSupply to close the entire position.
    function getCollateralToSupply(uint256 repayAmt) external view returns (uint256) {
        uint256 bBal = getBorrowBalance();
        uint256 colToSupply = 0;
        if (bBal > 0 && repayAmt <= bBal) {
            if (!isLeverage) {
                (uint256 amtETH, uint256 slippageRate) = tokenExchange.getExpectedRate(token, ETH, 1000000000000000000); // xxx: make this huge number and the rest global constant
                // How much colToSupply to get repayAmt of ETH?
                // 1000: amtETH :: ? : repayAmt
                colToSupply = 1000000000000000000 * repayAmt / amtETH; // xxx: huge number
            } else {
                // xxx: slippageRate unused
                (uint256 amtToken, uint256 slippageRate) = tokenExchange.getExpectedRate(
                    ETH,
                    token,
                    1000000000000000000  // xxx: huge number
                );
                // How much colToSupply to get repayAmt of token?
                // 1: amtToken :: ? : repayAmt
                colToSupply = 1000000000000000000 * repayAmt / amtToken;
            }
        }

        return colToSupply;
    }

    // This function calculates the supplyBalance balance of the collateral (including interest) from compound
    function getSupplyBalance() public view returns (uint256) {
        if (!isLeverage) {
            return cToken.balanceOf(address(this)) * cToken.exchangeRateStored();
        } else {
            return cETH.balanceOf(address(this)) * cETH.exchangeRateStored();
        }
    }

    function getBorrowBalance() public view returns (uint256) {
        if (!isLeverage) {
            return cETH.borrowBalanceStored(address(this));
        } else {
            return cToken.borrowBalanceStored(address(this));
        }
    }

    /**
     * @notice Function to transfer in the collateral (in the simple case Dai)
     * @param collateralAmt is the number of collateral tokens being transferred in.
     */
    function transferInCollateral(uint256 collateralAmt) private {
        require(collateralAmt > 0, "Cannot have zero collateral amount");
        require(
            token.transferFrom(msg.sender, address(this), collateralAmt), "Could not transfer token from account"
        );
    }

    /**
     * @notice Function to transfer in ETH.
     * @param amt is the amount of ETH tokens being transferred in.
     */
    function mintETH(uint256 amt) private {
        require(amt > 0, "Cannot mint zero ETH");
        cETH.mint.value(amt)();
    }

    /**
     * @notice This function mints a new compound cCollateral token.
     * @param amt is the amount of underlying tokens being used to mint corresponding cTokens.
     */
    function mintCollateral(uint256 amt) private {
        require(amt > 0, "Cannot mint zero tokens");
        token.approve(address(cToken), amt); // approve the transfer
        assert(cToken.mint(amt) == 0); // mint the cTokens and assert there is no error
    }

    // xxx: isLeverage shadows global value
    function borrow(uint256 amt, bool isLeverage) private {
        require(amt >= 0); // xxx: tautology - meant just ">"?
        address[] memory ct = new address[](2);
        ct[0] = address(cETH);
        ct[1] = address(cToken);
        uint256[] memory errors = TROLL.enterMarkets(ct);
        require(errors[0] == 0, "cETH failed");
        require(errors[1] == 0, "cToken failed");
        if (isLeverage) {
            // borrow the token if long position
            uint256 error = cToken.borrow(amt);
            assert(error == 0);
        } else {
            // borrow the ETH if short position
            uint256 error = cETH.borrow(amt);
            assert(error == 0);
        }
    }

    function swapTokentoEth(uint256 amt) private returns (uint256) {
        require(amt >= 0); // xxx: tautology
        (uint256 minConversionRate, uint256 slippageRate) = tokenExchange.getExpectedRate(
            token, ETH, amt
        );  // xxx: minConversionRate and slippage never used
        token.approve(address(tokenExchange), 1000000000000000000000000000000000000000); // xxx: make global
        return tokenExchange.trade(token, amt, ETH, address(this), 2**255, 0, KNC_PAYOUT_ADDR);
    }

    function swapEthToToken(uint256 amt) private returns (uint256) {
        require(amt >= 0); // xxx: tautology
        (uint256 minConversionRate, uint256 slippageRate) = tokenExchange.getExpectedRate(
            ETH, token, amt
        ); // xxx: minConversionRate and slippage never used
       return tokenExchange.trade.value(amt)(ETH, amt, token, address(this), 2**255, 0, KNC_PAYOUT_ADDR);
    }

    function transferOutTokens(uint256 amt) private {
        token.approve(ownerAddress, amt); // xxx: unneeded and dangerous approve
        token.transfer(ownerAddress, amt);
    }

    function short(uint256 colAmt, uint256 amtToShort) private {
         transferInCollateral(colAmt);
         mintCollateral(colAmt);
         borrow(amtToShort, false);
         uint256 numTokens = swapEthToToken(amtToShort);
         transferOutTokens(numTokens);
    }

    function determineTradeType(bool _isLeverage) private {
        // Ensure this is an 'l' or an 's'
        if (isLeverage != _isLeverage) {
            calcBorrowBal();
            require(borrowBalance == 0, "borrowBalance must be zero");
            isLeverage = _isLeverage;
        }
    }

    function transferFees() private {
        if(isLeverage) {
            factoryLogicAddress.transfer(address(this).balance);
        } else {
            uint256 tokenBal = token.balanceOf(address(this));
            token.approve(factoryLogicAddress, tokenBal);
            token.transfer(factoryLogicAddress, tokenBal);
        }
    }

    function determineLeverageAmount(uint256 _leverageIntensity) private {
        if(isLeverage) {
            if (leverageIntensity == 0){
                leverageIntensity = _leverageIntensity;
            } else {
                require(
                    leverageIntensity == _leverageIntensity,
                    "Leverage intensities not equal"
                );
            }
        }
    }

    // This function calculates the borrow balance of the token (including interest) from compound
    function calcBorrowBal() private returns (uint256) {
        if (!isLeverage) {
            borrowBalance = cETH.borrowBalanceCurrent(address(this));
        } else {
            borrowBalance = cToken.borrowBalanceCurrent(address(this));
        }
        return borrowBalance;
    }

        function repayBorrowToken(int256 borrowAmt) private {
        // TODO: ensure no issues with casting
        if (!isLeverage) {
            cETH.repayBorrow.value(uint256(borrowAmt))();
        } else {
            token.approve(address(cToken), 1000000000000000000000000000000000000000); // xxx: make constant
            require(
                cToken.repayBorrow(uint256(borrowAmt)) == 0,
                "cToken borrow failed"
            );
        }
    }

    // This function gets back the supplied collateral from compound
    function redeemCollateral(uint256 collateralAmt) private {
         if (!isLeverage) {
            require(cToken.redeem(collateralAmt) == 0, "cToken redeem failed");
         } else {
            require(cETH.redeem(collateralAmt) == 0, "cETH redeem failed");
         }
    }

    function redeemUnderlyingCollateral(uint256 collateralAmt) private {
        require(isLeverage, "Contract not in leverage state");
        require(
            cETH.redeemUnderlying(collateralAmt) == 0,
            "Could not redeem collateral"
        );
    }

    // This function sends the remaining intermediate tokens as fees to the factory contract
    function transferRemaining() private {
        uint256 tokenBal = token.balanceOf(address(this));
        token.approve(factoryLogicAddress, tokenBal); // xxx: dangerous approve
        token.transfer(factoryLogicAddress, tokenBal);
        ownerAddress.transfer(address(this).balance);
    }

    function closeShort(
        uint256 collateralAmt,
        uint128 repayAmt,
        uint256 withdrawAmt,
        uint256 amtClosed
    ) private {
        transferInCollateral(collateralAmt);
        uint256 tokenBalance = swapTokentoEth(collateralAmt);
        if (positionSize == amtClosed) {
            require(
                tokenBalance >= borrowBalance,
                "tokenBalance less than borrowBalance"
            );
            repayBorrowToken(int256(calcBorrowBal()));
            redeemCollateral(calcSupplyBalance());
            transferOutTokens(token.balanceOf(address(this)));
            transferRemaining ();
            positionSize -= amtClosed;
        } else {
            require(repayAmt > 0, "Need nonzero repayAmt");
            require(
                tokenBalance >= repayAmt,
                "tokenBalance less than repayAmt"
            );

            // xxx: ensure no issue with casting
            repayBorrowToken(int256(repayAmt));
            redeemCollateral(withdrawAmt/cToken.exchangeRateStored());
            transferOutTokens(token.balanceOf(address(this)));
            transferRemaining();
            require(
                amtClosed <= positionSize,
                "amtClosed greater than positionSize"
            );
            positionSize -= amtClosed;
        }
    }

    // This function calculates the supplyBalance balance of the collateral (including interest) from Compound
    function calcSupplyBalance() private view returns (uint256) {
        if(!isLeverage){
            return cToken.balanceOf(address(this)) ;
        } else {
            return cETH.balanceOf(address(this));
        }
    }

    function getAccountLiquidity() private view returns (
        uint256,
        uint256,
        uint256
    ) {
        return TROLL.getAccountLiquidity(address(this));
    }
}
