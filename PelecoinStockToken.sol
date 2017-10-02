pragma solidity ^0.4.11;

import './zeppelin-solidity/contracts/token/PausableToken.sol';
import './zeppelin-solidity/contracts/ReentrancyGuard.sol';

/** @title PelecoinStock smart contract */
contract PelecoinStock is PausableToken, ReentrancyGuard {
	string public   name     = "PelecoinStockToken"; 
	string public   symbol   = "PLST";
	uint public     decimals = 18;


	address[] private stockholders;
	mapping (address => uint32) private stockholdersLookup;
	uint32 private stockholdersNextInd  = 0;

	address private pelecoinContract;

	function PelecoinStock() {
		balances[msg.sender] = totalSupply = 1000;
		updateStockholders(msg.sender, address(0));
	}

    /** @dev Sets the address of related Pelecoin smart contract
      * @param _addr Contract address
      */
	function setPelecoinContract(address _addr) onlyOwner {
		pelecoinContract = _addr;
	}

	/**
	  * @dev transfer token for a specified address
	  * @param _to The address to transfer to
	  * @param _value The amount to be transferred
	  * @return Returns true on success, throws otherwise
	  */
	function transfer(address _to, uint256 _value) returns (bool) {
		require(super.transfer(_to, _value));
		updateStockholders(_to, msg.sender);
		return true;
	}

    /**
     * @dev Transfer tokens from one address to another
     * @param _from address The address which you want to send tokens from
     * @param _to address The address which you want to transfer to
     * @param _value uint256 the amout of tokens to be transfered
     */
	function transferFrom(address _from, address _to, uint256 _value) returns (bool) {
		require(super.transferFrom(_from, _to, _value));
		updateStockholders(_to, _from);
		return true;
	}

    /** @dev Called after each transfer operation to update those entitled to collect distributed fees
      * @param _to Target address 
	  * @param _from Source address
      */
	function updateStockholders(address _to, address _from) private {
		if (_from != address(0) && balances[_from] == 0) {
			stockholdersNextInd = stockholdersLookup[_from];
			delete stockholders[stockholdersNextInd];
		}
		if (stockholdersLookup[_to] == address(0)) {
			if (stockholdersNextInd==stockholders.length) {
				stockholdersLookup[_to] = stockholdersNextInd;
				stockholders.push(_to);
				stockholdersNextInd++;
			} else {
				stockholders[stockholdersNextInd] = _to;
				stockholdersLookup[_to] = stockholdersNextInd;
				stockholdersNextInd = uint32(stockholders.length);
			}
		}
	}

    /** @dev Distributes pending fees amongst entitled accounts. To be called by an external scheduler.
      * @param _amount Will distribute only if pending ammount is above this value
      */
	function distributeFees(uint256 _amount) {
        require(msg.sender == owner || msg.sender == pelecoinContract);

		for (uint32 i = 0; i < stockholders.length; i++) {
			address acc = stockholders[i];
			uint256 share = balances[acc] / totalSupply;
		}
	}

}
