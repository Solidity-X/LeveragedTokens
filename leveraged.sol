//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
library math {

    int constant LOG2_E = 1442695040888963407; // precalculated
    int constant MAX_SD59x18 = 57896044618658097711785492504343953926634992332820282019728792003956564819967; // cleaner than writing it everytime
    int constant LN10 = 2302585092994045684; // precalculated

    /*\
    e^x using tailor series
    \*/
    function fixedExp(uint x) internal pure returns (uint) {
        uint256 term = 1e18;
        uint256 sum = 1e18;
        for (uint256 i = 1; i < 100; i++) { // Adjust the number of iterations as needed
            term = (term * x) / (1e18 * i);
            sum += term;
        }
        return sum;
    }


    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        if (x >= 2**128) {
            x >>= 128;
            msb += 128;
        }
        if (x >= 2**64) {
            x >>= 64;
            msb += 64;
        }
        if (x >= 2**32) {
            x >>= 32;
            msb += 32;
        }
        if (x >= 2**16) {
            x >>= 16;
            msb += 16;
        }
        if (x >= 2**8) {
            x >>= 8;
            msb += 8;
        }
        if (x >= 2**4) {
            x >>= 4;
            msb += 4;
        }
        if (x >= 2**2) {
            x >>= 2;
            msb += 2;
        }
        if (x >= 2**1) {
            // No need to shift x any more.
            msb += 1;
        }
    }

    /*\
    log2(x)
    \*/
    function log2(int256 x) internal pure returns (int256 result) {
        require(x > 0);
        unchecked {
            // This works because log2(x) = -log2(1/x).
            int256 sign;
            if (x >= 1e18) {
                sign = 1;
            } else {
                sign = -1;
                // Do the fixed-point inversion inline to save gas. The numerator is 1e18 * 1e18.
                assembly {
                    x := div(1000000000000000000000000000000000000, x)
                }
            }

            // Calculate the integer part of the logarithm and add it to the result and finally calculate y = x * 2^(-n).
            uint256 n = mostSignificantBit(uint256(x / 1e18));

            // The integer part of the logarithm as a signed 59.18-decimal fixed-point number. The operation can't overflow
            // because n is maximum 255, 1e18 is 1e18 and sign is either 1 or -1.
            result = int256(n) * 1e18;

            // This is y = x * 2^(-n).
            int256 y = x >> n;

            // If y = 1, the fractional part is zero.
            if (y == 1e18) {
                return result * sign;
            }

            // Calculate the fractional part via the iterative approximation.
            // The "delta >>= 1" part is equivalent to "delta /= 2", but shifting bits is faster.
            for (int256 delta = int256(5e17); delta > 0; delta >>= 1) {
                y = (y * y) / 1e18;

                // Is y^2 > 2 and so in the range [2,4)?
                if (y >= 2 * 1e18) {
                    // Add the 2^(-m) factor to the logarithm.
                    result += delta;

                    // Corresponds to z/2 on Wikipedia.
                    y >>= 1;
                }
            }
            result *= sign;
        }
    }

    /*\
    loge(x)
    \*/
    function ln(int256 x) internal pure returns (int256 result) {
        unchecked { result = (log2(x) * 1e18) / LOG2_E; }
    }

    /*\
    logy(x)
    \*/
    function log(int x, int y) internal pure returns (int256 result) {
        unchecked { result = (log2(x) * 1e18) / log2(y); }
    }

    function min(int a, int b) external pure returns(int result) {
        if (a < b)
            result = a;
        else
            result = b;
    }

    function max(int a, int b) external pure returns(int result) {
        if (a > b)
            result = a;
        else
            result = b;
    }
}

contract leveraged is ERC20, ERC20Permit, Ownable{

    /*\
    Written by SolidityX (telegram: @SolidityX)
    what is a leveraged token?
    A leveraged token is a high risk token which is in no need of liquidity pools
    It works by increase the price of the token by leverage for every unit minted. Thus the price of the token can be set as leverage**totalsupply
    the leverage must me greather than 1 (ex. 1.1 (1.1e18))
    leveraged tokens ARE transferable and use the ERC20 standart which allows for them to be added to a liquidity pool or even used on lending platforms.
    Bigger leveraged tokens could open liquidity pool which allows users to buy/sell leveraged tokens on multiple DEXES. The creation of liquidity pools would also allow for arbitrage.
    Bigger leverage tokens could also be used in lending/borrowing pools where lenders could earn a very high APY to the instrinsic risk and borrowers could short or increase their leverage further.
    Any project could create such token and earn a fee of up to 5% (to not totally scam everyone) on every burn and mint. The fee is not applicable on transfers to intrinsiclly promote the intergration of leveraged tokens into ther eco-systems.
    Further calculations and cleaner visualtion of the math going on in the background can be seen here: [INSERT LINK]
    \*/

    using math for int;
    using math for uint;

    uint lnLeverage;
    uint public fee; // fee that is charged for every mint/burn (100=1%)
    uint public leverage; // price increase per unit minted 
    IERC20 public tradeable; // token you can trade it against


    //tradeable: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    //leverage: 1100000000000000000

    /*\
    sets name, symbol, tradeable token and leverage
    makes sure that leverage is >1, otherwise the token price would decrease on purchase
    sets the ln(leverage) as its cheaper to store then calculating it everytime
    \*/
    constructor(address _owner, string memory _name, string memory _symbol, address _tradeable, uint _leverage, uint _fee) ERC20(_name, _symbol) ERC20Permit(_name) Ownable(_owner){
        require(_leverage > 1e18, "no valid leverage!");
        require(_fee <= 5*100, "fee can't exceed 5%");
        tradeable = IERC20(_tradeable);
        leverage = _leverage;
        fee = _fee;
        lnLeverage = uint((int(_leverage)).ln());   
    }

/*//////////////////////////////////////////////‾‾‾‾‾‾‾‾‾‾\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*\
///////////////////////////////////////////////executeables\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
\*\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\____________/////////////////////////////////////////////*/

    /*\
    buys leveraged token will the balance of tradeable tokens from user
    adjusts for token fees
    \*/
    function mintLeveragedWithMaxEth() public returns(uint tokensMinted) {
        uint balBef = tradeable.balanceOf(address(this));
        require(tradeable.transferFrom(msg.sender, address(this), tradeable.balanceOf(msg.sender)));
        uint buyingPower = tradeable.balanceOf(address(this)) - balBef;
        
        uint feeCharged = buyingPower * fee / (100*100);
        buyingPower -= feeCharged;
        require(tradeable.transfer(owner(), feeCharged), "fee transfer failed!");
        
        
        tokensMinted = uint(math.log(int(1e18 + 1e17*buyingPower/getPrice()), int(leverage)));

        _mint(msg.sender, tokensMinted);
    }

    /*\
    buy tokens based on exact buying power
    adjusts for token fees
    \*/
    function mintLeverageWithExactEth(uint _buyingPower) public returns(uint tokensMinted) {
        uint balBef = tradeable.balanceOf(address(this));
        require(tradeable.transferFrom(msg.sender, address(this), _buyingPower));
        _buyingPower = tradeable.balanceOf(address(this)) - balBef;

        uint feeCharged = _buyingPower * fee / (100*100);
        _buyingPower -= feeCharged;
        require(tradeable.transfer(owner(), feeCharged), "fee transfer failed!");
        
        tokensMinted = uint(1e18 * (int(1e18 + 1e17*_buyingPower/getPrice())).ln()) / lnLeverage;
        
        _mint(msg.sender, tokensMinted);
    }


    /*\
    buy exact amount tokens
    adjusts for token fees
    \*/
    function mintExactLeverageWithEth(uint _amount) public returns(uint buyingPower) {
        
        buyingPower = 10 * (
            getPrice() *
            ((_amount*lnLeverage/1e18).fixedExp() - 1e18)
        ) / 1e18;

        uint feeCharged = buyingPower * fee / (100*100);
        buyingPower += feeCharged;
        
        uint balBef = tradeable.balanceOf(address(this));
        require(tradeable.transferFrom(msg.sender, address(this), buyingPower));
        uint diff = (tradeable.balanceOf(address(this)) - balBef);
        if (diff > 0) {
            uint toTransfer = 1e18 * diff / (1e18 - 1e18 * diff / buyingPower);
            require(tradeable.transferFrom(msg.sender, address(this), toTransfer));
        }
        require(tradeable.transfer(owner(), feeCharged), "fee transfer failed!");
        _mint(msg.sender, _amount);
    }

    /*\
    sell exact amount of tokens for ETH
    \*/
    function burnExactLeverageForEth(uint _amount) public returns(uint sellingPower) {
        _burn(msg.sender, _amount);

        sellingPower = 10*(
            (lnLeverage*totalSupply()/1e18).fixedExp() - 
            (lnLeverage*(totalSupply()-_amount)/1e18).fixedExp()
        );

        uint feeCharged = sellingPower * fee / (100*100);
        sellingPower += feeCharged;
        require(tradeable.transfer(owner(), feeCharged), "fee transfer failed!");

        require(tradeable.transfer(msg.sender, sellingPower));
    }

    /*\
    sell tokens for exact amount of ETH
    adjusts for token fees
    \*/
    function burnLeverageForExactEth(uint _sellingPower) public returns(uint amount) {
        
        uint feeCharged = _sellingPower * fee / (100*100);
        _sellingPower += feeCharged;

        amount = uint(
            int(totalSupply()) - math.log(-int(_sellingPower)/10 + int(getPrice()), int(leverage))
        );
        
        _burn(msg.sender, amount);
        uint balBef = tradeable.balanceOf(msg.sender);
        require(tradeable.transfer(msg.sender, _sellingPower));
        uint diff = tradeable.balanceOf(msg.sender) - balBef;
        uint toTransfer = 0;
        if(diff > 0) {
            toTransfer = 1e18 * diff / (1e18 - 1e18 * diff / _sellingPower);
            amount = uint(
                int(totalSupply()) - math.log(-int(toTransfer)/10 + int(getPrice()), int(leverage))
            );
            _burn(msg.sender, amount);

            require(tradeable.transfer(owner(), feeCharged), "fee transfer failed!");
            require(tradeable.transfer(msg.sender, toTransfer));
            
        }
    }

    /*\
    sells all leveraged tokens for tradeable token
    \*/
    function sellAllLeverageForEth() public returns(uint sellingPower) {
        sellingPower = balanceTradeable(msg.sender);
        
        uint feeCharged = sellingPower * fee / (100*100);
        sellingPower += feeCharged;
        require(tradeable.transfer(owner(), feeCharged), "fee transfer failed!");

        uint amount = balanceOf(msg.sender);
        _burn(msg.sender, amount);
        require(tradeable.transfer(msg.sender, sellingPower));
    }
    

 


/*//////////////////////////////////////////////‾‾‾‾‾‾‾‾‾‾‾\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*\
///////////////////////////////////////////////viewable/misc\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
\*\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_____________/////////////////////////////////////////////*/


    /*\
    get current price to mint
    \*/
    function getPrice() public view returns(uint) {
        return getPrice(totalSupply());
    }

    /*\
    returns the current price of the token based on the tokens minted 
    using Logarithmic Transformation
    \*/
    function getPrice(uint _totalSupply) internal view returns (uint) {
        uint result = (_totalSupply * lnLeverage / 1e18).fixedExp();
        
        return result;
    }

    /*\
    value of tokens in tradeable token if sold at the moment
    \*/ 
    function balanceTradeable(address account) public view returns(uint) {
        return 10*(getPrice(totalSupply()) - getPrice(totalSupply()-balanceOf(account))) * fee / (100*100);
    }

}
