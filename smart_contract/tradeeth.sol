pragma solidity ^0.4.9;

contract SafeMath {
  function safeMul(uint a, uint b) internal returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function safeSub(uint a, uint b) internal returns (uint) {
    assert(b <= a);
    return a - b;
  }

  function safeAdd(uint a, uint b) internal returns (uint) {
    uint c = a + b;
    assert(c>=a && c>=b);
    return c;
  }

  function assert(bool assertion) internal {
    if (!assertion) throw;
  }
}

contract Token {
  /// @return total amount of tokens
  function totalSupply() constant returns (uint256 supply) {}

  /// @param _owner The address from which the balance will be retrieved
  /// @return The balance
  function balanceOf(address _owner) constant returns (uint256 balance) {}

  /// @notice send `_value` token to `_to` from `msg.sender`
  /// @param _to The address of the recipient
  /// @param _value The amount of token to be transferred
  /// @return Whether the transfer was successful or not
  function transfer(address _to, uint256 _value) returns (bool success) {}

  /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
  /// @param _from The address of the sender
  /// @param _to The address of the recipient
  /// @param _value The amount of token to be transferred
  /// @return Whether the transfer was successful or not
  function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {}

  /// @notice `msg.sender` approves `_addr` to spend `_value` tokens
  /// @param _spender The address of the account able to transfer the tokens
  /// @param _value The amount of wei to be approved for transfer
  /// @return Whether the approval was successful or not
  function approve(address _spender, uint256 _value) returns (bool success) {}

  /// @param _owner The address of the account owning tokens
  /// @param _spender The address of the account able to transfer the tokens
  /// @return Amount of remaining tokens allowed to spent
  function allowance(address _owner, address _spender) constant returns (uint256 remaining) {}

  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract StandardToken is Token {
  address[] internal allTokenHolders;

  mapping(address => uint256) balances;

  mapping (address => mapping (address => uint256)) allowed;

  uint256 public totalSupply;

  function transfer(address _to, uint256 _value) returns (bool success) {
    //Default assumes totalSupply can't be over max (2^256 - 1).
    //If your token leaves out totalSupply and can issue more tokens as time goes on, you need to check if it doesn't wrap.
    //Replace the if with this one instead.
    if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
    //if (balances[msg.sender] >= _value && _value > 0) {
      balances[msg.sender] -= _value;
      syncTokenHolding(msg.sender, _to);

      balances[_to] += _value;
      Transfer(msg.sender, _to, _value);
      return true;
    } else { return false; }
  }

  function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
    //same as above. Replace this line with the following if you want to protect against wrapping uints.
    if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
    //if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
      if(balances[_to] == 0) {
        allTokenHolders.push(_to);
      }

      balances[_to] += _value;
      balances[_from] -= _value;
      if (balances[_from] == 0) {
        removeTokenHolder(_from);
      }

      allowed[_from][msg.sender] -= _value;


      Transfer(_from, _to, _value);
      return true;
    } else { return false; }
  }

  function balanceOf(address _owner) constant returns (uint256 balance) {
    return balances[_owner];
  }

  function approve(address _spender, uint256 _value) returns (bool success) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  function syncTokenHolding(address from, address to) internal {
    if (balances[from] == 0) {
      removeTokenHolder(from);
    } else if (balances[to] == 0) {
      allTokenHolders.push(to);
    }
  }

  function removeTokenHolder(address _addr) internal {
    for (uint i = 0; i < allTokenHolders.length; i++) {
      if (allTokenHolders[i] == _addr) {
        delete allTokenHolders[i];
        return;
      }
    }
  }
}

contract ReserveToken is StandardToken, SafeMath {
  address public owner;
  function ReserveToken() {
    owner = msg.sender;
  }

  function create(address account, uint amount) {
    if (msg.sender != owner) throw;
    balances[account] = safeAdd(balances[account], amount);
    totalSupply = safeAdd(totalSupply, amount);
  }

  function destroy(address account, uint amount) {
    if (msg.sender != owner) throw;
    if (balances[account] < amount) throw;
    balances[account] = safeSub(balances[account], amount);
    totalSupply = safeSub(totalSupply, amount);
  }
}

contract TETHToken is ReserveToken {
  uint public decimals = 18;
  string public name = "TradeETH";
  string public symbol = "TETH";
  address public exchangeContract;

  event SentDividend(address receiver, uint amount);

  function TETHToken(address _reserveAddress) {
    totalSupply = 100000000000000000000000000; // 100 mil.
    balances[_reserveAddress] = 10000000000000000000000000; // 10 mil.
  }

  function setExchangeContract(address _newAddress) external {
    if (msg.sender != owner) throw;
    exchangeContract = _newAddress;
  }

  /*
  * Used by token owner to sent dividends in batches
  * Note: Call from exchange contract to
  * transfer fee earnings to this call
  */
  function sendDividendsInBatches(address[] _tokenHolders) external payable {
    if (msg.sender != owner) throw;

    uint256 paymentPerShare = msg.value / totalSupply;
    if (paymentPerShare == 0) throw;

    for (uint256 i = 0; i < _tokenHolders.length; i++) {
      uint256 dividend = safeMul(paymentPerShare, balances[_tokenHolders[i]]);
      if (_tokenHolders[i].send(dividend)) {
        SentDividend(_tokenHolders[i], dividend);
      } else {
        throw;
      }
    }
  }

  /*
  * Sends dividends to all token holders.
  * Note: Call from exchange contract to
  * transfer fee earnings to this call.
  * In case of too many holders, it could hit block gas limit.
  */
  function sendDividends() public payable returns (bool){
    if (msg.sender != exchangeContract) throw;

    uint256 paymentPerShare = msg.value / totalSupply;
    if (paymentPerShare == 0) throw;

    /* Get all accounts and send them dividend payment */
    for (uint256 i = 0; i < allTokenHolders.length; i++) {
      uint256 dividend = safeMul(paymentPerShare, balances[allTokenHolders[i]]);
      if (allTokenHolders[i].send(dividend)) {
        SentDividend(allTokenHolders[i], dividend);
      } else {
        return false;
      }
    }

    return true;
  }
}

contract AccountLevels {
  //given a user, returns an account level
  //0 = regular user (pays take fee and make fee)
  //1 = market maker silver (pays take fee, no make fee, gets rebate)
  //2 = market maker gold (pays take fee, no make fee, gets entire counterparty's take fee as rebate)
  function accountLevel(address user) constant returns(uint) {}
}

contract AccountLevelsTest is AccountLevels {
  mapping (address => uint) public accountLevels;

  function setAccountLevel(address user, uint level) {
    accountLevels[user] = level;
  }

  function accountLevel(address user) constant returns(uint) {
    return accountLevels[user];
  }
}

contract TradeETH is SafeMath {
  address public admin; //the admin address
  uint public feeEarnings; // amount earned from fees
  address public accountLevelsAddr; //the address of the AccountLevels contract
  address public tokenAddress; // TETH token address
  uint public feeMake; //percentage times (1 ether)
  uint public feeTake; //percentage times (1 ether)
  uint public feeRebate; //percentage times (1 ether)
  mapping (address => mapping (address => uint)) public tokens; //mapping of token addresses to mapping of account balances (token=0 means Ether)
  mapping (address => mapping (bytes32 => bool)) public orders; //mapping of user accounts to mapping of order hashes to booleans (true = submitted by user, equivalent to offchain signature)
  mapping (address => mapping (bytes32 => uint)) public orderFills; //mapping of user accounts to mapping of order hashes to uints (amount of order that has been filled)

  event Order(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user);
  event Cancel(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint8 v, bytes32 r, bytes32 s);
  event Trade(address tokenGet, uint amountGet, address tokenGive, uint amountGive, address get, address give);
  event Deposit(address token, address user, uint amount, uint balance);
  event Withdraw(address token, address user, uint amount, uint balance);

  function TradeETH(address admin_,  address accountLevelsAddr_, uint feeMake_, uint feeTake_, uint feeRebate_, address _tokenAddress) {
    admin = admin_;
    accountLevelsAddr = accountLevelsAddr_;
    feeMake = feeMake_;
    feeTake = feeTake_;
    feeRebate = feeRebate_;
    tokenAddress = _tokenAddress;
  }

  function() {
    throw;
  }

  function changeAdmin(address admin_) {
    if (msg.sender != admin) throw;
    admin = admin_;
  }

  function changeAccountLevelsAddr(address accountLevelsAddr_) {
    if (msg.sender != admin) throw;
    accountLevelsAddr = accountLevelsAddr_;
  }

  function changeFeeMake(uint feeMake_) {
    if (msg.sender != admin) throw;
    if (feeMake_ > feeMake) throw;
    feeMake = feeMake_;
  }

  function changeFeeTake(uint feeTake_) {
    if (msg.sender != admin) throw;
    if (feeTake_ > feeTake || feeTake_ < feeRebate) throw;
    feeTake = feeTake_;
  }

  function changeFeeRebate(uint feeRebate_) {
    if (msg.sender != admin) throw;
    if (feeRebate_ < feeRebate || feeRebate_ > feeTake) throw;
    feeRebate = feeRebate_;
  }

  function sendEarnings() {
    if (msg.sender != admin) throw;
    if (TETHToken(tokenAddress).sendDividends.value(feeEarnings)()) {
      feeEarnings = 0;
    }
  }

  function deposit() payable {
    tokens[0][msg.sender] = safeAdd(tokens[0][msg.sender], msg.value);
    Deposit(0, msg.sender, msg.value, tokens[0][msg.sender]);
  }

  function withdraw(uint amount) {
    if (tokens[0][msg.sender] < amount) throw;
    tokens[0][msg.sender] = safeSub(tokens[0][msg.sender], amount);
    if (!msg.sender.call.value(amount)()) throw;
    Withdraw(0, msg.sender, amount, tokens[0][msg.sender]);
  }

  function depositToken(address token, uint amount) {
    //remember to call Token(address).approve(this, amount) or this contract will not be able to do the transfer on your behalf.
    if (token==0) throw;
    if (!Token(token).transferFrom(msg.sender, this, amount)) throw;
    tokens[token][msg.sender] = safeAdd(tokens[token][msg.sender], amount);
    Deposit(token, msg.sender, amount, tokens[token][msg.sender]);
  }

  function withdrawToken(address token, uint amount) {
    if (token==0) throw;
    if (tokens[token][msg.sender] < amount) throw;
    tokens[token][msg.sender] = safeSub(tokens[token][msg.sender], amount);
    if (!Token(token).transfer(msg.sender, amount)) throw;
    Withdraw(token, msg.sender, amount, tokens[token][msg.sender]);
  }

  function balanceOf(address token, address user) constant returns (uint) {
    return tokens[token][user];
  }

  function order(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce) {
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce);
    orders[msg.sender][hash] = true;
    Order(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, msg.sender);
  }

  function trade(address tokenGet, uint amountGet, address tokenGive, uint amountGive,
    uint expires, uint nonce, address user, uint8 v, bytes32 r, bytes32 s, uint amount) payable {
    //amount is in amountGet terms
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce);
    if (!(
      (orders[user][hash] || ecrecover(sha3("\x19Ethereum Signed Message:\n32", hash),v,r,s) == user) &&
      block.number <= expires &&
      safeAdd(orderFills[user][hash], amount) <= amountGet
    )) throw;
    tradeBalances(tokenGet, amountGet, tokenGive, amountGive, user, amount);
    orderFills[user][hash] = safeAdd(orderFills[user][hash], amount);
    Trade(tokenGet, amount, tokenGive, amountGive * amount / amountGet, user, msg.sender);
  }

  function calculateTakeFee(address user) public constant returns (uint) {
    uint fee = feeTake;
    if (accountLevelsAddr != 0x0) {
      uint accountLevel = AccountLevels(accountLevelsAddr).accountLevel(user);
      if (accountLevel == 1) fee = safeSub(feeTake, safeMul(feeTake, feeRebate));
      if (accountLevel == 2) fee = 0;
    }

    return fee;
  }

  function tradeBalances(address tokenGet, uint amountGet, address tokenGive, uint amountGive, address user, uint amount) private {
    uint feeToPay = calculateTakeFee(msg.sender);
    // Pay fee in fixed ETH
    if (msg.value != feeToPay) {
      throw;
    }

    tokens[tokenGet][msg.sender] = safeSub(tokens[tokenGet][msg.sender], amount);
    tokens[tokenGet][user] = safeAdd(tokens[tokenGet][user], amount);
    feeEarnings = safeAdd(feeEarnings, feeToPay);
    tokens[tokenGive][user] = safeSub(tokens[tokenGive][user], safeMul(amountGive, amount) / amountGet);
    tokens[tokenGive][msg.sender] = safeAdd(tokens[tokenGive][msg.sender], safeMul(amountGive, amount) / amountGet);
  }

  function testTrade(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint8 v, bytes32 r, bytes32 s, uint amount, address sender) constant returns(bool) {
    if (!(
      tokens[tokenGet][sender] >= amount &&
      availableVolume(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, user, v, r, s) >= amount
    )) return false;
    return true;
  }

  function availableVolume(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint8 v, bytes32 r, bytes32 s) constant returns(uint) {
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce);
    if (!(
      (orders[user][hash] || ecrecover(sha3("\x19Ethereum Signed Message:\n32", hash),v,r,s) == user) &&
      block.number <= expires
    )) return 0;
    uint available1 = safeSub(amountGet, orderFills[user][hash]);
    uint available2 = safeMul(tokens[tokenGive][user], amountGet) / amountGive;
    if (available1<available2) return available1;
    return available2;
  }

  function amountFilled(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint8 v, bytes32 r, bytes32 s) constant returns(uint) {
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce);
    return orderFills[user][hash];
  }

  function cancelOrder(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, uint8 v, bytes32 r, bytes32 s) {
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce);
    if (!(orders[msg.sender][hash] || ecrecover(sha3("\x19Ethereum Signed Message:\n32", hash),v,r,s) == msg.sender)) throw;
    orderFills[msg.sender][hash] = amountGet;
    Cancel(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, msg.sender, v, r, s);
  }
}
