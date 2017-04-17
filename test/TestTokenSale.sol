pragma solidity ^0.4.8;

import "truffle/Assert.sol";
import "zeppelin/token/ERC20.sol";
import "./helpers/AragonTokenSaleMock.sol";
import "./helpers/ThrowProxy.sol";
import "./helpers/MultisigMock.sol";

contract TestTokenSale {
  uint public initialBalance = 200 finney;
  address factory;

  ThrowProxy throwProxy;

  function beforeAll() {
    factory = address(new MiniMeTokenFactory());
  }

  function beforeEach() {
    throwProxy = new ThrowProxy(address(this));
  }

  function testHasCorrectPriceForStages() {
    AragonTokenSaleMock sale = new AragonTokenSaleMock(10, 20, address(this), address(this), 3, 1, 2);
    Assert.equal(sale.getPrice(10), 2, "Should have correct price for start stage 1");
    Assert.equal(sale.getPrice(13), 2, "Should have correct price for middle stage 1");
    Assert.equal(sale.getPrice(14), 2, "Should have correct price for final stage 1");
    Assert.equal(sale.getPrice(15), 1, "Should have correct price for start stage 2");
    Assert.equal(sale.getPrice(18), 1, "Should have correct price for middle stage 2");
    Assert.equal(sale.getPrice(19), 1, "Should have correct price for final stage 2");

    Assert.equal(sale.getPrice(9), 0, "Should have incorrect price out of sale");
    Assert.equal(sale.getPrice(20), 0, "Should have incorrect price out of sale");
  }

  function testHasCorrectPriceForMultistage() {
    AragonTokenSaleMock sale = new AragonTokenSaleMock(10, 40, address(this), address(this), 3, 1, 3);
    Assert.equal(sale.getPrice(10), 3, "Should have correct price");
    Assert.equal(sale.getPrice(19), 3, "Should have correct price");
    Assert.equal(sale.getPrice(20), 2, "Should have correct price");
    Assert.equal(sale.getPrice(25), 2, "Should have correct price");
    Assert.equal(sale.getPrice(30), 1, "Should have correct price");
    Assert.equal(sale.getPrice(39), 1, "Should have correct price");

    Assert.equal(sale.getPrice(9), 0, "Should have incorrect price out of sale");
    Assert.equal(sale.getPrice(41), 0, "Should have incorrect price out of sale");
  }

  function testAllocatesTokensInSale() {
    MultisigMock ms = new MultisigMock();

    AragonTokenSaleMock sale = new AragonTokenSaleMock(10, 20, address(ms), address(ms), 3, 1, 2);
    ms.activateSale(sale, factory);

    sale.setMockedBlockNumber(12);
    Assert.isTrue(sale.proxyPayment.value(25 finney)(address(this)), 'proxy payment should succeed'); // Gets 5 @ 10 finney

    sale.setMockedBlockNumber(17);
    if (!sale.proxyPayment.value(10 finney)(address(this))) throw; // Gets 1 @ 20 finney

    Assert.equal(ERC20(sale.token()).balanceOf(address(this)), 60 finney, 'Should have correct balance after allocation');
    Assert.equal(ERC20(sale.token()).totalSupply(), 60 finney, 'Should have correct supply after allocation');
    Assert.equal(ms.balance, 35 finney, 'Should have sent money to multisig');
  }

  function testCannotGetTokensInNotInitiatedSale() {
    TestTokenSale(throwProxy).throwsWhenGettingTokensInNotInitiatedSale();
    throwProxy.assertThrows("Should have thrown when sale is not activated");
  }

  function throwsWhenGettingTokensInNotInitiatedSale() {
    MultisigMock ms = new MultisigMock();

    AragonTokenSaleMock sale = new AragonTokenSaleMock(10, 20, address(ms), address(this), 3, 1, 2);
    ms.activateSale(sale, factory);
    // Would need activation from this too

    sale.setMockedBlockNumber(12);
    sale.proxyPayment.value(50 finney)(address(this));
  }

  function testEmergencyStop() {
    MultisigMock ms = new MultisigMock();
    AragonTokenSaleMock sale = new AragonTokenSaleMock(10, 20, address(ms), address(ms), 3, 1, 2);
    ms.activateSale(sale, factory);

    sale.setMockedBlockNumber(12);
    Assert.isTrue(sale.proxyPayment.value(15 finney)(address(this)), 'proxy payment should succeed');
    Assert.equal(ERC20(sale.token()).balanceOf(address(this)), 30 finney, 'Should have correct balance after allocation');

    ms.emergencyStopSale(address(sale));
    Assert.isTrue(sale.saleStopped(), "Sale should be stopped");

    ms.restartSale(sale);

    sale.setMockedBlockNumber(16);
    Assert.isFalse(sale.saleStopped(), "Sale should be restarted");
    Assert.isTrue(sale.proxyPayment.value(1 finney)(address(this)), 'proxy payment should succeed');
    Assert.equal(ERC20(sale.token()).balanceOf(address(this)), 31 finney, 'Should have correct balance after allocation');
  }

  function testCantBuyTokensInStoppedSale() {
    TestTokenSale(throwProxy).throwsWhenGettingTokensWithStoppedSale();
    throwProxy.assertThrows("Should have thrown when sale is stopped");
  }

  function throwsWhenGettingTokensWithStoppedSale() {
    MultisigMock ms = new MultisigMock();
    AragonTokenSaleMock sale = new AragonTokenSaleMock(10, 20, address(ms), address(ms), 3, 1, 2);
    ms.activateSale(sale, factory);
    sale.setMockedBlockNumber(12);

    ms.emergencyStopSale(address(sale));
    sale.proxyPayment.value(20 finney)(address(this));
  }

  function testCantBuyTokensInEndedSale() {
    TestTokenSale(throwProxy).throwsWhenGettingTokensWithEndedSale();
    throwProxy.assertThrows("Should have thrown when sale is ended");
  }

  function throwsWhenGettingTokensWithEndedSale() {
    MultisigMock ms = new MultisigMock();
    AragonTokenSaleMock sale = new AragonTokenSaleMock(10, 20, address(ms), address(ms), 3, 1, 2);
    ms.activateSale(sale, factory);
    sale.setMockedBlockNumber(21);

    sale.proxyPayment.value(20 finney)(address(this));
  }

  function testCantFinalizeNotEndedSale() {
    TestTokenSale(throwProxy).throwsWhenFinalizingNotEndedSale();
    throwProxy.assertThrows("Should have thrown when sale is ended");
  }

  function throwsWhenFinalizingNotEndedSale() {
    MultisigMock ms = new MultisigMock();
    AragonTokenSaleMock sale = new AragonTokenSaleMock(10, 20, address(ms), address(ms), 3, 1, 2);
    ms.activateSale(sale, factory);
    sale.setMockedBlockNumber(19);
    ms.finalizeSale(sale);
  }

  function testCantFinalizeIfNotMultisig() {
    TestTokenSale(throwProxy).throwsWhenFinalizingIfNotMultisig();
    throwProxy.assertThrows("Should have thrown if not multisig");
  }

  function throwsWhenFinalizingIfNotMultisig() {
    MultisigMock ms = new MultisigMock();
    AragonTokenSaleMock sale = new AragonTokenSaleMock(10, 20, address(ms), address(ms), 3, 1, 2);
    ms.activateSale(sale, factory);
    sale.setMockedBlockNumber(30);
    sale.finalizeSale();
  }

  function testCanFinalizeEndedSale() {
    MultisigMock ms = new MultisigMock();
    AragonTokenSaleMock sale = new AragonTokenSaleMock(10, 20, address(ms), address(ms), 3, 1, 2);
    ms.activateSale(sale, factory);
    sale.setMockedBlockNumber(12);
    sale.proxyPayment.value(35 finney)(address(this));

    Assert.equal(ERC20(sale.token()).balanceOf(address(this)), 70 finney, 'Should have correct balance after allocation');
    Assert.equal(ERC20(sale.token()).totalSupply(), 70 finney, 'Should have correct supply before ending sale');

    sale.setMockedBlockNumber(21);
    ms.finalizeSale(sale);

    Assert.equal(ERC20(sale.token()).balanceOf(address(ms)), 30 finney, 'Should have correct balance after ending sale');
    Assert.equal(ERC20(sale.token()).totalSupply(), 100 finney, 'Should have correct supply after ending sale');
  }

  function testTokensAreLockedDuringSale() {
    TestTokenSale(throwProxy).throwsWhenTransferingDuringSale();
    throwProxy.assertThrows("Should have thrown transferring during sale");
  }

  function throwsWhenTransferingDuringSale() {
    MultisigMock ms = new MultisigMock();
    AragonTokenSaleMock sale = new AragonTokenSaleMock(10, 20, address(ms), address(ms), 3, 1, 2);
    ms.activateSale(sale, factory);
    sale.setMockedBlockNumber(12);
    sale.proxyPayment.value(15 finney)(address(this));

    ERC20(sale.token()).transfer(0x1, 10 finney);
  }

  function testTokensAreTransferrableAfterSale() {
    MultisigMock ms = new MultisigMock();
    AragonTokenSaleMock sale = new AragonTokenSaleMock(10, 20, address(ms), address(ms), 3, 1, 2);
    ms.activateSale(sale, factory);
    sale.setMockedBlockNumber(12);
    sale.proxyPayment.value(15 finney)(address(this));
    sale.setMockedBlockNumber(22);
    ms.finalizeSale(sale);

    ERC20(sale.token()).transfer(0x1, 10 finney);
    Assert.equal(ERC20(sale.token()).balanceOf(0x1), 10 finney, 'Should have correct balance after receiving tokens');
  }
}
