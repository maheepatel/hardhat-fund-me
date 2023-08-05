// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PriceConverter.sol";

error FundMe__NotOwner();

// Gets funds from users
// withdraw funds
// Set a min funding value in USD

//848,948 gas to execute
// 829418 gas with constant

// Interface, Libraries, Contracts

/**
 * @title A contract for crowd funding
 * @author Mahee
 * @notice This contract is to demo a sample funding contract
 * @dev This implements price feeds as our library
 */

contract FundMe {
    // constant and immutable
    using PriceConverter for uint256;
    // 307 gas execution cost with constant
    // 2407 gas without constant
    // 307*15000000000 = 46,05,00,00,00,000 = $0.00881963415
    // 2407*15000000000 = 3,61,05,00,00,00,000 = $0.0691490181
    mapping(address => uint256) private s_addressToAmountFunded;
    address[] private s_funders;
    // could we make this constant?
    address private immutable i_owner;
    uint256 public constant MIN_USD = 50 * 10 ** 18;

    AggregatorV3Interface public s_priceFeed;
    // event Funded(address indexed from, uint256 amount);
    // 444 gas - immutable
    // 2580 gas - non-immutable

    modifier onlyOwner() {
        //   require(msg.sender == owner, "Sender is not owner!");
        // below is the more gas optimisation
        if (msg.sender != i_owner) {
            revert FundMe__NotOwner();
        }
        // _; means excute the rest of the code either before require or after
        _;
    }

    // Functions Order:
    //// constructor
    //// receive function (if exists)
    //// fallback function (if exists)
    //// external
    //// public
    //// internal
    //// private
    //// view / pure

    constructor(address priceFeedAddress) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeedAddress);
    }

    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

    /**
     * @notice This function funds this contract
     * @dev This implements price feeds as our library
     */

    function fund() public payable {
        // want to be able to set a min
        // 1. How do we send ETH to this contract

        // msg.value.getConversionRate();
        require(
            msg.value.getConversionRate(s_priceFeed) >= MIN_USD,
            "Didn't send enough money"
        );
        // require(getConversionRate(msg.value) >= MIN_USD, "Didn't send enough!");  // 1e18 == 1*10**18
        s_funders.push(msg.sender);
        s_addressToAmountFunded[msg.sender] = msg.value;
    }

    function withdraw() public onlyOwner {
        // require(msg.sender == owner, "Sender is not owner");
        for (
            uint256 funderIndex = 0;
            funderIndex < s_funders.length;
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        // reset array
        s_funders = new address[](0);
        // withdraw funds

        // 1. transfer
        // Whole balance is transfered and typecast address type to payable address

        // payable(msg.sender).transfer(address(this).balance);

        //2. send
        // bool sendSuccess = payable(msg.sender).send(address(this).balance);
        // require(sendSuccess, "Send failed");
        // 3. call
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed");
    }

    function cheaperWithdraw() public payable onlyOwner {
        //  storage var into memory var and then read from it
        address[] memory funders = s_funders;
        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool success, ) = i_owner.call{value: address(this).balance}("");

        require(success);
    }

    // View or pure functions
    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getFunder(uint256 index) public view returns (address) {
        return s_funders[index];
    }

    function getAddressToAmountFunded(
        address funder
    ) public view returns (uint256) {
        return s_addressToAmountFunded[funder];
    }

    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }

    // Q. what happens if someone sends this contract ETH without calling the fund function
    // ANS. All this is because to track who sent ETH and reward all without missing anyone
}
