// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


contract ERC20Yul{



// internal and constant -> makes them immutable - security 
//                          and        constant - saves gas than storing it in storage 

// 32 bytes keccak hash of event selectors 
// The full 32-byte Keccak-256 hash uniquely identifies the event type.
// Even if different contracts emit events with the same signature string,
// the full hash ensures that the event can be uniquely identified
bytes32 internal constant  _TRANSFER_HASH  = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef ;
bytes32 internal constant  _APPROVAL_HASH = 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925 ;

// 4 bytes selectors of ERROR strings -> padded to 32 bytes   
// padded for easy storage access
bytes32 internal constant  _INSUFFICIENT_BALANCE = 0xf4d678b800000000000000000000000000000000000000000000000000000000 ;
bytes32 internal constant _INSUFFICIENT_ALLOWANCE_SELECTOR = 0x13be252b00000000000000000000000000000000000000000000000000000000;
bytes32 internal constant _RECIPIENT_ZERO_SELECTOR = 0x4c131ee600000000000000000000000000000000000000000000000000000000;
bytes32 internal constant _INVALID_SIG_SELECTOR = 0x8baa579f00000000000000000000000000000000000000000000000000000000;
bytes32 internal constant _EXPIRED_SELECTOR = 0x203d82d800000000000000000000000000000000000000000000000000000000;
bytes32 internal constant _STRING_TOO_LONG_SELECTOR = 0xb11b2ad800000000000000000000000000000000000000000000000000000000;
bytes32 internal constant _OVERFLOW_SELECTOR = 0x35278d1200000000000000000000000000000000000000000000000000000000;

// _MAX amount value 
bytes32 internal constant _MAX = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;


// EIP 712 
bytes32 internal constant _EIP712_DOMAIN_PREFIX_HASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
bytes32 internal constant _VERSION_1_HASH = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;

// EIP 2612
bytes32 internal constant _PERMIT_HASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

// name and symbol
// prevents dynamic allocation as strings
bytes32 internal immutable  _name;
bytes32 internal immutable _symbol;

// length of name and string
// for conversion in future 
uint256 internal immutable _nameLen;
uint256 internal immutable _symbolLen;

// EIP 2612
uint256 internal immutable _initialChainId;
bytes32 internal immutable _initialDomainSeparator;

// balances mappings 
mapping(address => uint256) internal _balances;
mapping(address => mapping( address => uint256 )) internal _allowances;

// maintains the total supply of tokens 
// updates when getting burned or minted 
uint256 internal _supply;
mapping(address => uint256) internal  _nonces;

constructor(string memory name_, string memory symbol_){

bytes memory nameX = bytes(name_);
bytes memory symbolX = bytes(symbol_);
uint256  nameLen = nameX.length;
uint256  symbolLen = symbolX.length;

// checks if name and symbol are less than 32 bytes 
assembly{
    if or(lt(0x20,nameLen), lt(0x20,symbolX)){
        mstore(0x00,_STRING_TOO_LONG_SELECTOR)
        revert(0x00, 0x04)
    }
}

// compute domain separator
bytes32 initialDomainSeparator = _computeDomainSeparator(
    keccak256(nameX)
);

// setting the storage variables
_name = bytes32(nameX);
_symbol = bytes32(symbolX);
_initialChainId = block.chainid;
_initialDomainSeparator = initialDomainSeparator;
_nameLen = nameLen;
_symbolLen = symbolLen;

}

// transfer function from address to address 
function transfer(address _to, uint _value) public virtual returns(bool success){

    assembly{
        // checks if the receipinet address is nonzero 
        if iszero(_to){
            mstore(0x00,_RECIPIENT_ZERO_SELECTOR)
            revert(0x00, 0x04)
        }
        // load the caller() and store at 0x00 memory location
        mstore(0x00, caller()) 
        mstore(0x20,0x00) // stores 0x00 at 0x20 location 
        let srcSender :=  keccak256(0x00,0x40)
        let balSender := sload(srcSender)
        // checking for sufficient balance
        if lt(balSender,_value){
            mstore(0x00,_INSUFFICIENT_BALANCE)
            revert(0x00,0x04)
        }
        // update senders balance
        sstore(srcSender, sub(balSender,_value))
        // update receipt balance
        mstore(0x00,_to)
        let srcReceipt := keccak256(0x00,0x40)
        let balReceipt := sload(srcReceipt)
        // receipt balance update
        sstore(srcReceipt, add(balReceipt,_value))
        // emit event logs 
        mstore(0x00,_value)
        log3(0x00,0x20,_TRANSFER_HASH,caller(),_to)
        // returns true
        success := 0x01 

    }
}

function transferFrom(address _from , address _to , uint256 _value) public virtual returns(bool success){

assembly{
    // check for addresses not zero 
     if or( iszero(_from) , iszero(_to) ) {
        mstore(0x00,_RECIPIENT_ZERO_SELECTOR )
        revert(0x00,0x04)
     }
     mstore(0x00,_from)
     mstore(0x20,0x01)
     mstore(0x20,keccak256(0x00,0x40) )
     mstore(0x00,caller())
     let srcAllowance := keccak256(0x00,0x40)
     let balAllowance := sload(srcAllowance)
    // check for sufficient funds
     if lt(balAllowance,_MAX){
        if lt(balAllowance,_value){
        mstore(0x00,_INSUFFICIENT_BALANCE)
        revert(0x00,0x04)
     }
        // update allowance
        sstore(srcAllowance, sub(balAllowance,_value))
     }
     // update senders balance
     mstore(0x00,_from)
     mstore(0x20,0x00)
     let srcSender := keccak256(0x00,0x40)
     let balSender := sload(srcSender)
     if lt(balSender,_value){
        mstore(0x00,_INSUFFICIENT_BALANCE)
        revert(0x00,0x04)
     }
     sstore(srcSender, sub(balSender,_value))

     // update receiver balance
     mstore(0x00,_to)
     mstore(0x20,0x00)
     let srcRecipt := keccak256(0x00,0x40)
     let balReceipt :=  sload(srcRecipt)
     sstore(srcRecipt, add(balReceipt,_value))

     mstore(0x00,_value)
     log3(0x00,0x20,_TRANSFER_HASH,_from , _to )
     success := 0x00

}
}

function approve(address _to, uint256 _value) public virtual returns(bool success){

    assembly{
         // check address zero 
         if iszero(_to){
            mstore(0x00,_RECIPIENT_ZERO_SELECTOR)
            revert(0x00,0x04)
         }
         // set approval 
        mstore(0x00, caller())
        mstore(0x020, 0x01)
        mstore(0x20, keccak256(0x00,0x40))
        mstore(0x00,_to)
        sstore(keccak256(0x00,0x40),_value)
        // emit approval event 
        mstore(0x00,_value)
        log3(0x00,0x20,_APPROVAL_HASH,caller(),_to)
        // return true
        success := 0x01
    }

}

function allowance(address _from ,address _to) public virtual returns(uint256 _value){

    assembly{
        // check if address is zero 
        if iszero(_to){
            mstore(0x00,_RECIPIENT_ZERO_SELECTOR)
            revert(0x00,0x04)
        }
        // retreive the allowance
        mstore(0x00,_from)
        mstore(0x20,0x01)
        mstore(0x20,keccak256(0x00,0x40))
        mstore(0x00,_to)
        let allowanceSlot := keccak256(0x00,0x40)
        // returns the value 
        _value := sload(allowanceSlot)

    }
}


function baalanceOf(address _to) public virtual returns (uint256 _value){

        assembly{
            // check if balance is zero 
            if iszero(_to){
                mstore(0x00,_RECIPIENT_ZERO_SELECTOR)
                revert(0x00,0x04)
            }
            mstore(0x00,_to)
            mstore(0x20,0x00)
            let srcReceipt := keccak256(0x00,0x40)
            // load the amount and retrun 
            _value := sload(srcReceipt)

        }

}
function nonces(address _to) public virtual returns(uint256 _nonceValue){
    assembly{
        // check if address is zero
        if iszero(_to){
            mstore(0x00,_RECIPIENT_ZERO_SELECTOR)
            revert(0x00,0x04)
        }
        //  get storage slot of the nonce from address
        mstore(0x00,_to)
        mstore(0x20,0x03)
        // load and return the nonce value
        _nonceValue := sload(keccak256(0x00,0x40))
    }
}



function totalSupply() public virtual returns(uint256 _totalSupply){
    assembly{
        // load value from 0x03 storage slot 
        _totalSupply := sload(0x02)
    }
}

function name() public virtual returns(string memory value){
    bytes32 nameTemp = _name;
    uint256 nameLenTemp = _symbolLen ;
    assembly{
        // load the memory location available for storing in memory
        value := mload(0x40)
        // store the length of string at the starting of free memory available
        mstore(value,nameLenTemp)
        // store the value of the string at memory location just after the stored length
        mstore(add(0x20,value),nameTemp)
        // update the memory pointer 
        mstore(0x40,add(0x40,value))
    }
}

function symbol() public virtual returns(uint256 value){
    bytes32  symbolTemp = _symbol ;
    uint256 symbolLenTemp = _symbolLen;
    assembly{
    // loads the free memory location where data can be stored
      value:= mload(0x40)
      // stroring the length of symbol at starting of the free memory location 
      mstore(value,symbolLenTemp)
      // storing the value of symbol in memory slot just after the stored length of symbol
      mstore(add(value,0x20),symbolTemp)
      // updating the value of free memory pointer 
      mstore(0x40,add(0x40,value))
    }
}

function decimal() public virtual returns(uint256 ){
    return 18;
}

function _mint(address _to, uint256 _amount) public virtual returns( bool success){
    assembly{
        //check if address is non zero
        if iszero(_to){
            mstore(0x00,_RECIPIENT_ZERO_SELECTOR)
            revert(0x00,0x04)
        }
        let supply := sload(_supply.slot)
        let newSupply := add(supply, _amount)
        // check for overflow
        if lt(newSupply, supply){
            mstore(0x00,_OVERFLOW_SELECTOR)
            revert(0x00,0x04)
        }
        // update the stoarge value with new value 
        sstore(_supply.slot,newSupply)
        mstore(0x00,_to)
        mstore(0x20,_balances.slot)
        // slot where the balance is saved
        let srcTo := keccak256(0x00,0x40)
        let srcBal := sload(srcTo)
        let newBalance := add(srcBal,_amount)
        // check for overflow 
        if lt(newBalance,srcBal){
            mstore(0x00,_OVERFLOW_SELECTOR)
            revert(0x00,0x04)
        }
        sstore(srcTo,newBalance)
        // Emit a Transfer event from the zero address to indicate tokens were minted.
        mstore(0x00, _amount)
        log3(0x00, 0x20, _TRANSFER_HASH, _to, _amount)
        success := 0x01

    }
}

function _burn(address _src, uint256 _amount) internal virtual {
    assembly {
        // Check the balance of the source address to ensure it has enough tokens to burn.
        mstore(0x00, _src)
        mstore(0x20, _balances.slot)
        let srcSlot := keccak256(0x00, 0x40)
        let srcBalance := sload(srcSlot)

        if lt(srcBalance, _amount) {
            mstore(0x00, _INSUFFICIENT_BALANCE)
            revert(0x00, 0x04)
        }
        // Deduct the amount from the source address's balance.
        sstore(srcSlot, sub(srcBalance, _amount))
        // Reduce the total supply by the amount burned.
        let supply := sload(_supply.slot)
        sstore(_supply.slot, sub(supply, _amount))
        // Emit a Transfer event with the destination address as the zero address to indicate burning.
        mstore(0x00, _amount)
        log3(0x00, 0x20, _TRANSFER_HASH, _src, _amount)
    }
}

// solhint-disable-next-line func-name-mixedcase
function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
    return
        block.chainid == _initialChainId
            ? _initialDomainSeparator
            : _computeDomainSeparator(keccak256(abi.encode(_name)));
}

function _computeDomainSeparator(bytes32 nameHash)
    public
    view virtual 
    returns (bytes32 domainSeparator)
{
    assembly {
        let memptr := mload(0x40) // Load the free memory pointer.
        mstore(memptr, _EIP712_DOMAIN_PREFIX_HASH) // EIP-712 domain prefix hash.
        mstore(add(memptr, 0x20), nameHash) // Token name hash.
        mstore(add(memptr, 0x40), _VERSION_1_HASH) // Version hash ("1").
        mstore(add(memptr, 0x60), chainid()) // Current chain ID.
        mstore(add(memptr, 0x80), address()) // Contract address.
        // Compute the EIP-712 domain separator.
        domainSeparator := keccak256(memptr, 0xA0)
    }
}

}