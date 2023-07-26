//SPDX-License-Identifier:MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_ETHER = 1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public {
        console.log(fundMe.getVersion());
        assertEq(fundMe.getVersion(), 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // expect next line to fail
        fundMe.fund();
    }

    function testFundPassWithEnoughETH() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_ETHER}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_ETHER);
    }

    function testAddsAddressToAmountFundedArray() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_ETHER}();
        assertEq(fundMe.getFunder(0), USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_ETHER}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        // AAA
        // Arrange - Act - Assert

        // Arrange
        address ownerFundMe = fundMe.getOwner();
        uint256 startingOwnerBalance = ownerFundMe.balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        // uint256 gasStart = gasleft();
        // vm.txGasPrice(GAS_PRICE);
        vm.prank(ownerFundMe);
        fundMe.cheaperWithdraw();
        // uint256 gasEnd = gasleft();

        // Assert
        uint256 endingOwnerBalance = ownerFundMe.balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        // uint256 gasConsumed = (gasStart - gasEnd) * tx.gasprice;
        // console.log(gasConsumed);
        assertEq(startingFundMeBalance - endingFundMeBalance, SEND_ETHER);
        assertGt(endingOwnerBalance, startingOwnerBalance);
        assertEq(
            endingOwnerBalance,
            startingOwnerBalance + startingFundMeBalance
        );

        // In the local anvil chain gasPrice is set default to 0;
    }

    function testWithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        address ownerFundMe = fundMe.getOwner();

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // address usr = makeAddr("usr");
            // vm.deal(usr, STARTING_BALANCE);
            // vm.prank(usr);

            // hoax === deal + prank

            // since 0.8.0 you can no longer cast explicitly from address to uint256
            // for conversion use
            // uint256 i = uint256(uint160(msg.sender))

            hoax(address(i), STARTING_BALANCE);
            fundMe.fund{value: SEND_ETHER}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.startPrank(ownerFundMe);
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        // Assert
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(startingFundMeBalance, 10 ether);
    }
}
