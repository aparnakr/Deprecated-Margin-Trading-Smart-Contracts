import _ from 'lodash';
import uuidV4 from 'uuid/V4';
import {web3, util} from './init.js';
import {PERIOD_TYPE, LOAN_STATE} from './utils/Constants.js';
import LoanFactory from './utils/LoanFactory.js';
import {LoanCreated, LoanTermBegin,
    LoanBidsRejected, PeriodicRepayment,
    ValueRedeemed, Transfer, Approval} from './utils/LoanEvents.js'
import expect from 'expect.js';
import Random from 'random-js';

const Loan = artifacts.require("./Loan.sol");
contract("Loan", (accounts) => {
    const TERMS_SCHEMA_VERSION = "0.1.0";
    const LOAN_DATA = {
        uuid: web3.sha3(uuidV4()),
        borrower: accounts[0],
        principal: web3.toWei(1, 'ether'),
        terms: {
            version: web3.sha3(TERMS_SCHEMA_VERSION),
            periodType: PERIOD_TYPE.WEEKLY,
            periodLength: 1,
            termLength: 4,
            compounded: true
        },
        attestor: accounts[1],
        attestorFee: web3.toWei(0.001, 'ether'),
        defaultRisk: web3.toWei(0.73, 'ether')
    };
    const LOAN = LoanFactory.generateSignedLoan(LOAN_DATA);
    const AUCTION_LENGTH_IN_BLOCKS = 20;
    const REVIEW_PERIOD_IN_BLOCKS = 32;
    const INVESTORS = accounts.slice(2,9);

    let loan;
    let loanFactory;
    let loanCreatedBlockNumber;
    let bids = {};

    before(async () => {
        loan = await Loan.deployed();
        loanFactory = new LoanFactory(loan);
    })

    describe("#createLoan()", () => {
        it("should successfuly create loan request", async () => {
            const result = await loan.createLoan(
                LOAN.uuid,
                LOAN.borrower,
                LOAN.principal,
                LOAN.terms,
                LOAN.attestor,
                LOAN.attestorFee,
                LOAN.defaultRisk,
                LOAN.signature.r,
                LOAN.signature.s,
                LOAN.signature.v,
                AUCTION_LENGTH_IN_BLOCKS,
                REVIEW_PERIOD_IN_BLOCKS
            )

            util.assertEventEquality(result.logs[0], LoanCreated({
                uuid: LOAN.uuid,
                borrower: LOAN.borrower,
                attestor: LOAN.attestor,
                blockNumber: result.receipt.blockNumber
            }))

            // Save the latest block in which the loan was created
            loanCreatedBlockNumber = result.receipt.blockNumber;

        });

        it("should throw on a loan request with a duplicate UUID to be created", async() => {
            try {
                await loan.createLoan(
                    LOAN.uuid,
                    LOAN.borrower,
                    LOAN.principal,
                    LOAN.terms,
                    LOAN.attestor,
                    LOAN.attestorFee,
                    LOAN.defaultRisk,
                    LOAN.signature.r,
                    LOAN.signature.s,
                    LOAN.signature.v,
                    AUCTION_LENGTH_IN_BLOCKS,
                    REVIEW_PERIOD_IN_BLOCKS
                )
                expect().fail("should throw error");
            } catch (err) {
                util.assertThrowMessage(err);
            }
        })

        it("should throw on a loan request with a zero block auction length", async() => {
            try {
                await loan.createLoan(
                    web3.sha3(uuidV4()),
                    LOAN.borrower,
                    LOAN.principal,
                    LOAN.terms,
                    LOAN.attestor,
                    LOAN.attestorFee,
                    LOAN.defaultRisk,
                    LOAN.signature.r,
                    LOAN.signature.s,
                    LOAN.signature.v,
                    0,
                    REVIEW_PERIOD_IN_BLOCKS
                )
                expect().fail("should throw error");
            } catch (err) {
                util.assertThrowMessage(err);
            }
        })

        it("should throw on a loan request with a zero block review period length", async() => {
            try {
                await loan.createLoan(
                    web3.sha3(uuidV4()),
                    LOAN.borrower,
                    LOAN.principal,
                    LOAN.terms,
                    LOAN.attestor,
                    LOAN.attestorFee,
                    LOAN.defaultRisk,
                    LOAN.signature.r,
                    LOAN.signature.s,
                    LOAN.signature.v,
                    AUCTION_LENGTH_IN_BLOCKS,
                    0
                )
                expect().fail("should throw error");
            } catch (err) {
                util.assertThrowMessage(err);
            }
        })
    })

    describe('#getters', () => {
        it('should get borrower', async () => {
            const borrower = await loan.getBorrower.call(LOAN.uuid);
            expect(borrower).to.be(LOAN.borrower);
        })

        it('should get principal', async() => {
            const principal = await loan.getPrincipal.call(LOAN.uuid);
            expect(principal.equals(LOAN.principal)).to.be(true);
        })

        it('should get terms', async() => {
            const terms = await loan.getTerms.call(LOAN.uuid);
            expect(terms).to.be(LOAN.terms);
        })

        it('should get attestor', async() => {
            const attestor = await loan.getAttestor.call(LOAN.uuid);
            expect(attestor).to.be(LOAN.attestor);
        })

        it('should get attestorFee', async() => {
            const attestorFee = await loan.getAttestorFee.call(LOAN.uuid);
            expect(attestorFee.equals(LOAN.attestorFee)).to.be(true);
        })

        it('should get defaultRisk', async() => {
            const defaultRisk = await loan.getDefaultRisk.call(LOAN.uuid);
            expect(defaultRisk.equals(LOAN.defaultRisk)).to.be(true);
        })

        it('should get the ECDSA signature', async() => {
            const signature = await loan.getAttestorSignature.call(LOAN.uuid);
            expect(signature[0]).to.be(LOAN.signature.r);
            expect(signature[1]).to.be(LOAN.signature.s);
            expect(signature[2].equals(LOAN.signature.v)).to.be(true);
        })

        it('should get auction end block', async() => {
            const auctionEndBlock = await loan.getAuctionEndBlock.call(LOAN.uuid);
            const expectedAuctionEndBlock =
                loanCreatedBlockNumber + AUCTION_LENGTH_IN_BLOCKS;
            expect(auctionEndBlock.equals(expectedAuctionEndBlock)).to.be(true);
        })

        it('should get review period end block', async() => {
            const reviewPeriodEndBlock = await loan.getReviewPeriodEndBlock.call(LOAN.uuid);
            const expectedReviewPeriodEndBlock =
                loanCreatedBlockNumber + AUCTION_LENGTH_IN_BLOCKS + REVIEW_PERIOD_IN_BLOCKS;
            expect(reviewPeriodEndBlock.equals(expectedReviewPeriodEndBlock)).to.be(true);
        })

        it("should get entire data packet", async() => {
            const data = await loan.getData.call(LOAN.uuid);
            expect(data[0]).to.be(LOAN.borrower);
            expect(data[1].equals(LOAN.principal)).to.be(true);
            expect(data[2]).to.be(LOAN.terms);
            expect(data[3]).to.be(LOAN.attestor);
            expect(data[4].equals(LOAN.attestorFee)).to.be(true);
            expect(data[5].equals(LOAN.defaultRisk)).to.be(true);
        })
    })

    describe('#bid()', () => {
        it('should allow investors to bid during the auction period', async () => {
            await Promise.all(INVESTORS.map(async function(investor) {
                const amount = Random().real(0.4, 0.7);
                const minInterestRate = Random().real(0.1, 0.2);

                bids[investor] = {
                    amount: web3.toWei(amount, 'ether'),
                    minInterestRate: web3.toWei(minInterestRate, 'ether')
                }

                await loan.bid(
                    LOAN.uuid,
                    investor,
                    bids[investor].minInterestRate,
                    { from: investor, value: bids[investor].amount }
                )
            }))

            const numBids = await loan.getNumBids.call(LOAN.uuid);
            for (let i = 0; i < numBids; i++) {
                let bid = await loan.getBidByIndex.call(LOAN.uuid, i);
                let investor = bid[0];
                expect(bid[1].equals(bids[investor].amount)).to.be(true);
                expect(bid[2].equals(bids[investor].minInterestRate)).to.be(true);
            }
        })

        it('should throw if investor tries to bid twice', async () => {
            try {
                await loan.bid(
                    LOAN.uuid,
                    INVESTORS[0],
                    web3.toWei(0.1, 'ether'),
                    { from: INVESTORS[0], value: web3.toWei(0.1, 'ether') }
                )
                expect().fail("should throw error")
            } catch (err) {
                util.assertThrowMessage(err);
            }
        })

        it('should throw if borrower accepts terms before auction period ends', async () => {
            try {
                await loan.acceptBids(LOAN.uuid, INVESTORS.slice(0,5),
                    [web3.toWei(0.2, 'ether'), web3.toWei(0.2, 'ether'),
                        web3.toWei(0.2, 'ether'), web3.toWei(0.2, 'ether'),
                        web3.toWei(0.2, 'ether')],
                    { from: LOAN.borrower })
                expect().fail("should throw error");
            } catch (err) {
                util.assertThrowMessage(err);
            }
        })

        it('should throw if borrower rejects terms before auction period ends', async () => {
            try {
                await loan.rejectBids(LOAN.uuid);
                expect().fail("should throw error");
            } catch (err) {
                util.assertThrowMessage(err);
            }
        })

        it('should not allow investors to bid after the auction period', async () => {
            try {
                //await util.setBlockNumberForward(8);
                await loan.bid(
                    LOAN.uuid,
                    INVESTORS[0],
                    web3.toWei(0.1, 'ether'),
                    { from: INVESTORS[0], value: web3.toWei(0.1, 'ether') }
                )
                expect().fail("should throw error")
            } catch (err) {
                util.assertThrowMessage(err)
            }
        })
    })

    describe('#acceptBids()', () => {
        it ("should throw when non-borrower tries to accept terms", async () => {
            try {
                await loan.acceptBids(LOAN.uuid, INVESTORS.slice(0, 5),
                    [web3.toWei(0.2, 'ether'), web3.toWei(0.2, 'ether'),
                        web3.toWei(0.2, 'ether'), web3.toWei(0.2, 'ether'),
                        web3.toWei(0.201, 'ether')],
                    { from: LOAN.attestor })
                expect().fail("should throw error");
            } catch (err) {
                util.assertThrowMessage(err);
            }
        })

        it ('should throw when borrower accepts w/o full principal+fee raised', async () => {
            try {
                await loan.acceptBids(LOAN.uuid, INVESTORS.slice(0, 3),
                    [web3.toWei(0.3, 'ether'),
                        web3.toWei(0.4, 'ether'), web3.toWei(0.3, 'ether')],
                    { from: LOAN.borrower })
                expect().fail("should throw error");
            } catch (err) {
                util.assertThrowMessage(err);
            }
        })

        it ('should throw when borrower accepts w/ > full principal+fee amount', async () => {
            try {
                await loan.acceptBids(LOAN.uuid, INVESTORS.slice(0, 6),
                    [web3.toWei(0.2, 'ether'), web3.toWei(0.2, 'ether'),
                        web3.toWei(0.2, 'ether'), web3.toWei(0.2, 'ether'),
                        web3.toWei(0.2, 'ether'), web3.toWei(0.2, 'ether')],
                    { from: LOAN.borrower })
                expect().fail("should throw error");
            } catch (err) {
                util.assertThrowMessage(err);
            }
        })

        it ('should throw when borrower accepts w/ non-investors', async () => {
            try {
                await loan.acceptBids(LOAN.uuid, INVESTORS.slice(0, 4).concat(LOAN.attestor),
                    [web3.toWei(0.2, 'ether'), web3.toWei(0.2, 'ether'),
                        web3.toWei(0.2, 'ether'), web3.toWei(0.2, 'ether'),
                        web3.toWei(0.2, 'ether')],
                    { from: LOAN.borrower })
                expect().fail("should throw error");
            } catch (err) {
                util.assertThrowMessage(err);
            }
        })

        it ('should throw when borrower accepts w/ > than any investor bid', async () => {
            try {
                await loan.acceptBids(LOAN.uuid, INVESTORS.slice(0, 5),
                    [web3.toWei(0.1, 'ether'), web3.toWei(0.1, 'ether'),
                        web3.toWei(0.75, 'ether'), web3.toWei(0.025, 'ether'),
                        web3.toWei(0.025, 'ether')],
                    { from: LOAN.borrower })
                expect().fail("should throw error");
            } catch (err) {
                util.assertThrowMessage(err);
            }
        })

        // it ('should throw when borrower accepts w/ > 10 investors', async () => {
        //     try {
        //         await loan.acceptBids(LOAN.uuid, INVESTORS.slice(0, 11),
        //             [web3.toWei(0.1, 'ether'), web3.toWei(0.1, 'ether'),
        //                 web3.toWei(0.1, 'ether'), web3.toWei(0.1, 'ether'),
        //                 web3.toWei(0.1, 'ether'), web3.toWei(0.1, 'ether'),
        //                 web3.toWei(0.1, 'ether'), web3.toWei(0.1, 'ether'),
        //                 web3.toWei(0.05, 'ether'), web3.toWei(0.05, 'ether'),],
        //             { from: LOAN.borrower })
        //         expect().fail("should throw error");
        //     } catch (err) {
        //         util.assertThrowMessage(err);
        //     }
        // })

        it ('should allow borrower to accept w/ < 10 investors and full principal+fee', async () => {
            const borrowerBalanceBefore = web3.eth.getBalance(LOAN.borrower);
            const attestorBalanceBefore = web3.eth.getBalance(LOAN.attestor);
            const bidAmountsAccepted = [
                web3.toWei(0.2, 'ether'),
                web3.toWei(0.2, 'ether'),
                web3.toWei(0.2, 'ether'),
                web3.toWei(0.2, 'ether'),
                web3.toWei(0.201, 'ether')
            ]

            const result = await loan.acceptBids(LOAN.uuid, INVESTORS.slice(0, 5),
                bidAmountsAccepted, { from: LOAN.borrower })

            const gasCosts = await util.getGasCosts(result);
            const borrowerBalanceAfter = web3.eth.getBalance(LOAN.borrower);
            const attestorBalanceAfter = web3.eth.getBalance(LOAN.attestor);

            expect(borrowerBalanceAfter
                .minus(borrowerBalanceBefore).plus(gasCosts).equals(LOAN.principal))
                .to.be(true, "balance delta is not principal")

            expect(attestorBalanceAfter
                .minus(attestorBalanceBefore).equals(LOAN.attestorFee))
                .to.be(true, "attestor delta is not attestorFee")

            const state = await loan.getState.call(LOAN.uuid);
            expect(state.equals(LOAN_STATE.ACCEPTED)).to.be(true, "wrong state");

            util.assertEventEquality(result.logs[0], LoanTermBegin({
                uuid: LOAN.uuid,
                borrower: LOAN.borrower,
                blockNumber: result.receipt.blockNumber
            }))

            for (let i = 0; i < 5; i++) {
                const totalInvested =
                    web3.toBigNumber(LOAN.principal).plus(LOAN.attestorFee)
                const expectedBalance =
                    web3.toBigNumber(bidAmountsAccepted[i])
                        .times(LOAN.principal)
                        .div(totalInvested)
                        .trunc();

                let balance = await loan.balanceOf(LOAN.uuid, INVESTORS[i]);

                expect(balance.equals(expectedBalance)).to.be(true);
            }

            let nonInvestorBalance = await loan.balanceOf(LOAN.uuid, INVESTORS[5])
            expect(nonInvestorBalance.equals(0)).to.be(true);

            const acceptedBidsInterestRates =
                INVESTORS.slice(0, 5)
                    .map((investor) => { return bids[investor].minInterestRate })

            const expectedInterestRate = web3.BigNumber.max(acceptedBidsInterestRates)
            const acceptedInterestRate = await loan.getInterestRate.call(LOAN.uuid)
            expect(expectedInterestRate.equals(acceptedInterestRate)).to.be(true);
        })

        it('should throw if borrower tries to reject after accepting', async () => {
            try {
                await loan.rejectBids(LOAN.uuid);
                expect().fail("should throw error");
            } catch (err) {
                util.assertThrowMessage(err);
            }
        })
    })

    describe('#rejectBids()', () => {
        let loanInReview = _.cloneDeep(LOAN_DATA);
        let bids = [
            {
                bidder: INVESTORS[0],
                amount: 1.0,
                minInterestRate: 0.1
            }
        ]

        beforeEach(async () => {
            loanInReview.uuid = web3.sha3(uuidV4());
            await loanFactory.generateReviewStateLoan(loanInReview, bids);
        })

        it('should allow a borrower to reject the bids', async () => {
            const auctionEndBlock = await loan.getAuctionEndBlock.call(loanInReview.uuid)
            const reviewPeriodEndBlock = await loan.getReviewPeriodEndBlock.call(loanInReview.uuid)

            const result = await loan.rejectBids(loanInReview.uuid);

            util.assertEventEquality(result.logs[0], LoanBidsRejected({
                uuid: loanInReview.uuid,
                borrower: loanInReview.borrower,
                blockNumber: result.receipt.blockNumber
            }));

            const state = await loan.getState.call(loanInReview.uuid);
            expect(state.equals(LOAN_STATE.REJECTED)).to.be(true);

        })

        it('should throw when non-borrower tries to reject the bids', async () => {
            try {
                await loan.rejectBids(loanInReview.uuid, { from: loanInReview.attestor });
                expect().fail("should throw error");
            } catch (err) {
                util.assertThrowMessage(err);
            }
        })
    })

    describe('#withdrawInvestment()', () => {
        let withdrawalTestLoan = _.cloneDeep(LOAN_DATA);

        describe('State: Auction', () => {
            before(async () => {
                let auctionPeriod = 5;
                let reviewPeriod = 100;

                withdrawalTestLoan.uuid = web3.sha3(uuidV4());
                await loanFactory.generateAuctionStateLoan(withdrawalTestLoan,
                    auctionPeriod, reviewPeriod);

                await loan.bid(
                    withdrawalTestLoan.uuid,
                    INVESTORS[0],
                    web3.toWei(0.1, 'ether'),
                    { value: web3.toWei(0.3, 'ether') }
                )
            })

            it('should not allow auction non-participants to withdraw', async () => {
                try {
                    await loan.withdrawInvestment(withdrawalTestLoan.uuid,
                        { from: INVESTORS[1] })
                    expect().fail("should throw error");
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })

            it('should not allow auction participants to withdraw', async () => {
                try {
                    await loan.withdrawInvestment(withdrawalTestLoan.uuid,
                        { from: INVESTORS[0] })
                    expect().fail("should throw error");
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })
        })

        describe('State: Review', () => {
            before(async () => {
                bids = [];
                for (let i = 0; i < 5; i++) {
                    bids.push({
                        bidder: INVESTORS[i],
                        amount: Random().real(0.2, 0.3),
                        minInterestRate: Random().real(0.1, 0.2)
                    })
                }
                withdrawalTestLoan.uuid = web3.sha3(uuidV4());
                await loanFactory.generateReviewStateLoan(withdrawalTestLoan, bids);
            })

            it('should not allow auction non-participants to withdraw', async () => {
                try {
                    await loan.withdrawInvestment(withdrawalTestLoan.uuid,
                        { from: withdrawalTestLoan.attestor })
                    expect().fail("should throw error");
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })

            it('should not allow auction participants to withdraw', async () => {
                try {
                    await loan.withdrawInvestment(withdrawalTestLoan.uuid,
                        { from: INVESTORS[0] })
                    expect().fail("should throw error");
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })
        })

        describe('State: Accepted', () => {
            let bids = [];
            for (let i = 0; i < INVESTORS.length; i++) {
                bids.push({
                    bidder: INVESTORS[i],
                    amount: Random().real(0.2, 0.3),
                    minInterestRate: Random().real(0.1, 0.2)
                })
            }

            let acceptedBids = []
            for (let i = 0; i < 5; i++) {
                const amount = i == 4 ? 0.201 : 0.2; // include attestorFee in last bid
                acceptedBids.push({
                    bidder: INVESTORS[i],
                    amount: amount
                })
            }

            before(async () => {
                withdrawalTestLoan.uuid = web3.sha3(uuidV4());
                await loanFactory.generateAcceptedStateLoan(withdrawalTestLoan,
                    bids, acceptedBids);
            })

            it('should not allow auction non-participants to withdraw', async () => {
                try {
                    await loan.withdrawInvestment(withdrawalTestLoan.uuid,
                        { from: withdrawalTestLoan.attestor })
                    expect().fail("should throw error");
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })

            it('should allow auction participants to withdraw', async () => {
                for (let i = 0; i < INVESTORS.length; i++) {
                    const balanceBefore = web3.eth.getBalance(INVESTORS[i]);
                    const result = await loan.withdrawInvestment(withdrawalTestLoan.uuid,
                        { from: INVESTORS[i] })
                    const balanceAfter = web3.eth.getBalance(INVESTORS[i]);
                    const gasCosts = await util.getGasCosts(result);
                    const investmentAmount = i < 5 ? acceptedBids[i].amount : 0;
                    const bidAmount = web3.toBigNumber(bids[i].amount)
                    const expectedRefund =
                        web3.toWei(bidAmount.minus(investmentAmount), 'ether');

                    expect(balanceAfter
                        .minus(balanceBefore)
                        .plus(gasCosts)
                        .equals(expectedRefund))
                        .to.be(true);
                }
            })

            it('should not allow auction participants to withdraw twice', async () => {
                try {
                    await loan.withdrawInvestment(withdrawalTestLoan.uuid,
                        { from: INVESTORS[0] })
                    expect().fail("should throw error")
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })
        })

        describe('State: Rejected', () => {
            let bids = [];
            for (let i = 0; i < INVESTORS.length; i++) {
                bids.push({
                    bidder: INVESTORS[i],
                    amount: Random().real(0.2, 0.3),
                    minInterestRate: Random().real(0.1, 0.2)
                })
            }

            before(async () => {
                withdrawalTestLoan.uuid = web3.sha3(uuidV4());
                await loanFactory.generateRejectedStateLoan(withdrawalTestLoan, bids);
            })

            it('should not allow auction non-participants to withdraw', async () => {
                try {
                    await loan.withdrawInvestment(withdrawalTestLoan.uuid,
                        { from: withdrawalTestLoan.attestor })
                    expect().fail("should throw error");
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })

            it('should allow auction participants to withdraw', async () => {
                for (let i = 0; i < INVESTORS.length; i++) {
                    const balanceBefore = web3.eth.getBalance(INVESTORS[i]);
                    const result = await loan.withdrawInvestment(withdrawalTestLoan.uuid,
                        { from: INVESTORS[i] })
                    const balanceAfter = web3.eth.getBalance(INVESTORS[i]);
                    const gasCosts = await util.getGasCosts(result);

                    expect(balanceAfter
                        .minus(balanceBefore)
                        .plus(gasCosts)
                        .equals(web3.toWei(bids[i].amount, 'ether'))).to.be(true);
                }
            })

            it('should not allow auction participants to withdraw twice', async () => {
                try {
                    await loan.withdrawInvestment(withdrawalTestLoan.uuid,
                        { from: INVESTORS[0] })
                    expect().fail("should throw error")
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })
        })
    })

    describe('#periodicRepayment()', () => {
        let repaymentTestLoan = _.cloneDeep(LOAN_DATA);

        describe('State: Auction', () => {
            before(async () => {
                repaymentTestLoan.uuid = web3.sha3(uuidV4());
                await loanFactory.generateAuctionStateLoan(repaymentTestLoan, 1, 1);
            })

            it('should throw if periodicRepayment attempted', async () => {
                try {
                    await loan.periodicRepayment(repaymentTestLoan.uuid,
                        { value: web3.toWei(1, 'ether') })
                    expect().fail("should throw error");
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })
        })

        describe('State: Review', () => {
            let bids = [{
                bidder: INVESTORS[0],
                minInterestRate: 0.1,
                amount: 0.1
            }]

            before(async () => {
                repaymentTestLoan.uuid = web3.sha3(uuidV4());
                await loanFactory.generateReviewStateLoan(repaymentTestLoan, bids);
            })

            it('should throw if periodicRepayment attempted', async () => {
                try {
                    await loan.periodicRepayment(repaymentTestLoan.uuid,
                        { value: web3.toWei(1, 'ether') })
                    expect().fail("should throw error");
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })
        })

        describe('State: Accepted', () => {
            let bids = [{
                bidder: INVESTORS[0],
                minInterestRate: 0.1,
                amount: 1.001
            }]

            let acceptedBids = [{
                bidder: INVESTORS[0],
                amount: 1.001
            }]

            before(async () => {
                repaymentTestLoan.uuid = web3.sha3(uuidV4());
                await loanFactory.generateAcceptedStateLoan(repaymentTestLoan, bids,
                    acceptedBids);
            })

            it('should throw if borrower repays with 0 value', async () => {
                try {
                    await loan.periodicRepayment(repaymentTestLoan.uuid,
                        { value: 0 })
                    expect().fail("should throw error");
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })

            it('should allow borrower to periodically repay', async () => {
                const result = await loan.periodicRepayment(repaymentTestLoan.uuid,
                    { value: web3.toWei(1, 'ether') })
                const amountRepaid = await loan.getAmountRepaid.call(repaymentTestLoan.uuid);
                expect(amountRepaid.equals(web3.toWei(1, 'ether'))).to.be(true);
                util.assertEventEquality(result.logs[0], PeriodicRepayment({
                    uuid: repaymentTestLoan.uuid,
                    from: repaymentTestLoan.borrower,
                    value: web3.toWei(1, 'ether'),
                    blockNumber: result.receipt.blockNumber
                }))
            })
        })

        describe('State: Rejected', () => {
            let bids = [{
                bidder: INVESTORS[0],
                minInterestRate: 0.1,
                amount: 1.01
            }]

            before(async () => {
                repaymentTestLoan.uuid = web3.sha3(uuidV4());
                await loanFactory.generateRejectedStateLoan(repaymentTestLoan, bids);
            })

            it('should throw if periodicRepayment attempted', async () => {
                try {
                    await loan.periodicRepayment(repaymentTestLoan.uuid,
                        { value: web3.toWei(1, 'ether') })
                    expect().fail("should throw error");
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            });
        })
    })

    describe('RedeemableToken', () => {
        let redeemableTokenTestLoan = _.cloneDeep(LOAN_DATA);
        const bids = [
            {
                bidder: INVESTORS[0],
                amount: 0.2002,
                minInterestRate: 0.1
            },
            {
                bidder: INVESTORS[1],
                amount: 0.8008,
                minInterestRate: 0.1
            }
        ]
        const acceptedBids = [
            {
                bidder: INVESTORS[0],
                amount: 0.2002,
            },
            {
                bidder: INVESTORS[1],
                amount: 0.8008,
            }
        ]

        before(async () => {
            redeemableTokenTestLoan.uuid = web3.sha3(uuidV4());
            await loanFactory.generateAcceptedStateLoan(redeemableTokenTestLoan,
                bids, acceptedBids);

        })

        describe("first repayment", async () => {
            const expectedInvestorOneRedeemable = web3.toWei(0.1, 'ether');
            const expectedInvestorTwoRedeemable = web3.toWei(0.4, 'ether');

            before(async () => {
                await loan.periodicRepayment(redeemableTokenTestLoan.uuid,
                    { value: web3.toWei(0.5, 'ether') })
            });

            describe('getRedeemableValue() before', () => {
                it('should retrieve correct values', async () => {
                    const investorOneRedeemable =
                        await loan.getRedeemableValue
                            .call(redeemableTokenTestLoan.uuid, INVESTORS[0])
                    const investorTwoRedeemable =
                        await loan.getRedeemableValue
                            .call(redeemableTokenTestLoan.uuid, INVESTORS[1])

                    expect(investorOneRedeemable.equals(expectedInvestorOneRedeemable))
                        .to.be(true)
                    expect(investorTwoRedeemable.equals(expectedInvestorTwoRedeemable))
                        .to.be(true)
                })
            })

            describe('redeemValue()', () => {
                it('should redeem the correct amount for investor 1', async () => {
                    const balanceBefore = web3.eth.getBalance(INVESTORS[0])
                    const result = await loan.redeemValue(redeemableTokenTestLoan.uuid,
                        INVESTORS[0], { from: INVESTORS[0] });
                    const gasCosts = await util.getGasCosts(result);
                    const balanceAfter = web3.eth.getBalance(INVESTORS[0])
                    const amountRedeemed =
                        balanceAfter.minus(balanceBefore).plus(gasCosts);

                    expect(amountRedeemed.equals(expectedInvestorOneRedeemable)).to.be(true);

                    util.assertEventEquality(result.logs[0], ValueRedeemed({
                        uuid: redeemableTokenTestLoan.uuid,
                        investor: INVESTORS[0],
                        recipient: INVESTORS[0],
                        value: expectedInvestorOneRedeemable,
                        blockNumber: result.receipt.blockNumber
                    }))
                })

                it('should not let investor 1 redeem any more value', async () => {
                    try {
                        await loan.redeemValue(redeemableTokenTestLoan.uuid,
                            INVESTORS[0], { from: INVESTORS[0] });
                        expect().fail("should throw error");
                    } catch (err) {
                        util.assertThrowMessage(err)
                    }
                })
            })
        })

        describe('second repayment', async () => {
            const expectedInvestorOneRedeemable = web3.toWei(0.06, 'ether');
            const expectedInvestorTwoRedeemable = web3.toWei(0.64, 'ether');

            before(async () => {
                await loan.periodicRepayment(redeemableTokenTestLoan.uuid,
                    { value: web3.toWei(0.3, 'ether') })
            });

            describe('getRedeemableValue() before', () => {
                it('should retrieve correct values', async () => {
                    const investorOneRedeemable =
                        await loan.getRedeemableValue
                            .call(redeemableTokenTestLoan.uuid, INVESTORS[0])
                    const investorTwoRedeemable =
                        await loan.getRedeemableValue
                            .call(redeemableTokenTestLoan.uuid, INVESTORS[1])

                    expect(investorOneRedeemable.equals(expectedInvestorOneRedeemable))
                        .to.be(true)
                    expect(investorTwoRedeemable.equals(expectedInvestorTwoRedeemable))
                        .to.be(true)
                })
            })

            describe('redeemValue()', () => {
                it('should redeem the correct amount for investor 1', async () => {
                    const balanceBefore = web3.eth.getBalance(INVESTORS[0])
                    const result = await loan.redeemValue(redeemableTokenTestLoan.uuid,
                        INVESTORS[0], { from: INVESTORS[0] });
                    const gasCosts = await util.getGasCosts(result);
                    const balanceAfter = web3.eth.getBalance(INVESTORS[0])
                    const amountRedeemed =
                        balanceAfter.minus(balanceBefore).plus(gasCosts);

                    expect(amountRedeemed.equals(expectedInvestorOneRedeemable)).to.be(true);

                    util.assertEventEquality(result.logs[0], ValueRedeemed({
                        uuid: redeemableTokenTestLoan.uuid,
                        investor: INVESTORS[0],
                        recipient: INVESTORS[0],
                        value: expectedInvestorOneRedeemable,
                        blockNumber: result.receipt.blockNumber
                    }))
                })

                it('should not let investor 1 redeem any more value', async () => {
                    try {
                        await loan.redeemValue(redeemableTokenTestLoan.uuid,
                            INVESTORS[0], { from: INVESTORS[0] });
                        expect().fail("should throw error");
                    } catch (err) {
                        util.assertThrowMessage(err)
                    }
                })

                it('should redeem the correct amount for investor 2', async () => {
                    const balanceBefore = web3.eth.getBalance(INVESTORS[1])
                    const result = await loan.redeemValue(redeemableTokenTestLoan.uuid,
                        INVESTORS[1], { from: INVESTORS[1] });
                    const gasCosts = await util.getGasCosts(result);
                    const balanceAfter = web3.eth.getBalance(INVESTORS[1])
                    const amountRedeemed =
                        balanceAfter.minus(balanceBefore).plus(gasCosts);

                    expect(amountRedeemed.equals(expectedInvestorTwoRedeemable)).to.be(true);

                    util.assertEventEquality(result.logs[0], ValueRedeemed({
                        uuid: redeemableTokenTestLoan.uuid,
                        investor: INVESTORS[1],
                        recipient: INVESTORS[1],
                        value: expectedInvestorTwoRedeemable,
                        blockNumber: result.receipt.blockNumber
                    }))
                })

                it('should not let investor 2 redeem any more value', async () => {
                    try {
                        await loan.redeemValue(redeemableTokenTestLoan.uuid,
                            INVESTORS[1], { from: INVESTORS[1] });
                        expect().fail("should throw error");
                    } catch (err) {
                        util.assertThrowMessage(err)
                    }
                })
            });
        })
    })

    describe('ERC20', () => {
        let erc20TestLoan = _.cloneDeep(LOAN_DATA);
        const bids = [
            {
                bidder: INVESTORS[0],
                amount: 0.2002,
                minInterestRate: 0.1
            },
            {
                bidder: INVESTORS[1],
                amount: 0.8008,
                minInterestRate: 0.1
            }
        ]
        const acceptedBids = [
            {
                bidder: INVESTORS[0],
                amount: 0.2002,
            },
            {
                bidder: INVESTORS[1],
                amount: 0.8008,
            }
        ]

        before(async () => {
            erc20TestLoan.uuid = web3.sha3(uuidV4());
            await loanFactory.generateAcceptedStateLoan(erc20TestLoan, bids, acceptedBids);
        })

        describe('#balanceOf()', () => {
            it('should expose the balanceOf endpoint', async () => {
                const expectedInvestorOneBalance = web3.toWei(0.2, 'ether');
                const expectedInvestorTwoBalance = web3.toWei(0.8, 'ether');

                const investorOneBalance =
                    await loan.balanceOf.call(erc20TestLoan.uuid, INVESTORS[0]);
                const investorTwoBalance =
                    await loan.balanceOf.call(erc20TestLoan.uuid, INVESTORS[1]);

                expect(investorOneBalance.equals(expectedInvestorOneBalance)).to.be(true)
                expect(investorTwoBalance.equals(expectedInvestorTwoBalance)).to.be(true)
            })
        })

        describe('#transfer()', () => {
            it('should allow a token holder to transfer their balance', async () => {
                const result = await loan.transfer(erc20TestLoan.uuid,
                    INVESTORS[1], web3.toWei(0.1, 'ether'), { from: INVESTORS[0] })

                const expectedInvestorOneBalance = web3.toWei(0.1, 'ether');
                const expectedInvestorTwoBalance = web3.toWei(0.9, 'ether');

                const investorOneBalance =
                    await loan.balanceOf.call(erc20TestLoan.uuid, INVESTORS[0]);
                const investorTwoBalance =
                    await loan.balanceOf.call(erc20TestLoan.uuid, INVESTORS[1]);

                expect(investorOneBalance.equals(expectedInvestorOneBalance)).to.be(true)
                expect(investorTwoBalance.equals(expectedInvestorTwoBalance)).to.be(true)

                util.assertEventEquality(result.logs[0], Transfer({
                    uuid: erc20TestLoan.uuid,
                    from: INVESTORS[0],
                    to: INVESTORS[1],
                    value: web3.toWei(0.1, 'ether'),
                    blockNumber: result.receipt.blockNumber
                }))
            })

            it('should not let holder transfer balance they do not have', async () => {
                try {
                    await loan.transfer(erc20TestLoan.uuid,
                        INVESTORS[1], web3.toWei(0.2, 'ether'), { from: INVESTORS[0] })
                    expect().fail("should throw error");
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })
        })

        describe('#allowance()', () => {
            it('should expose the allowance endpoint', async () => {
                const allowance =
                    await loan.allowance(erc20TestLoan.uuid, INVESTORS[0], INVESTORS[1])
                expect(allowance.equals(0)).to.be(true);
            })
        })

        describe('#approve()', () => {
            it('should allow investor to approve usage of their funds', async () => {
                const result = await loan.approve(
                    erc20TestLoan.uuid,
                    INVESTORS[0],
                    web3.toWei(0.4, 'ether'),
                    { from: INVESTORS[1] }
                )

                const allowance =
                    await loan.allowance(erc20TestLoan.uuid, INVESTORS[1], INVESTORS[0])

                expect(allowance.equals(web3.toWei(0.4, 'ether'))).to.be(true);

                util.assertEventEquality(result.logs[0], Approval({
                    uuid: erc20TestLoan.uuid,
                    owner: INVESTORS[1],
                    spender: INVESTORS[0],
                    value: web3.toWei(0.4, 'ether'),
                    blockNumber: result.receipt.blockNumber
                }))
            })
        })

        describe('#transferFrom()', () => {
            it("should allow user to transfer from other user's approved funds", async () => {
                const result = await loan.transferFrom(erc20TestLoan.uuid, INVESTORS[1], INVESTORS[0],
                    web3.toWei(0.2, 'ether'), { from : INVESTORS[0] });

                const expectedInvestorOneBalance = web3.toWei(0.3, 'ether');
                const expectedInvestorTwoBalance = web3.toWei(0.7, 'ether');

                const investorOneBalance =
                    await loan.balanceOf.call(erc20TestLoan.uuid, INVESTORS[0]);
                const investorTwoBalance =
                    await loan.balanceOf.call(erc20TestLoan.uuid, INVESTORS[1]);

                expect(investorOneBalance.equals(expectedInvestorOneBalance)).to.be(true)
                expect(investorTwoBalance.equals(expectedInvestorTwoBalance)).to.be(true)

                util.assertEventEquality(result.logs[0], Transfer({
                    uuid: erc20TestLoan.uuid,
                    from: INVESTORS[1],
                    to: INVESTORS[0],
                    value: web3.toWei(0.2, 'ether'),
                    blockNumber: result.receipt.blockNumber
                }))
            })

            it("should throw if user tries transfering from other user's unapproved funds", async () => {
                try {
                    await loan.transferFrom(erc20TestLoan.uuid, INVESTORS[2], INVESTORS[0],
                        web3.toWei(0.2, 'ether'), { from : INVESTORS[0] });
                    expect().fail("should throw error");
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })

            it('should throw if user tries transfering more than they are approved', async () => {
                try {
                    await loan.transferFrom(erc20TestLoan.uuid, INVESTORS[1], INVESTORS[0],
                        web3.toWei(0.3, 'ether'), { from : INVESTORS[0] });
                    expect().fail("should throw error");
                } catch (err) {
                    util.assertThrowMessage(err);
                }
            })
        })
    })
})