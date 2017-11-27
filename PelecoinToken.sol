pragma solidity ^0.4.11;

import './zeppelin-solidity/contracts/token/PausableToken.sol';
import './zeppelin-solidity/contracts/ReentrancyGuard.sol';


/** @title Pelecoin smart contract */
contract Pelecoin is PausableToken, ReentrancyGuard {
	string public   name             = "PelecoinCash";
	string public   symbol           = "PLCN";
	uint public     decimals         = 18;
	uint256 private buyPrice         = 1268726;
	uint256 private sellPrice        = 1347204;

	uint256 public  pendingFees      = 0;
	uint16 private  feeDivider       = 1000;
	uint private    transferFee      = 1;
	uint private    balanceUpdateFee = 1;
	uint private    managementFee    = 1;
	uint32 private  managementFeeTakenAt;

	address[] private peleholders;
	mapping (address => uint32) private peleholdersLookup;
	uint32 private peleholdersNextInd  = 0;

	address private pelecoinStockContract;

	function Pelecoin(uint256 initBalance) {
		balances[msg.sender] = totalSupply = initBalance;
		updatePeleholders(msg.sender, address(0));
	}

    /** @dev Payable fallback function for local transfers
      */
    function() public payable { }

    /** @dev Sets the fee divider used to calculate all fees
      * @param _feeDivider Fee dividing number
      */
	function setFeeDivider(uint16 _feeDivider) public onlyOwner {
		feeDivider = _feeDivider;
	}

    /** @dev Sets the fee that's deducted from each transfer operation
      * @param _transferFee Integer number that will be divided by <feeDivider> to represent percentage
      */
	function setTransferFee(uint _transferFee) public onlyOwner {
		transferFee = _transferFee;
	}

    /** @dev Sets the management fee to deduct from the balance by external scheduled call
      * @param _managementFee Integer number that will be divided by <feeDivider> to represent percentage
      */
	function setManagementFee(uint _managementFee) public onlyOwner {
		managementFee = _managementFee;
	}

    /** @dev Sets the fee to deduct on every balance increment operation
      * @param _balanceUpdateFee Integer number that will be divided by <feeDivider> to represent percentage
      */
	function setBalanceUpdateFee(uint _balanceUpdateFee) public onlyOwner {
		balanceUpdateFee = _balanceUpdateFee;
	}

    /** @dev Updates the address of PelecoinStock smart contract
      * @param _pelecoinStockContract Contract address
      */
	function setStockContract(address _pelecoinStockContract) public onlyOwner {
		pelecoinStockContract = _pelecoinStockContract;
	}

    /** @dev Updates the buy and sell prices of one Pelecoin __in_wei__
      * @param _buyPrice The new buy price
	  * @param _sellPrice The new sell price
      */
	function setBuySellPrices(uint256 _buyPrice, uint256 _sellPrice) public onlyOwner {
		buyPrice = _buyPrice;
		sellPrice = _sellPrice;
	}

    /** @dev Helper function used to calculate different fees
      * @param amount Amount operand
	  * @param fee Fee to extract
	  * @return Returns fee amount
      */
	function calcFee(uint256 amount, uint fee) private constant returns (uint256) {
		return amount.div(feeDivider).mul(fee);
	}

    /** @dev Allows buying of Pelecoins for Ether
      * @return amount The amount of Pelecoins bought
      */
	function buy(address forAccount) public payable nonReentrant returns (uint256 amount) {	
		amount = msg.value * buyPrice;
		if (forAccount==address(0))
			forAccount = msg.sender;
		allowed[owner][forAccount] = amount;
		transferFrom(owner, forAccount, amount);
		allowed[owner][forAccount] = 0;	//remove untaken fee
		return amount;
	}

    /** @dev Allows selling of Pelecoins to receive Ether
      * @return amount The amount of Pelecoins bought
      */
	function sell(uint256 amount, address forAccount) public nonReentrant returns (uint256 revenue) {
		balances[msg.sender] = balances[msg.sender].sub(amount);
		uint256 fee = calcFee(amount, balanceUpdateFee);
		pendingFees += fee;
		amount -= fee;
		balances[owner] = balances[owner].add(amount);
		revenue = amount / sellPrice;
		if (forAccount==address(0))
			forAccount = msg.sender;
		require(forAccount.send(revenue));
		Transfer(msg.sender, owner, amount);
		updatePeleholders(address(0), msg.sender);
		return revenue;
	}

	/**
	  * @dev transfer token for a specified address
	  * @param to The address to transfer to
	  * @param amount The amount to be transferred
	  * @return Returns true on success, throws otherwise
	  */
	function transfer(address to, uint256 amount) public returns (bool) {
		var fee = calcFee(amount, transferFee);
		require(super.transfer(to, amount - fee));
		balances[msg.sender] -= fee;
		pendingFees += fee;
		updatePeleholders(to, msg.sender);
		return true;
	}

    /**
     * @dev Transfer tokens from one address to another
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param amount uint256 the amout of tokens to be transfered
     */
   	function transferFrom(address from, address to, uint256 amount) public returns (bool) {
		var fee = calcFee(amount, transferFee);
		require(super.transferFrom(from, to, amount.sub(fee)));
		balances[from] -= fee;
		pendingFees += fee;
		updatePeleholders(to, from);
		return true;
	}

    /** @dev Called after each transfer operation to update those entitled to collect distributed fees
      * @param to Target address
	  * @param from Source address
      */
	function updatePeleholders(address to, address from) private {
		if (from != address(0) && balances[from] == 0) {
			peleholdersNextInd = peleholdersLookup[from];
			delete peleholders[peleholdersNextInd];
		}
		if (peleholdersLookup[to] == address(0)) {
			if (peleholdersNextInd==peleholders.length) {
				peleholdersLookup[to] = peleholdersNextInd;
				peleholders.push(to);
				peleholdersNextInd++;
			} else {
				peleholders[peleholdersNextInd] = to;
				peleholdersLookup[to] = peleholdersNextInd;
				peleholdersNextInd = uint32(peleholders.length);
			}
		}
	}

    /** @dev Used mainly to update pending fees after negative balance update (cannot deduct fees)
      * @param amount Amount to add
      */
	function addToPendingFees(uint256 amount) public onlyOwner {
		pendingFees += amount;
		totalSupply += amount;
	}

    /** @dev Used to add/deduct an amount from a specific account. When balance is incremented a fee is deducted.
      * @param account Account address to update
	  * @param amount Amount to add or deduct
	  * @return Returns the actual amount that impacted the balance (after fee deduction)
      */
	function updateBalance(address account, int256 amount) public onlyOwner returns (int256) {
		uint256 a = uint256(amount * ((amount < 0) ? -1 : int(1)));
		uint256 fee;
		if (amount > 0) {
			fee = calcFee(a, balanceUpdateFee);
			balances[account] += a - fee;
			totalSupply += a;
			pendingFees += fee;
			return int256(a - fee);
		}
		if (balances[account] < a)
			a = balances[account];
		fee = calcFee(a, balanceUpdateFee);
		balances[account] -= a;
		totalSupply -= a - fee;
		pendingFees += fee;
		return amount + int256(fee);
	}


    /** @dev Update the total supply and contract's balance with specified amount
      * @param amount Amount to add or deduct
      */
	function updateSupply(int256 amount) public onlyOwner {
		require(amount > 0 || (int256(totalSupply) >= amount && int256(balances[owner])>=amount));
		totalSupply = uint256(int256(totalSupply) + amount);
		balances[owner] = uint256(int256(balances[owner]) + amount);
	}

    /** @dev Distributes pending fees amongst entitled accounts. To be called by an external scheduler.
      * @param ifAbove Will distribute only if pending ammount is above this value
      */
	function distributeFees(uint256 ifAbove) public onlyOwner {
		if (pendingFees < ifAbove)
			return;
		for (uint32 i = 0; i < peleholders.length; i++) {
			address acc = peleholders[i];
			uint256 share = balances[acc] * 100 / totalSupply;
			uint256 fee = pendingFees * share / 100;
			balances[acc] += fee;
			pendingFees -= fee;
		}
	}

    /** @dev Collects management fees. To be called by an external scheduler. If less than 24 hours passed since last call, operation is aborted.
      * @param timestamp Current UTC unix timestamp on scheduling server
      * @param minTimeDiff Minimal amount of seconds that should have passed in order to collect fees
	  * @return totalCollected The total amount of collected fees
      */
	function collectManagementFees(uint32 timestamp, uint32 minTimeDiff) public onlyOwner returns (uint256 totalCollected) {
		if (timestamp - managementFeeTakenAt < minTimeDiff)
			return 0;
		totalCollected = 0;
		for (uint32 i = 0; i < peleholders.length; i++) {
			address adr = peleholders[i];
			uint256 fee = calcFee(balances[adr], managementFee);
			balances[adr] -= fee;
			pendingFees += fee;
			totalCollected += fee;
		}
		managementFeeTakenAt = timestamp;
		return totalCollected;
	}
}
