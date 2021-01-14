pragma solidity ^0.5.5;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "../interface/IERC20.sol";

import "../library/SafeERC20.sol";
import "../library/Governance.sol";

contract NFTMarket is IERC721Receiver, Governance {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public _dandy = IERC20(0x0);

    struct SalesObject {
        uint256 id;

        uint256 tokenId;
        address payable seller;
        IERC721 nft;

        address payable buyer;

        uint256 startTime;
        uint256 durationTime;

        uint256 maxPrice;
        uint256 minPrice;
        uint256 finalPrice;

        uint8 status;
    }

    uint256 public _salesAmount = 0;

    SalesObject[] _salesObjects;

    uint256 public _minDurationTime = 5 minutes;

    mapping(address => bool) public _seller;
    mapping(address => bool) public _verifySeller;
    mapping(address => bool) public _supportNft;
    bool public _isStartUserSales;

    bool public _isRewardSellerDandy = false;
    bool public _isRewardBuyerDandy = false;

    uint256 public _sellerRewardDandy = 1e15;
    uint256 public _buyerRewardDandy = 1e15;

    uint256 public _tipsFeeRate = 20;
    uint256 public _baseRate = 1000;
    address payable _tipsFeeWallet;

    event eveSales(
        uint256 indexed id, 
        uint256 tokenId,
        address buyer, 
        uint256 finalPrice, 
        uint256 tipsFee
    );

    event eveNewSales(
        uint256 indexed id,
        uint256 tokenId, 
        address seller, 
        address nft,
        address buyer, 
        uint256 startTime,
        uint256 durationTime,
        uint256 maxPrice, 
        uint256 minPrice,
        uint256 finalPrice
    );

    event eveCancelSales(
        uint256 indexed id,
        uint256 tokenId
    );

    event eveNFTReceived(address operator, address from, uint256 tokenId, bytes data);

    /**
     * check address
     */
    modifier validAddress( address addr ) {
        require(addr != address(0x0));
        _;
    }

    modifier checkindex(uint index) {
        require(index <= _salesObjects.length, "overflow");
        _;
    }

    modifier checkTime(uint index) {
        require(index <= _salesObjects.length, "overflow");
        SalesObject storage obj = _salesObjects[index];
        require(obj.startTime <= now, "!open");
        _;
    }


    modifier mustNotSellingOut(uint index) {
        require(index <= _salesObjects.length, "overflow");
        SalesObject storage obj = _salesObjects[index];
        require(obj.buyer == address(0x0) && obj.status == 0, "sry, selling out");
        _;
    }

    modifier onlySalesOwner(uint index) {
        require(index <= _salesObjects.length, "overflow");
        SalesObject storage obj = _salesObjects[index];
        require(obj.seller == msg.sender || msg.sender == _governance, "author & governance");
        _;
    }

    function seize(IERC20 asset) external returns (uint256 balance) {
        balance = asset.balanceOf(address(this));
        asset.safeTransfer(_governance, balance);
    }

    function() external payable {
        revert();
    }

    function setSellerRewardDandy(uint256 rewardDandy) public onlyGovernance {
        _sellerRewardDandy = rewardDandy;
    }

    function setBuyerRewardDandy(uint256 rewardDandy) public onlyGovernance {
        _buyerRewardDandy = rewardDandy;
    }

    function addSupportNft(address nft) public onlyGovernance validAddress(nft) {
        _supportNft[nft] = true;
    }

    function removeSupportNft(address nft) public onlyGovernance validAddress(nft) {
        _supportNft[nft] = false;
    }

    function addSeller(address seller) public onlyGovernance validAddress(seller) {
        _seller[seller] = true;
    }

    function removeSeller(address seller) public onlyGovernance validAddress(seller) {
        _seller[seller] = false;
    }

    function addVerifySeller(address seller) public onlyGovernance validAddress(seller) {
        _verifySeller[seller] = true;
    }

    function removeVerifySeller(address seller) public onlyGovernance validAddress(seller) {
        _verifySeller[seller] = false;
    }

    function setIsStartUserSales(bool isStartUserSales) public onlyGovernance {
        _isStartUserSales = isStartUserSales;
    }

    function setIsRewardSellerDandy(bool isRewardSellerDandy) public onlyGovernance {
        _isRewardSellerDandy = isRewardSellerDandy;
    }

    function setIsRewardBuyerDandy(bool isRewardBuyerDandy) public onlyGovernance {
        _isRewardBuyerDandy = isRewardBuyerDandy;
    }

    function setMinDurationTime(uint256 durationTime) public onlyGovernance {
        _minDurationTime = durationTime;
    }

    function setTipsFeeWallet(address payable wallet) public onlyGovernance {
        _tipsFeeWallet = wallet;
    }

    function getSalesEndTime(uint index) 
        external
        view
        checkindex(index)
        returns (uint256) 
    {
        SalesObject storage obj = _salesObjects[index];
        return obj.startTime.add(obj.durationTime);
    }

    function getSales(uint index) external view checkindex(index) returns(SalesObject memory) {
        return _salesObjects[index];
    }

    function getSalesPrice(uint index)
        external
        view
        checkindex(index)
        returns (uint256)
    {
        SalesObject storage obj = _salesObjects[index];
        if(obj.buyer != address(0x0) || obj.status == 1) {
            return obj.finalPrice;
        } else {
            if(obj.startTime.add(obj.durationTime) < now) {
                return obj.minPrice;
            } else if (obj.startTime >= now) {
                return obj.maxPrice;
            } else {
                uint256 per = obj.maxPrice.sub(obj.minPrice).div(obj.durationTime);
                return obj.maxPrice.sub(now.sub(obj.startTime).mul(per));
            }
        }
    }

    function setDandyAddress(address addr) external onlyGovernance validAddress(addr) {
        _dandy = IERC20(addr);
    }

    function setBaseRate(uint256 rate) external onlyGovernance {
        _baseRate = rate;
    }

    function setTipsFeeRate(uint256 rate) external onlyGovernance {
        _tipsFeeRate = rate;
    }

    function isVerifySeller(uint index) public view checkindex(index) returns(bool) {
        SalesObject storage obj = _salesObjects[index];
        return _verifySeller[obj.seller];
    }

    function cancelSales(uint index) external checkindex(index) onlySalesOwner(index) mustNotSellingOut(index)  {
        SalesObject storage obj = _salesObjects[index];
        obj.status = 2;
        obj.nft.safeTransferFrom(address(this), obj.seller, obj.tokenId);

        emit eveCancelSales(index, obj.tokenId);
    }

    function startSales(uint256 tokenId,
                        uint256 maxPrice, 
                        uint256 minPrice,
                        uint256 startTime, 
                        uint256 durationTime,
                        address nft)
        external 
        validAddress(nft)
        returns(uint)
    {
        require(tokenId != 0, "invalid token");
        require(startTime.add(durationTime) > now, "invalid start time");
        require(durationTime >= _minDurationTime, "invalid duration");
        require(maxPrice >= minPrice, "invalid price");
        require(_isStartUserSales || _seller[msg.sender] == true || _supportNft[nft] == true, "cannot sales");

        IERC721(nft).safeTransferFrom(msg.sender, address(this), tokenId);

        _salesAmount++;
        SalesObject memory obj;

        obj.id = _salesAmount;
        obj.tokenId = tokenId;
        obj.seller = msg.sender;
        obj.nft = IERC721(nft);
        obj.buyer = address(0x0);
        obj.startTime = startTime;
        obj.durationTime = durationTime;
        obj.maxPrice = maxPrice;
        obj.minPrice = minPrice;
        obj.finalPrice = 0;
        obj.status = 0;

        
        if (_salesObjects.length == 0) {
            SalesObject memory zeroObj;
            zeroObj.tokenId = 0;
            zeroObj.seller = address(0x0);
            zeroObj.nft = IERC721(0x0);
            zeroObj.buyer = address(0x0);
            zeroObj.startTime = 0;
            zeroObj.durationTime = 0;
            zeroObj.maxPrice = 0;
            zeroObj.minPrice = 0;
            zeroObj.finalPrice = 0;
            zeroObj.status = 2;
            _salesObjects.push(zeroObj);    
        }

        _salesObjects.push(obj);

        if(_isRewardSellerDandy || _verifySeller[msg.sender]) {
            _dandy.mint(msg.sender, _sellerRewardDandy);
        }

        emit eveNewSales(obj.id, tokenId, msg.sender, nft, address(0x0), startTime, durationTime, maxPrice, minPrice, 0);
        return _salesAmount;
    }

    function buy(uint index)
        public
        mustNotSellingOut(index)
        checkTime(index)
        payable 
    {
        SalesObject storage obj = _salesObjects[index];
        require (msg.value >= this.getSalesPrice(index), "umm.....  your price is too low");
        uint256 price = this.getSalesPrice(index);
        uint256 returnBack = msg.value.sub(price);
        if(returnBack > 0) {
            msg.sender.transfer(returnBack);
        }

        uint256 tipsFee = price.mul(_tipsFeeRate).div(_baseRate);
        uint256 purchase = price.sub(tipsFee);

        if(_isRewardBuyerDandy || _verifySeller[obj.seller]) {
            _dandy.mint(msg.sender, _buyerRewardDandy);
        }

        if(tipsFee > 0) {
            _tipsFeeWallet.transfer(tipsFee);
        }

        obj.seller.transfer(purchase);
        obj.nft.safeTransferFrom(address(this), msg.sender, obj.tokenId);
        
        obj.buyer = msg.sender;
        obj.finalPrice = price;

        obj.status = 1;

        // fire event
        emit eveSales(index, obj.tokenId, msg.sender, price, tipsFee);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data) public returns (bytes4) {
        //only receive the _nft staff
        if(address(this) != operator) {
            //invalid from nft
            return 0;
        }

        //success
        emit eveNFTReceived(operator, from, tokenId, data);
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}
