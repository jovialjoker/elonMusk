//SPDX-License-Identifier: GPL-3.0
 
pragma solidity >=0.5.0 <0.9.0;

contract AuctionCreator{
    Auction[] public auctions;
    uint256 public auctionsCount;

    struct AuctionInfo {
        uint id;
        address auctionAddress;
        string title;
        string description;
        string[] imageUrls;
    }

    function createAuction(string memory _title, string memory _description, string[] memory _imagesUrls) public{
        Auction newAuction = new Auction(msg.sender, auctionsCount, _title, _description, _imagesUrls);
        auctions.push(newAuction); // the address of the externally owned account; the owner of the auction
        auctionsCount ++;
    }

    function getLatestAuctionAddress() public view returns (address){
        return address(auctions[auctionsCount - 1]);
    }

    function getAuctionBalance(uint index) public view returns (uint) {
        require(index < auctions.length, "Invalid index");
        return auctions[index].getBalance();
    }

    function getAuctions() public view returns (AuctionInfo[] memory) {
        AuctionInfo[] memory auctionInfoList = new AuctionInfo[](auctionsCount);

        for (uint256 i = 0; i < auctionsCount; i++) {
            address auctionAddress = address(auctions[i]);
            auctionInfoList[i] = AuctionInfo(auctions[i].getId(), auctionAddress, auctions[i].getTitle(), auctions[i].getDescription(), auctions[i].getImageUrls());
        }

        return auctionInfoList;
    }

}


contract Auction{
    // receive Eth; seen by everyone
    uint public id;
    address payable public owner;
    uint public startBlock;
    uint public endBlock;
    string public ipfsHash;
    string public title;
    string public description;
    string[] public imageUrls;

    enum State {
        Started, Running, Ended, Canceled
    }
    State public auctionState;

    uint public highestBindingBid;
    // the winner of the auction
    address payable public highestBidder;

    // bidders and the amount they bid
    mapping(address => uint) public bids;

    uint bidIncrement;

     // BidPlaced event
    event BidPlaced(address indexed bidder, uint amount, string message);

    struct AuctionDetailsDTO{
        uint id;
        uint highestBiddingBid;
        string title;
        string description;
        string[] imageUrls;
        uint startBlock;
        uint endBlock;
        address owner;
        address highestBidder;
        State auctionState;
    }
    


    constructor(address eoa, uint _id, string memory _title, string memory _description, string[] memory _imageUrls){
        owner = payable(eoa);
        auctionState = State.Running;
        // safer from spoofing ETH blocktime is 15s
        // block => global variable
        startBlock = block.number;
        // 40320 blocks created in a week
        endBlock = startBlock + 40320;
        // endBlock = startBlock + 4;
        ipfsHash = "";
        // bidIncrement = 100 
        bidIncrement = 10000000000; // 1eth

        id = _id;
        title = _title;
        description = _description;
        imageUrls = _imageUrls;
    }

    modifier notOwner(){
        require(msg.sender != owner);
        _;
    }

    modifier afterStart(){
        require(block.number >= startBlock);
        _;
    }

    modifier beforeEnd(){
        require(block.number <= endBlock);
        _;
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "Only the owner can cancel the auction");
        _;
    }

    // pure does not alternate blockchain/ it doesn't read the blockchain
    function min(uint a, uint b) pure internal returns(uint){
        if(a <= b){
            return a;
        }
        else{
            return b;
        }
    }

    function cancelAuction() public onlyOwner{
        auctionState = State.Canceled;
    }

    // the owner can t place a bid
    function placeBid() public payable afterStart beforeEnd notOwner{

        // Check if the auction is running and bid value meets the minimum requirement
        require(auctionState == State.Running, "Auction is not running");
        require(msg.value >= 100, "Bid value must be at least 100 wei");

        // Ensure that the bid exceeds the current highest bid
        uint currentBid = bids[msg.sender] + msg.value;
        require(currentBid > highestBindingBid, "Bid must exceed current highest bid");

        // Update bidder's bid amount
        bids[msg.sender] = currentBid;

        // Update highest bid and bidder
        if(currentBid <= bids[highestBidder]) {
            highestBindingBid = min(currentBid + bidIncrement, bids[highestBidder]);
        } else {
            highestBindingBid = min(currentBid, bids[highestBidder] + bidIncrement);
            highestBidder = payable(msg.sender);
        }
        
        // Emit BidPlaced event
        emit BidPlaced(msg.sender, msg.value, "Bid placed successfully");
    }

    function finalizeAuction() public {
        // the auction ended
        require(auctionState == State.Canceled || block.number > endBlock);
        // owner or a bidder
        require(msg.sender == owner || bids[msg.sender] > 0);

        address payable recipient;  // the bidder who wants his money back
        uint value;

        // the auction was cancelled 
        if(auctionState == State.Canceled){
            // the bidders can request their money
            recipient = payable(msg.sender);
            value = bids[msg.sender];
        }
        // auction ended, not canceled
        else{
            // the owner will receive the highest bid
            if(msg.sender == owner){
                recipient = owner;
                value = highestBindingBid;
            }
            // bidder will request their funds
            else{
                if(msg.sender == highestBidder){
                    recipient = highestBidder;
                    value = bids[highestBidder] - highestBindingBid;
                }
                // neither the owner/ highest bidder
                else{
                    recipient = payable(msg.sender);
                    value = bids[msg.sender];
                }
            }
        }  
        // resetting the bids value => can call finalize only once 
        bids[recipient] = 0;
        recipient.transfer(value); 
    }

    function getBalance() external view returns (uint){
        return address(this).balance;
    }

    function getTitle() public view returns (string memory) {
        return title;
    }

    function getDescription() public view returns (string memory) {
        return description;
    }

    function getImageUrls() public view returns (string[] memory) {
        return imageUrls;
    }

    function getId() public view returns (uint) {
        return id;
    }

    function getAuctionDetails() public view returns(AuctionDetailsDTO memory){
        AuctionDetailsDTO memory auctionDetails = AuctionDetailsDTO(id, highestBindingBid, title, description, imageUrls, startBlock, endBlock, owner, address(highestBidder), auctionState);
        return auctionDetails;
    }
}