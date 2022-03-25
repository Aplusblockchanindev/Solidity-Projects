pragma solidity >=0.7.0 <0.9.0;

contract Auction{

    event LogBid(address bidder, uint bid, address highestBidder, uint highestBid, uint highestBindBid);
    event LogWithdraw(address withdrawer, address withdrawalAddress, uint amount);
    event LogCancelled();

    // static
    address public owner;
    uint public startBlock;
    uint public endBlock;
    string public ipfsHash;
    uint public bidIncrement;

    // state
    bool public canceled;
    address public highestBidder;
    mapping(address => uint256) public fundsByBidder;
    uint public highestBindingBid;
    bool ownerHasWithdrawn;

    constructor (address _owner, uint _bidIncrement, uint _startBlock, uint _endBlock, string memory _ipfsHash) {
        require(_startBlock < _endBlock);
        require(_startBlock > block.number);
        require(_owner != address(0));

        owner = _owner;
        bidIncrement = _bidIncrement;
        startBlock = _startBlock;
        endBlock = _endBlock;
        ipfsHash = _ipfsHash;
    }
    modifier onlyRunning {
        require(!canceled);
        require(block.number > startBlock && block.number < endBlock);
        _;
    }
    modifier onlyNotOwner {
        require(msg.sender != owner);
        _;
    }
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlyAfterStart {
        require(block.number > startBlock);
        _;
    }

    modifier onlyBeforeEnd {
        require(block.number < endBlock);
        _;
    }

    modifier onlyNotCanceled {
        require(!canceled);
        _;
    }    
    function placeBid() public
        payable
        onlyAfterStart
        onlyBeforeEnd
        onlyNotCanceled
        onlyNotOwner
        returns (bool success)
    {
        // reject payments of 0 ETH
        require(msg.value != 0);

        // calculate the user's total bid based on the current amount they've sent to the contract
        // plus whatever has been sent with this transaction
        uint newBid = fundsByBidder[msg.sender] + msg.value;

        // if the user isn't even willing to overbid the highest binding bid, there's nothing for us
        // to do except revert the transaction.
        require(newBid > highestBindingBid);

        // grab the previous highest bid (before updating fundsByBidder, in case msg.sender is the
        // highestBidder and is just increasing their maximum bid).
        uint highestBid = fundsByBidder[highestBidder];

        fundsByBidder[msg.sender] = newBid;

        if (newBid <= highestBid) {
            // if the user has overbid the highestBindingBid but not the highestBid, we simply
            // increase the highestBindingBid and leave highestBidder alone.

            // note that this case is impossible if msg.sender == highestBidder because you can never
            // bid less ETH than you already have.
            highestBindingBid = newBid+bidIncrement;
            if(highestBindingBid > highestBid) 
                highestBindingBid = highestBid;
        } else {
            // if msg.sender is already the highest bidder, they must simply be wanting to raise
            // their maximum bid, in which case we shouldn't increase the highestBindingBid.

            // if the user is NOT highestBidder, and has overbid highestBid completely, we set them
            // as the new highestBidder and recalculate highestBindingBid.

            if (msg.sender != highestBidder) {
                highestBidder = msg.sender;
                highestBindingBid = highestBid + bidIncrement;
                if(highestBindingBid > newBid) highestBindingBid = newBid;
            }
            highestBid = newBid;
        }

        emit LogBid(msg.sender, newBid, highestBidder, highestBid, highestBindingBid);
        return true;
    }

    modifier onlyEndedOrCanceled{
        _;
    }

    function withdraw() payable public
        onlyEndedOrCanceled
        returns (bool success)
    {
        address withdrawalAccount;
        uint withdrawalAmount;

        if (canceled) {
            // if the auction was canceled, everyone should simply be allowed to withdraw their funds
            withdrawalAccount = msg.sender;
            withdrawalAmount = fundsByBidder[withdrawalAccount];

        } else {
            // the auction finished without being canceled

            if (msg.sender == owner) {
                // the auction's owner should be allowed to withdraw the highestBindingBid
                withdrawalAccount = highestBidder;
                withdrawalAmount = highestBindingBid;
                ownerHasWithdrawn = true;

            } else if (msg.sender == highestBidder) {
                // the highest bidder should only be allowed to withdraw the difference between their
                // highest bid and the highestBindingBid
                withdrawalAccount = highestBidder;
                if (ownerHasWithdrawn) {
                    withdrawalAmount = fundsByBidder[highestBidder];
                } else {
                    withdrawalAmount = fundsByBidder[highestBidder] - highestBindingBid;
                }

            } else {
                // anyone who participated but did not win the auction should be allowed to withdraw
                // the full amount of their funds
                withdrawalAccount = msg.sender;
                withdrawalAmount = fundsByBidder[withdrawalAccount];
            }
        }

        require(withdrawalAmount != 0);

        fundsByBidder[withdrawalAccount] -= withdrawalAmount;

        // send the funds
        require(payable(msg.sender).send(withdrawalAmount));

        emit LogWithdraw(msg.sender, withdrawalAccount, withdrawalAmount);

        return true;
    }

    function cancelAuction() public
        onlyOwner
        onlyBeforeEnd
        onlyNotCanceled
        returns (bool success)
    {
        canceled = true;
        emit LogCancelled();
        return true;
    }
}