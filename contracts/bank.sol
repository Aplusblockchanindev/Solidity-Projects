pragma solidity ^0.8.0;

contract Bank{
    address public bankOwner;
    string public bankName;

    mapping(address => uint256) public customerBalances;

    constructor(){
        // require(bankOwner == msg.sender,"");
        bankOwner = msg.sender;
    }

    function depositeMoney() public payable{
        require(msg.value>0,"You need to deposite some amount of money");
        customerBalances[msg.sender] += msg.value;
    }

    function setBankName(string memory _name) public {
        require(msg.sender == bankOwner,"You must be the owner");
        bankName = _name;
    }
    
    function withdrawMoney(address payable _to, uint256 _amount) public{
        require(_amount<=customerBalances[msg.sender],"You don't have sufficient funds!");
        customerBalances[msg.sender] -= _amount;
        _to.transfer(_amount);
    }

    function getCustomerBalance() public view returns(uint256){
        return customerBalances[msg.sender];
    }
    function getBankBalance() public view returns(uint256){
        require(msg.sender == bankOwner,"You must be a bank owner to see all balance");
        return address(this).balance;

    }
}