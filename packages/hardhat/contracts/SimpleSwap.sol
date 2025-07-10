// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


/// @title SimpleSwap a Liquidity Pool Contract 
/// @notice This contract allows users to add/remove liquidity and swap tokens in an ERC-20 pool.
/// @dev  revision 4.

contract SimpleSwap is ERC20 {

    constructor() ERC20("Liquidity","LT"){
    }

    event LiquidityAdded(address indexed tokenA, address indexed tokenB, uint amountA, uint amountB, uint liquidity, address indexed to);
    event LiquidityRemoved(address indexed tokenA, address indexed tokenB, uint amountA, uint amountB, uint liquidity, address indexed to);
    event TokensSwapped(address indexed from, address indexed tokenIn, address indexed tokenOut, uint amountIn, uint amountOut);
    
    /// @notice Adds liquidity to a token pair in the ERC-20 pool.
    /// @dev This function transfers tokens from the user to the contract, calculates 
    ///      the liquidity based on reserves,
    ///      and issues liquidity tokens to the user.
    /// @param tokenA The address of the first token.
    /// @param tokenB The address of the second token.
    /// @param amountADesired The desired amount of token A to add.
    /// @param amountBDesired The desired amount of token B to add.
    /// @param amountAMin The minimum acceptable amount of token A to avoid failure.
    /// @param amountBMin The minimum acceptable amount of token B to avoid failure.
    /// @param to The address of the recipient who will receive liquidity tokens.
    /// @param deadline The timestamp by which the transaction must be completed.
    /// @return amountA The effective amount of token A added.
    /// @return amountB The effective amount of token B added.
    /// @return liquidity The amount of liquidity tokens issued.
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity) {
     require(deadline >= block.timestamp ,"TimeIsOver" );
     liquidity = totalSupply();
     if(liquidity > 0 ){
        uint256 lq1 = (amountADesired* liquidity)/ ERC20(tokenA).balanceOf(address(this));
        uint256 lq2 = (amountBDesired* liquidity)/ ERC20(tokenB).balanceOf(address(this));
        if( lq1< lq2){
            amountA = amountADesired;
            amountB = getPrice(tokenA,tokenB)* amountA;
        }else{
            amountB = amountBDesired; 
            uint256 lprice = getPrice(tokenB, tokenA);  /// local var to solve nesting took deep error
            amountA = ( lprice * amountB) / 1e18;
        }
     }else{
        liquidity = amountADesired;
        amountA = amountADesired ;
        amountB = amountBDesired;
     }
    
    require(amountAMin<= amountA,"Amount A is too small");
    require(amountBMin <= amountB,"Amount B is too small");
   
    ERC20(tokenA).transferFrom(msg.sender,address(this), amountA);
    ERC20(tokenB).transferFrom(msg.sender, address(this) ,amountB );
    _mint(to,liquidity);
    emit LiquidityAdded(tokenA, tokenB, amountA, amountB, liquidity, to);
 
    return(amountA,amountB,liquidity);
    }

    /// @notice Removes liquidity from a token pair in the ERC-20 pool.
    /// @dev This function burns liquidity tokens from the user and returns the respective amounts of token A and B.
    /// @param tokenA The address of the first token.
    /// @param tokenB The address of the second token.
    /// @param liquidity The amount of liquidity tokens to withdraw.
    /// @param amountAMin The minimum acceptable amount of token A to avoid failure.
    /// @param amountBMin The minimum acceptable amount of token B to avoid failure.
    /// @param to The address of the recipient who will receive the tokens.
    /// @param deadline The timestamp by which the transaction must be completed.
    /// @return amountA The amount of token A received after removing liquidity.
    /// @return amountB The amount of token B received after removing liquidity.
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB) {
    
    require(msg.sender == to, "Only liquidity provider can burn their tokens");
    uint256 totalLiquidity = totalSupply();
    
    require(totalLiquidity > 0, "No liquidity in the pool");
    require(deadline>= block.timestamp , "TimeIsOver" );
    
    amountA = liquidity * ERC20(tokenA).balanceOf(address(this))/totalLiquidity;
    amountB = liquidity * ERC20(tokenB).balanceOf(address(this))/totalLiquidity;

    require(amountA>= amountAMin,"AmountA is too small");
    require(amountB>= amountBMin,"AmountB is too small");

    _burn(msg.sender,liquidity);
    ERC20(tokenA).transfer(to,amountA);
    ERC20(tokenB).transfer(to,amountB);
    
    emit LiquidityRemoved(tokenA, tokenB, amountA, amountB, liquidity, to);
    
    return(amountA,amountB);
    }

    /// @notice Swaps an exact amount of one token for another.
    /// @dev This function transfers the input token from the user to the contract,
    ///      calculates the swap amount based on reserves, and transfers the output token to the user.
    /// @param amountIn The amount of input tokens.
    /// @param amountOutMin The minimum acceptable amount of output tokens.
    /// @param path An array of token addresses (input token, output token).
    /// @param to The address of the recipient who will receive the output tokens.
    /// @param deadline The timestamp by which the transaction must be completed.
    /// @return amounts An array containing the amounts of input and output tokens.
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        // Ensure the path is valid (length should be 2 for a direct swap)              
        require(path.length == 2, "Invalid path length");
        require(deadline>= block.timestamp , "TimeIsOver" );
        
        ERC20 tokenA = ERC20(path[0]);
        ERC20 tokenB = ERC20(path[1]);
        
        // Get reserves before transfer
        uint256 reserveA = tokenA.balanceOf(address(this));
        uint256 reserveB = tokenB.balanceOf(address(this));
        
        // Transfer in first
        tokenA.transferFrom(msg.sender, address(this), amountIn);

        // Calculate amountOut using pre-swap reserves
        uint256 amountOut = (amountIn * reserveB) / (reserveA + amountIn);
        require(amountOut >= amountOutMin, "AmountOut too small");
        tokenB.transfer(to, amountOut);
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
        emit TokensSwapped(msg.sender, path[0], path[path.length - 1], amountIn, amounts[amounts.length - 1]);    
        return amounts;
    
    }

    /// @notice Retrieves the price of one token in terms of another.
    /// @dev This function fetches the reserves of both tokens and calculates the price.
    /// @param tokenA The address of the first token.
    /// @param tokenB The address of the second token.
    /// @return price The price of token A in terms of token B.
    function getPrice(
        address tokenA,
        address tokenB
    ) public view returns (uint price) {

        uint256 amountA = ERC20(tokenA).balanceOf(address(this));
        uint256 amountB = ERC20(tokenB).balanceOf(address(this));
        require(amountA > 0 && amountB > 0, "Insufficient reserves for price calculation");
        require(tokenA != tokenB, "Cannot calculate price for the same token");
        // Calculate price as amountB per amountA, scaled by 1e18 for precision
        price = (amountB * 1e18) / amountA;
       return price;
    }

    /// @notice Calculates the amount of tokens received from a swap.
    /// @dev This function computes the output amount based on input amount and reserves.
    /// @param amountIn The amount of input tokens.
    /// @param reserveIn The current reserves of the input token.
    /// @param reserveOut The current reserves of the output token.
    /// @return amountOut The amount of tokens to be received.
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut) {
        require(amountIn > 0, "Amount in must be greater than zero");
        require(reserveIn > 0 && reserveOut > 0, "Reserves must be greater than zero"); 
        return (amountIn * reserveOut) / (amountIn + reserveIn);
    }
}
