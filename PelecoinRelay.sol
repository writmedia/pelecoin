pragma solidity ^0.4.11;

import './zeppelin-solidity/contracts/ownership/Ownable.sol';

contract Relay is Ownable {
    address public currAddr;
    address public owner;

    function Relay(address initAddr) {
        currAddr = initAddr;
        owner = msg.sender;
    }

    function update(address newAddress) onlyOwner {
        currAddr = newAddress;
    }

    function() {
        require(currAddr.delegatecall(msg.data));
    }
}