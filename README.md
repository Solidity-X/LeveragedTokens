<h1>Leveraged Tokens</h1>
<br>
<br>
<h2> What is it? </h2>
<p>
  Leveraged Tokens allow any crypto project to create a high risk derivative Token with no initial liquidity needed, no need for any oracle and no need for liquidations. <br>
  Users can speculate on events and maximize their yield. Projects can each a trading fee and thus increase the projcts income.
</p>

<h2> How does it work?</h2>
<p>
  A Leveraged Tokens can be minted and burned against a underlying asset. This asset is arbitrary can be chosen freely by the deployer. <br>
  The rate at which the assets can be exchanged is constantly changing. At deployment a starting price and thus the lowest exchange rate is set. <br>
  For each new mint the prices rises some fixed percentage which is set at deployment, the same applies for every burn, just that the price decreases by said percentage. <br>
  Leveraged Tokens also support underlyings with fees on transfer. <br>
  Because Leveraged tokens are traded against the underlying directly, and the price curve is known beforehand there is no need for initial liquidity. <br>
  Also there is no need for liquidations, a user can NEVER loose 100% (in terms of the underlying). If the initial price is set to 1 U (underlying) and the price increases by <b>10%</b> for each mint and a user mints the 10th LT (Leveraged Token) and then all other LT's are burned then the user will still receive 1 U. <br>
  The user is left with $\frac{1.1^{0}}{1.1^{10}}$ or 0.385% of his investment. (in terms of underlying) <br>
  LT's can also be minted/burned partially. <br>
  Some more math can be seen <a href='https://www.desmos.com/calculator/0cvbcckmou'>here</a>
</p>
<h2> Why Leveraged Tokens?</h2>
  The reason to use LT's is very simple. 
  <ul>
      <li>Speculation: It allows your community to speculate on events and increase their exposure to your token. In order to mint LT's they first have to obtain the underlying asset.</li> <br>
      <li>Volatility: Due to high liquidity, the underlying asset may not feed the risk appetite of some individuals and they will look for other investment opportunities, LT's can solve this issue.</li> <br>
      <li>Extra Income: Projects can earn a fee of upto 5% of each mint/burn which can be a good extra income for projects to further develop their projects.</li> <br>    
      <li>Market Making: Projects that successfully established LT's can even create liquidity pool for them, thus users can trade LT's without minting/burning them. This allows for arbitrage opportunities which the projects could utilize through bots.</li>
  </ul>

<b>Use at your own risk, the code has not been audit and is subsceptible to bugs</b>
