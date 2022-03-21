pragma solidity >=0.7.0 <0.9.0;

contract Ballot{
    struct Voter{
        uint weight;
        bool voted;
        address delegate;
        uint vote;
    }

    struct Proposal{
        bytes32 name;
        uint voteCount;
    }

    address public chairperson;

    mapping(address => Voter) public voters;

    Proposal[] public proposals;

    constructor(bytes32[] memory proposalNames){
        chairperson = msg.sender;
        voters[chairperson].weight = 1;

        for(uint i=0;i<proposalNames.length;i++){
            proposals.push(Proposal({name:proposalNames[i],voteCount:0}));
        }
    }

    function giveRightToVoter(address voter) public {
        require(msg.sender == chairperson,"Only Chair person can give rights to voter");
        require(!voters[voter].voted,"Already voted");
        voters[voter].weight = 1;
    }

    function delegate(address to) public{
        Voter storage sender = voters[msg.sender];
        require(!sender.voted,"Already voted before delegate");

        require(to!=msg.sender,"Self-delegation is disallowed");

        while(voters[to].delegate != address(0)){
            to = voters[to].delegate;
            require(to != msg.sender,"Found loop in the delegation");
        }

        Voter storage delegate_ = voters[to];

        require(delegate_.weight >= 1, "Can not delegate if the target wallet can not vote");
        sender.voted = true;
        sender.delegate = to;

        if(delegate_.voted){
            proposals[delegate_.vote].voteCount += sender.weight;
        }
        else{
            delegate_.weight += sender.weight;
        }

    }

    function vote(uint proposal) public{
        Voter storage sender = voters[msg.sender];
        require(sender.weight>=0,"Has not right to vote");
        require(!sender.voted, "Already voted!"); 
        sender.voted = true;
        sender.vote = proposal;
        proposals[proposal].voteCount += sender.weight;
    }

    function winningProposals() public view returns(uint winningProposals_){
        uint maxVoteCount = 0;
        for(uint i=0;i<proposals.length;i++){
            if(maxVoteCount<proposals[i].voteCount){
                maxVoteCount = proposals[i].voteCount;
                winningProposals_ = i;
            }
        }
    }

    function winnerName() public view returns(bytes32){
        return proposals[winningProposals()].name;
    }

}